/* ctermyrdp.c — CTermyRDP shim: real FreeRDP 3.26.0 session bodies.
 *
 * M5 Task 4. Implements the narrow opaque-handle C API declared in
 * ctermyrdp.h against vendored, statically-linked FreeRDP 3.26.0:
 *   • client context (RDP_CLIENT_ENTRY_POINTS) + settings population
 *   • freerdp_connect / disconnect / destroy lifecycle
 *   • gdi software framebuffer → full BGRA frame events (no partial-rect
 *     path: FreeRDP's gdi maintains the whole primary surface; the Swift
 *     wrapper's bitmap-compositing decision records this as dead post-cutover)
 *   • cliprdr / rdpdr / rdpsnd channel hookup via the PubSub
 *     ChannelConnected event
 *   • a single non-blocking pump that drains FreeRDP's event handles and
 *     forwards queued events through ctermyrdp_event_sink
 *   • freerdp_get_last_error() → ctermyrdp_status mapping
 *
 * NOTE ON THE DEFERRED GATE (spec §8): a live RDP server is unavailable in
 * this environment, so the connect/pump/channel paths below are structurally
 * complete and link against the real archives but are NOT exercised
 * end-to-end here. The unit-tested surface is the Swift marshalling
 * trampoline + settings + credential resolution driven by synthetic inputs
 * (Tests/TermyRDPTests/FreeRDPSessionTests.swift). The live server connect +
 * bitmap render + audible-audio round-trip is the explicit deferred
 * verification gate and is never simulated.
 *
 * Threading (ctermyrdp.h contract): ctermyrdp_pump is called repeatedly on a
 * dedicated off-main thread; the sink callback fires on that thread; every
 * payload pointer is valid only for the callback's duration (the Swift
 * trampoline copies before returning).
 */

#include "ctermyrdp.h"

/* FreeRDP headers — confined to this .c, never the public header. */
#include <freerdp/freerdp.h>
#include <freerdp/client.h>
#include <freerdp/settings.h>
#include <freerdp/error.h>
#include <freerdp/event.h>
#include <freerdp/gdi/gdi.h>
#include <freerdp/codec/color.h>
#include <freerdp/codec/audio.h>
#include <freerdp/channels/channels.h>
#include <freerdp/client/channels.h>
#include <freerdp/client/cmdline.h>
#include <freerdp/client/cliprdr.h>
#include <freerdp/client/rdpsnd.h>
#include <freerdp/client/rdpdr.h>
#include <winpr/winpr.h>
#include <winpr/synch.h>
#include <winpr/collections.h>

#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>

/* Pump-loop poll timeout (ms). Bounded so the pump thread blocks instead of
 * busy-spinning, yet wakes often enough to honour cooperative cancellation. */
#define CTERMYRDP_PUMP_POLL_MS 100u

/* The remdesk (Remote Assistance) channel is disabled at build time
 * (script/build_freerdp.sh, spec §1 channel allowlist) so FreeRDP's static
 * addin table no longer references it — no workaround stubs are needed. */

/* ── Per-session context embedded in FreeRDP's rdpContext ───────────────── */

typedef struct {
    rdpContext _p;                 /* MUST be first (FreeRDP contract) */
    struct ctermyrdp_session* owner;
} ctermyrdp_rdp_context;

/* A queued event whose payload buffers are heap-owned by the shim until the
 * sink callback has consumed them. One queue node owns exactly one event +
 * its detached buffers. */
typedef struct ctermyrdp_queued_event {
    ctermyrdp_event event;
    uint8_t* buf0;                 /* frame pixels / clipboard / audio pcm */
    char*    buf1;                 /* drive path (NUL-terminated) */
    struct ctermyrdp_queued_event* next;
} ctermyrdp_queued_event;

struct ctermyrdp_session {
    /* Deep-copied connection config; password zeroed after connect. */
    char* host;
    char* username;
    char* domain;
    char* password;                /* zeroed + freed after ctermyrdp_connect */
    uint16_t port;
    ctermyrdp_resolution resolution;
    ctermyrdp_redirection_flags redirections;

    freerdp* instance;
    ctermyrdp_rdp_context* context;

    /* Channel client contexts, captured on ChannelConnected. */
    CliprdrClientContext* cliprdr;
    RdpdrClientContext*   rdpdr;

    /* Event queue (producer: FreeRDP callbacks; consumer: ctermyrdp_pump). */
    CRITICAL_SECTION queue_lock;
    ctermyrdp_queued_event* queue_head;
    ctermyrdp_queued_event* queue_tail;

    /* R3: FreeRDP is not thread-safe for concurrent access to one rdpContext.
     * The pump thread (freerdp_check_event_handles) and the caller-thread input
     * sends (freerdp_input_send_*, cliprdr) would otherwise race the context.
     * Held around the context-touching pass / each send — NOT around the pump's
     * WaitForMultipleObjects, so input never waits the full poll timeout. */
    CRITICAL_SECTION context_lock;

    ctermyrdp_status last_status;
    int32_t last_error_code;
    /* Written by ctermyrdp_disconnect (caller thread), read by
     * ctermyrdp_pump (pump thread). Atomic with relaxed ordering: it is a
     * standalone cancellation flag (no other state is published through it),
     * so relaxed loads/stores suffice and avoid a C11 data race. */
    _Atomic int disconnect_requested;
    int connected;
    uint64_t frame_seq; /* shim-owned frame counter; NOT FreeRDP's gdi->frameId */

    /* R4/R5 cliprdr handshake state (touched only on the pump thread via the
     * cliprdr callbacks, plus send_clipboard which stashes the pending tx under
     * context_lock). */
    uint32_t requested_format;   /* R4: format we asked the server for; tags the
                                  * inbound FORMAT_DATA_RESPONSE (was hardcoded 13). */
    uint8_t* pending_tx_data;    /* R5: local clipboard bytes stashed by
                                  * ctermyrdp_send_clipboard, sent when the server
                                  * issues a FORMAT_DATA_REQUEST. */
    size_t   pending_tx_size;
    uint32_t pending_tx_format;
};

/* ── Small helpers ──────────────────────────────────────────────────────── */

static char* dup_cstr(const char* s)
{
    if (!s) return NULL;
    size_t n = strlen(s);
    char* p = (char*)malloc(n + 1);
    if (!p) return NULL;
    memcpy(p, s, n + 1);
    return p;
}

/* Securely wipe + free the plaintext password. memset is volatile-guarded so
 * the compiler cannot elide it. */
static void scrub_free(char** s)
{
    if (s && *s) {
        volatile char* v = (volatile char*)*s;
        size_t n = strlen(*s);
        for (size_t i = 0; i < n; ++i) v[i] = 0;
        free(*s);
        *s = NULL;
    }
}

static void enqueue(struct ctermyrdp_session* s, ctermyrdp_queued_event* n)
{
    n->next = NULL;
    EnterCriticalSection(&s->queue_lock);
    if (s->queue_tail) s->queue_tail->next = n;
    else               s->queue_head = n;
    s->queue_tail = n;
    LeaveCriticalSection(&s->queue_lock);
}

static ctermyrdp_queued_event* dequeue(struct ctermyrdp_session* s)
{
    EnterCriticalSection(&s->queue_lock);
    ctermyrdp_queued_event* n = s->queue_head;
    if (n) {
        s->queue_head = n->next;
        if (!s->queue_head) s->queue_tail = NULL;
    }
    LeaveCriticalSection(&s->queue_lock);
    return n;
}

static void free_queued(ctermyrdp_queued_event* n)
{
    if (!n) return;
    free(n->buf0);
    free(n->buf1);
    free(n);
}

static ctermyrdp_queued_event* new_node(void)
{
    ctermyrdp_queued_event* n =
        (ctermyrdp_queued_event*)calloc(1, sizeof(*n));
    return n;
}

/* freerdp_get_last_error() → stable ctermyrdp_status. The full mapped error
 * code is also carried up so the Swift side can ride it in
 * RDPDisconnectReason.transportError(Int32). */
static ctermyrdp_status map_freerdp_error(UINT32 err)
{
    if (err == FREERDP_ERROR_SUCCESS || err == FREERDP_ERROR_NONE)
        return CTERMYRDP_STATUS_OK;
    switch (err) {
        case FREERDP_ERROR_AUTHENTICATION_FAILED:
        case FREERDP_ERROR_INSUFFICIENT_PRIVILEGES:
        case FREERDP_ERROR_CONNECT_LOGON_FAILURE:
        case FREERDP_ERROR_CONNECT_ACCOUNT_DISABLED:
        case FREERDP_ERROR_CONNECT_PASSWORD_EXPIRED:
        case FREERDP_ERROR_CONNECT_PASSWORD_MUST_CHANGE:
            return CTERMYRDP_STATUS_AUTH_FAILED;
        case FREERDP_ERROR_TLS_CONNECT_FAILED:
            return CTERMYRDP_STATUS_TLS_FAILED;
        case FREERDP_ERROR_DNS_ERROR:
        case FREERDP_ERROR_DNS_NAME_NOT_FOUND:
        case FREERDP_ERROR_CONNECT_TRANSPORT_FAILED:
            return CTERMYRDP_STATUS_NETWORK_ERROR;
        case FREERDP_ERROR_CONNECT_CANCELLED:
            return CTERMYRDP_STATUS_DISCONNECTED;
        default:
            return CTERMYRDP_STATUS_CONNECT_FAILED;
    }
}

/* ── GDI full-frame extraction (EndPaint) ───────────────────────────────── */

/* FreeRDP's gdi keeps the complete primary BGRA surface. On EndPaint we
 * snapshot the whole buffer into a heap copy and queue a FRAME event. There
 * is intentionally no partial-rectangle path: the C API exposes only
 * CTERMYRDP_EVENT_FRAME (full frame) — the Swift wrapper records this as the
 * bitmap-compositing-dead decision. */
static BOOL termy_end_paint(rdpContext* context)
{
    ctermyrdp_rdp_context* cc = (ctermyrdp_rdp_context*)context;
    struct ctermyrdp_session* s = cc ? cc->owner : NULL;
    if (!s || !context) return TRUE;

    rdpGdi* gdi = context->gdi;
    if (!gdi || !gdi->primary_buffer) return TRUE;

    UINT32 w = (UINT32)gdi->width;
    UINT32 h = (UINT32)gdi->height;
    if (w == 0 || h == 0) return TRUE;

    size_t bytes = (size_t)w * (size_t)h * 4u;
    uint8_t* copy = (uint8_t*)malloc(bytes);
    if (!copy) return TRUE;

    /* gdi->stride may exceed w*4; pack rows tightly into BGRA32. */
    UINT32 stride = (UINT32)gdi->stride;
    for (UINT32 y = 0; y < h; ++y) {
        memcpy(copy + (size_t)y * w * 4,
               gdi->primary_buffer + (size_t)y * stride,
               (size_t)w * 4);
    }

    ctermyrdp_queued_event* n = new_node();
    if (!n) { free(copy); return TRUE; }
    n->buf0 = copy;
    n->event.kind = CTERMYRDP_EVENT_FRAME;
    n->event.payload.frame.bgra_pixels = copy;
    n->event.payload.frame.width = w;
    n->event.payload.frame.height = h;
    /* Shim-owned monotonic counter — never mutate FreeRDP's internal
     * gdi->frameId (it drives gdi/gfx PDU bookkeeping). The Swift instance
     * trampoline additionally overlays its own per-session sequence; this
     * value is the C-side fallback for the stateless marshalEvent path. */
    n->event.payload.frame.sequence_number = ++s->frame_seq;
    enqueue(s, n);
    return TRUE;
}

static BOOL termy_desktop_resize(rdpContext* context)
{
    if (!context) return FALSE;
    rdpGdi* gdi = context->gdi;
    rdpSettings* settings = context->settings;
    if (!gdi || !settings) return FALSE;
    UINT32 w = freerdp_settings_get_uint32(settings, FreeRDP_DesktopWidth);
    UINT32 h = freerdp_settings_get_uint32(settings, FreeRDP_DesktopHeight);
    return gdi_resize(gdi, w, h);
}

/* ── Channel hookup (cliprdr / rdpsnd / rdpdr) ──────────────────────────── */

/* CF_UNICODETEXT (winpr/user.h) — the one text format the inbound decoder reads. */
#define TERMY_CF_UNICODETEXT 13u

/* R4: choose the paste format to request from a server-announced list.
 * CF_UNICODETEXT ONLY: it is the single format the inbound decoder
 * (FreeRDPSession.marshalClipboard) reads correctly (UTF-16LE). Requesting
 * CF_TEXT/CF_OEMTEXT would be decoded as UTF-8 and garble non-ASCII — exactly the
 * R4 defect, from the other direction — so request nothing (0) when the server
 * offers no unicode text (it then stays unsupported rather than garbled). Pure
 * (no FreeRDP types) so it is unit-tested from Swift. */
uint32_t ctermyrdp_preferred_paste_format(const uint32_t* formats, size_t count)
{
    if (!formats) return 0u;
    for (size_t i = 0; i < count; ++i) {
        if (formats[i] == TERMY_CF_UNICODETEXT) return TERMY_CF_UNICODETEXT;
    }
    return 0u;
}

/* Send a ClientFormatList. `format` 0 → an empty list (handshake only). */
static UINT termy_cliprdr_send_format_list(CliprdrClientContext* ctx, uint32_t format)
{
    if (!ctx || !ctx->ClientFormatList) return CHANNEL_RC_OK;
    CLIPRDR_FORMAT fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.formatId = format;
    fmt.formatName = NULL;
    CLIPRDR_FORMAT_LIST list;
    memset(&list, 0, sizeof(list));
    list.common.msgType = CB_FORMAT_LIST;
    list.numFormats = format ? 1u : 0u;
    list.formats = format ? &fmt : NULL;
    return ctx->ClientFormatList(ctx, &list);
}

/* R5: after MonitorReady the client completes the handshake with a format list
 * (empty until the app shares local clipboard via ctermyrdp_send_clipboard). */
static UINT termy_cliprdr_monitor_ready(CliprdrClientContext* ctx,
                                        const CLIPRDR_MONITOR_READY* ready)
{
    (void)ready;
    return termy_cliprdr_send_format_list(ctx, 0u);
}

/* R4 (inbound paste): ack the server's format list, then request a preferred
 * text format — which arrives via ServerFormatDataResponse. */
static UINT termy_cliprdr_server_format_list(CliprdrClientContext* ctx,
                                             const CLIPRDR_FORMAT_LIST* list)
{
    struct ctermyrdp_session* s = ctx ? (struct ctermyrdp_session*)ctx->custom : NULL;
    if (!s || !list) return CHANNEL_RC_OK;

    if (ctx->ClientFormatListResponse) {
        CLIPRDR_FORMAT_LIST_RESPONSE resp;
        memset(&resp, 0, sizeof(resp));
        resp.common.msgType = CB_FORMAT_LIST_RESPONSE;
        resp.common.msgFlags = CB_RESPONSE_OK;
        ctx->ClientFormatListResponse(ctx, &resp);
    }

    uint32_t ids[64];
    UINT32 n = list->numFormats < 64 ? list->numFormats : 64u;
    for (UINT32 i = 0; i < n && list->formats; ++i) ids[i] = list->formats[i].formatId;
    uint32_t chosen = ctermyrdp_preferred_paste_format(ids, list->formats ? n : 0u);
    if (chosen == 0u || !ctx->ClientFormatDataRequest) return CHANNEL_RC_OK;

    s->requested_format = chosen;
    CLIPRDR_FORMAT_DATA_REQUEST req;
    memset(&req, 0, sizeof(req));
    req.common.msgType = CB_FORMAT_DATA_REQUEST;
    req.requestedFormatId = chosen;
    return ctx->ClientFormatDataRequest(ctx, &req);
}

static UINT termy_cliprdr_server_format_list_response(
    CliprdrClientContext* ctx, const CLIPRDR_FORMAT_LIST_RESPONSE* resp)
{
    (void)ctx; (void)resp;
    return CHANNEL_RC_OK;
}

/* R5 (outbound paste): the server wants our clipboard — answer with the bytes
 * the app last stashed via ctermyrdp_send_clipboard. */
static UINT termy_cliprdr_server_format_data_request(
    CliprdrClientContext* ctx, const CLIPRDR_FORMAT_DATA_REQUEST* req)
{
    struct ctermyrdp_session* s = ctx ? (struct ctermyrdp_session*)ctx->custom : NULL;
    if (!s || !req || !ctx->ClientFormatDataResponse) return CHANNEL_RC_OK;

    /* This callback fires on the pump thread inside freerdp_check_event_handles,
     * which already holds context_lock (see ctermyrdp_pump). That lock also
     * guards ctermyrdp_send_clipboard's writes to pending_tx, so reading it here
     * needs no further locking — and re-locking would rely on CRITICAL_SECTION
     * recursion. */
    CLIPRDR_FORMAT_DATA_RESPONSE resp;
    memset(&resp, 0, sizeof(resp));
    resp.common.msgType = CB_FORMAT_DATA_RESPONSE;
    if (s->pending_tx_data && s->pending_tx_size > 0) {
        resp.common.msgFlags = CB_RESPONSE_OK;
        resp.common.dataLen = (UINT32)s->pending_tx_size;
        resp.requestedFormatData = s->pending_tx_data;
    } else {
        resp.common.msgFlags = CB_RESPONSE_FAIL;
    }
    return ctx->ClientFormatDataResponse(ctx, &resp);
}

static UINT termy_cliprdr_server_format_data_response(
    CliprdrClientContext* ctx, const CLIPRDR_FORMAT_DATA_RESPONSE* resp)
{
    struct ctermyrdp_session* s =
        ctx ? (struct ctermyrdp_session*)ctx->custom : NULL;
    if (!s || !resp || (resp->common.msgFlags & CB_RESPONSE_OK) == 0)
        return CHANNEL_RC_OK;

    UINT32 len = resp->common.dataLen;
    ctermyrdp_queued_event* n = new_node();
    if (!n) return CHANNEL_RC_NO_MEMORY;
    if (len > 0 && resp->requestedFormatData) {
        n->buf0 = (uint8_t*)malloc(len);
        if (!n->buf0) { free(n); return CHANNEL_RC_NO_MEMORY; }
        memcpy(n->buf0, resp->requestedFormatData, len);
    }
    n->event.kind = CTERMYRDP_EVENT_CLIPBOARD_RX;
    n->event.payload.clipboard_rx.data = n->buf0;
    n->event.payload.clipboard_rx.size = len;
    /* R4: tag with the format we actually requested, not a hardcoded
     * CF_UNICODETEXT (a FORMAT_DATA_RESPONSE carries no format id of its own). */
    n->event.payload.clipboard_rx.format =
        s->requested_format ? s->requested_format : TERMY_CF_UNICODETEXT;
    enqueue(s, n);
    return CHANNEL_RC_OK;
}

/* ── rdpsnd: vendored "termy" PCM subsystem bridge ──────────────────────────
 *
 * FreeRDP's rdpsnd is internally managed (spec §6 + 2026-05-19 plan-sync).
 * The audio sink is the build-time custom subsystem
 * vendor/freerdp/overlays/channels/rdpsnd/client/termy/rdpsnd_termy.c, which
 * is compiled into libfreerdp-client3.a and selected at connect via the
 * rdpsnd channel arg "sys:termy" (set in apply_settings). On each PCM block
 * the subsystem's PlayEx/Play callback calls the bridge function below;
 * static linkage resolves the symbol — there is no runtime plugin
 * registration. The pump drains the queued CTERMYRDP_EVENT_AUDIO_PCM events
 * exactly like FRAME/CLIPBOARD_RX; the Swift instance marshal stamps the
 * per-session monotonic audioSequence so RDPAudioOutputBridge's dedup does
 * not drop frames. ctermyrdp_submit_audio_format (header) stays an accepted
 * no-op: format negotiation is owned by rdpsnd_main.c + the subsystem's
 * FormatSupported (PCM-only) gate; nothing from the public API drives it. */

/* Pure enqueue+copy of one PCM block into a session's event queue. No
 * FreeRDP types — this is the unit-tested seam (synthetic PCM, no server).
 * Returns 1 on success, 0 on allocation failure / bad args. The PCM bytes
 * are COPIED into a shim-owned buffer (callback-duration-only lifetime per
 * the rdpsnd device contract); buf0 is freed by free_queued after the sink
 * has consumed the event. */
int ctermyrdp_internal_enqueue_pcm(struct ctermyrdp_session* s,
                                   uint32_t sample_rate, uint8_t channels,
                                   uint8_t bits_per_sample,
                                   const uint8_t* data, size_t size)
{
    if (!s || !data || size == 0) return 0;

    ctermyrdp_queued_event* n = new_node();
    if (!n) return 0;
    n->buf0 = (uint8_t*)malloc(size);
    if (!n->buf0) { free(n); return 0; }
    memcpy(n->buf0, data, size);

    n->event.kind = CTERMYRDP_EVENT_AUDIO_PCM;
    n->event.payload.audio_pcm.pcm_data        = n->buf0;
    n->event.payload.audio_pcm.size            = size;
    n->event.payload.audio_pcm.sample_rate     = sample_rate;
    n->event.payload.audio_pcm.channels        = channels;
    n->event.payload.audio_pcm.bits_per_sample = bits_per_sample;
    enqueue(s, n);
    return 1;
}

/* Bridge invoked by the vendored rdpsnd_termy subsystem on every PCM block.
 * Maps rdpContext* → owning session, narrows the AUDIO_FORMAT to the
 * payload's PCM fields, and hands off to the pure enqueue path. The
 * AUDIO_FORMAT here is always WAVE_FORMAT_PCM (the subsystem's
 * FormatSupported rejects non-PCM, and rdpsnd_main.c DSP-decodes anything
 * else to PCM before this point — Opus/AAC/GSM deps are off, spec §1).
 * nChannels is UINT16 in AUDIO_FORMAT but the wire payload is uint8_t:
 * RDP audio is mono/stereo in practice (1–2) so the narrowing is safe; a
 * pathological >255 is clamped rather than wrapped. */
void ctermyrdp_rdpsnd_termy_deliver_pcm(rdpContext* context,
                                        const AUDIO_FORMAT* format,
                                        const BYTE* data, size_t size)
{
    if (!context || !format || !data || size == 0) return;
    ctermyrdp_rdp_context* cc = (ctermyrdp_rdp_context*)context;
    struct ctermyrdp_session* s = cc->owner;
    if (!s) return;

    uint8_t ch = (format->nChannels > 0xFF)
                     ? 0xFF
                     : (uint8_t)format->nChannels;
    uint8_t bps = (format->wBitsPerSample > 0xFF)
                      ? 0xFF
                      : (uint8_t)format->wBitsPerSample;
    (void)ctermyrdp_internal_enqueue_pcm(s, format->nSamplesPerSec, ch, bps,
                                         (const uint8_t*)data, size);
}

/* Test-only queue drain. Pops the head event, copies the event struct into
 * *out_event, and TRANSFERS ownership of its buf0 (PCM/frame/clipboard
 * heap copy) to the caller via *out_buf0 — the caller must free(*out_buf0)
 * after asserting. Returns 1 if an event was popped, 0 if the queue was
 * empty. Not a production API (production drains via ctermyrdp_pump); this
 * exists so the synthetic-PCM TDD can exercise the real enqueue+copy path
 * without a server. Thread-safe (dequeue takes the queue lock). */
int ctermyrdp_test_pop_event(struct ctermyrdp_session* s,
                             ctermyrdp_event* out_event, void** out_buf0)
{
    if (!s || !out_event) return 0;
    ctermyrdp_queued_event* n = dequeue(s);
    if (!n) return 0;
    *out_event = n->event;
    if (out_buf0) {
        *out_buf0 = n->buf0;
        n->buf0 = NULL; /* ownership transferred to caller */
    }
    free_queued(n);
    return 1;
}

static void on_channel_connected(void* userdata, const ChannelConnectedEventArgs* e)
{
    /* FreeRDP raises ChannelConnected with instance->context (an rdpContext*),
     * not the session pointer — recover the session via ->owner exactly like
     * every other context-driven callback (termy_end_paint, rdpsnd_deliver). */
    ctermyrdp_rdp_context* cc = (ctermyrdp_rdp_context*)userdata;
    struct ctermyrdp_session* s = cc ? cc->owner : NULL;
    if (!s || !e || !e->name) return;

    if (strcmp(e->name, CLIPRDR_SVC_CHANNEL_NAME) == 0) {
        s->cliprdr = (CliprdrClientContext*)e->pInterface;
        if (s->cliprdr) {
            s->cliprdr->custom = s;
            /* R4/R5: wire the full text clipboard handshake, not just the
             * inbound data response. */
            s->cliprdr->MonitorReady = termy_cliprdr_monitor_ready;
            s->cliprdr->ServerFormatList = termy_cliprdr_server_format_list;
            s->cliprdr->ServerFormatListResponse =
                termy_cliprdr_server_format_list_response;
            s->cliprdr->ServerFormatDataRequest =
                termy_cliprdr_server_format_data_request;
            s->cliprdr->ServerFormatDataResponse =
                termy_cliprdr_server_format_data_response;
        }
    } else if (strcmp(e->name, RDPDR_SVC_CHANNEL_NAME) == 0) {
        s->rdpdr = (RdpdrClientContext*)e->pInterface;
        if (s->rdpdr) s->rdpdr->custom = s;
    }
    /* rdpsnd: managed internally; no client context is captured here. PCM
     * is forwarded by the vendored "termy" subsystem (selected via the
     * "sys:termy" channel arg in apply_settings) through
     * ctermyrdp_rdpsnd_termy_deliver_pcm — resolved by static linkage, not
     * runtime plugin registration (spec §6 plan-sync). */
}

static void on_channel_disconnected(void* userdata, const ChannelDisconnectedEventArgs* e)
{
    /* See on_channel_connected: userdata is the rdpContext*, recover via ->owner. */
    ctermyrdp_rdp_context* cc = (ctermyrdp_rdp_context*)userdata;
    struct ctermyrdp_session* s = cc ? cc->owner : NULL;
    if (!s || !e || !e->name) return;
    if (strcmp(e->name, CLIPRDR_SVC_CHANNEL_NAME) == 0) s->cliprdr = NULL;
    else if (strcmp(e->name, RDPDR_SVC_CHANNEL_NAME) == 0) s->rdpdr = NULL;
}

/* ── FreeRDP client entry points ────────────────────────────────────────── */

static BOOL termy_pre_connect(freerdp* instance)
{
    if (!instance || !instance->context) return FALSE;
    rdpSettings* settings = instance->context->settings;

    /* Channels are driven by settings flags; subscribe to connect events so
     * we can capture the client contexts. */
    PubSub_SubscribeChannelConnected(instance->context->pubSub,
                                     on_channel_connected);
    PubSub_SubscribeChannelDisconnected(instance->context->pubSub,
                                         on_channel_disconnected);

    if (!freerdp_client_load_addins(instance->context->channels, settings))
        return FALSE;
    return TRUE;
}

static BOOL termy_post_connect(freerdp* instance)
{
    if (!instance || !instance->context) return FALSE;
    if (!gdi_init(instance, PIXEL_FORMAT_BGRA32)) return FALSE;

    rdpUpdate* update = instance->context->update;
    if (update) {
        update->EndPaint = termy_end_paint;
        update->DesktopResize = termy_desktop_resize;
    }
    return TRUE;
}

static void termy_post_disconnect(freerdp* instance)
{
    if (instance) gdi_free(instance);
}

static BOOL termy_client_new(freerdp* instance, rdpContext* context)
{
    if (!instance || !context) return FALSE;
    instance->PreConnect = termy_pre_connect;
    instance->PostConnect = termy_post_connect;
    instance->PostDisconnect = termy_post_disconnect;
    return TRUE;
}

static void termy_client_free(freerdp* instance, rdpContext* context)
{
    (void)instance;
    (void)context;
}

static int termy_client_start(rdpContext* context) { (void)context; return 0; }
static int termy_client_stop(rdpContext* context)  { (void)context; return 0; }

static int termy_client_entry(RDP_CLIENT_ENTRY_POINTS* ep)
{
    if (!ep) return -1;
    ep->Version = RDP_CLIENT_INTERFACE_VERSION;
    ep->Size = sizeof(RDP_CLIENT_ENTRY_POINTS_V1);
    ep->ContextSize = sizeof(ctermyrdp_rdp_context);
    ep->ClientNew = termy_client_new;
    ep->ClientFree = termy_client_free;
    ep->ClientStart = termy_client_start;
    ep->ClientStop = termy_client_stop;
    return 0;
}

/* ── Settings population from ctermyrdp_config ───────────────────────────── */

static BOOL apply_settings(struct ctermyrdp_session* s, rdpSettings* settings)
{
    if (!settings) return FALSE;

    if (!freerdp_settings_set_string(settings, FreeRDP_ServerHostname, s->host))
        return FALSE;
    if (!freerdp_settings_set_uint32(settings, FreeRDP_ServerPort, s->port))
        return FALSE;
    if (!freerdp_settings_set_string(settings, FreeRDP_Username, s->username))
        return FALSE;
    if (s->domain &&
        !freerdp_settings_set_string(settings, FreeRDP_Domain, s->domain))
        return FALSE;
    if (s->password &&
        !freerdp_settings_set_string(settings, FreeRDP_Password, s->password))
        return FALSE;

    if (!freerdp_settings_set_uint32(settings, FreeRDP_DesktopWidth,
                                     s->resolution.width))
        return FALSE;
    if (!freerdp_settings_set_uint32(settings, FreeRDP_DesktopHeight,
                                     s->resolution.height))
        return FALSE;
    if (!freerdp_settings_set_uint32(settings, FreeRDP_DesktopScaleFactor,
                                     s->resolution.scale_factor_percent))
        return FALSE;
    if (!freerdp_settings_set_uint32(settings, FreeRDP_ColorDepth, 32))
        return FALSE;
    if (!freerdp_settings_set_bool(settings, FreeRDP_SoftwareGdi, TRUE))
        return FALSE;

    BOOL clip  = (s->redirections & CTERMYRDP_REDIRECT_CLIPBOARD) != 0;
    BOOL drive = (s->redirections & CTERMYRDP_REDIRECT_DRIVES) != 0;
    BOOL audio = (s->redirections & CTERMYRDP_REDIRECT_AUDIO) != 0;

    if (!freerdp_settings_set_bool(settings, FreeRDP_RedirectClipboard, clip))
        return FALSE;
    if (!freerdp_settings_set_bool(settings, FreeRDP_AudioPlayback, audio))
        return FALSE;
    if (audio) {
        /* Pre-register the rdpsnd static channel with arg "sys:termy" so the
         * vendored custom PCM subsystem is selected (rather than the
         * compile-time backends[] default in rdpsnd_main.c, which never
         * lists "termy"). freerdp_client_load_addins (called from
         * termy_pre_connect) is idempotent: it finds this channel already
         * registered and keeps our args, which rdpsnd_process_addin_args
         * parses → rdpsnd_set_subsystem(rdpsnd, "termy"). FreeRDP 3.26.0 has
         * no FreeRDP_RdpsndSubsystem setting — the channel arg is the only
         * supported selection mechanism. */
        const char* rdpsnd_params[] = { "rdpsnd", "sys:termy" };
        if (!freerdp_client_add_static_channel(
                settings, 2, rdpsnd_params))
            return FALSE;
    }
    if (drive) {
        if (!freerdp_settings_set_bool(settings, FreeRDP_DeviceRedirection, TRUE))
            return FALSE;
        if (!freerdp_settings_set_bool(settings, FreeRDP_RedirectDrives, TRUE))
            return FALSE;
    }
    return TRUE;
}

/* ── Public lifecycle API ───────────────────────────────────────────────── */

ctermyrdp_session* ctermyrdp_create(const ctermyrdp_config* config)
{
    if (!config || !config->host || !config->username) return NULL;

    struct ctermyrdp_session* s =
        (struct ctermyrdp_session*)calloc(1, sizeof(*s));
    if (!s) return NULL;

    s->host       = dup_cstr(config->host);
    s->username   = dup_cstr(config->username);
    s->domain     = dup_cstr(config->domain);
    s->password   = dup_cstr(config->password);
    s->port       = config->port ? config->port : 3389;
    s->resolution = config->resolution;
    s->redirections = config->redirections;
    s->last_status  = CTERMYRDP_STATUS_OK;

    if (!s->host || !s->username ||
        (config->domain && !s->domain) ||
        (config->password && !s->password)) {
        scrub_free(&s->password);
        free(s->host); free(s->username); free(s->domain);
        free(s);
        return NULL;
    }

    InitializeCriticalSection(&s->queue_lock);
    InitializeCriticalSection(&s->context_lock);

    RDP_CLIENT_ENTRY_POINTS ep;
    memset(&ep, 0, sizeof(ep));
    termy_client_entry(&ep);

    rdpContext* ctx = freerdp_client_context_new(&ep);
    if (!ctx) {
        DeleteCriticalSection(&s->context_lock);
        DeleteCriticalSection(&s->queue_lock);
        scrub_free(&s->password);
        free(s->host); free(s->username); free(s->domain);
        free(s);
        return NULL;
    }

    s->context = (ctermyrdp_rdp_context*)ctx;
    s->context->owner = s;
    s->instance = freerdp_client_get_instance(ctx);

    if (!apply_settings(s, ctx->settings)) {
        s->last_status = CTERMYRDP_STATUS_INVALID_ARG;
    }

    /* Password is now inside FreeRDP settings; the shim copy is no longer
     * needed. Securely wipe + free it before returning (callers also pass it
     * by value and zero their side; defence in depth). */
    scrub_free(&s->password);
    return s;
}

ctermyrdp_status ctermyrdp_connect(ctermyrdp_session* session)
{
    if (!session) return CTERMYRDP_STATUS_NO_SESSION;
    if (!session->instance) return CTERMYRDP_STATUS_INTERNAL_ERROR;
    if (session->last_status == CTERMYRDP_STATUS_INVALID_ARG)
        return CTERMYRDP_STATUS_INVALID_ARG;

    if (!freerdp_connect(session->instance)) {
        UINT32 err = freerdp_get_last_error(&session->context->_p);
        session->last_error_code = (int32_t)err;
        session->last_status = map_freerdp_error(err);
        return session->last_status;
    }
    session->connected = 1;
    session->last_status = CTERMYRDP_STATUS_OK;
    return CTERMYRDP_STATUS_OK;
}

ctermyrdp_status ctermyrdp_pump(ctermyrdp_session*          session,
                                const ctermyrdp_event_sink* sink)
{
    if (!session) return CTERMYRDP_STATUS_NO_SESSION;
    if (!sink || !sink->callback) return CTERMYRDP_STATUS_INVALID_ARG;
    if (!session->instance) return CTERMYRDP_STATUS_INTERNAL_ERROR;

    rdpContext* ctx = &session->context->_p;

    if (atomic_load_explicit(&session->disconnect_requested,
                             memory_order_relaxed) ||
        freerdp_shall_disconnect_context(ctx)) {
        goto disconnected;
    }

    /* One servicing pass. The thread BLOCKS on FreeRDP's event handles for up
     * to CTERMYRDP_PUMP_POLL_MS, then processes whatever is ready. A bounded
     * (not zero, not INFINITE) timeout is deliberate: a 0 ms poll would
     * busy-spin a CPU core for the idle life of the session, while INFINITE
     * would prevent the pump from periodically re-checking the cooperative
     * cancellation flags (disconnect_requested / the Swift-side stop). 100 ms
     * is FreeRDP's idiomatic client-loop responsiveness/idle-cost balance.
     * The update + channel callbacks (termy_end_paint, cliprdr handlers)
     * enqueue events during freerdp_check_event_handles. */
    {
        HANDLE handles[64];
        DWORD count = freerdp_get_event_handles(ctx, handles,
                                                (DWORD)(sizeof(handles) / sizeof(handles[0])));
        if (count == 0) {
            /* No event handles means the transport is gone — an abnormal
             * drop, NOT a user-initiated close. Map to NETWORK_ERROR so
             * disconnectReason() yields .networkFailure and the existing
             * RDPReconnectPolicy retries (a stale CTERMYRDP_STATUS_OK here
             * would mis-map to .userInitiated and suppress reconnect). */
            session->last_status = CTERMYRDP_STATUS_NETWORK_ERROR;
            if (session->last_error_code == 0) {
                UINT32 err = freerdp_get_last_error(ctx);
                if (err != 0) session->last_error_code = (int32_t)err;
            }
            goto disconnected;
        }

        DWORD wr = WaitForMultipleObjects(count, handles, FALSE,
                                          CTERMYRDP_PUMP_POLL_MS);
        if (wr != WAIT_TIMEOUT) {
            /* R3: serialise the context-touching pass against input sends. The
             * blocking wait above stays outside the lock so a send never waits
             * the full poll timeout. */
            EnterCriticalSection(&session->context_lock);
            BOOL ok = freerdp_check_event_handles(ctx);
            LeaveCriticalSection(&session->context_lock);
            if (!ok) {
                UINT32 err = freerdp_get_last_error(ctx);
                session->last_error_code = (int32_t)err;
                session->last_status = map_freerdp_error(err);
                goto disconnected;
            }
        }
    }

    /* Drain the queue produced by the callbacks above. */
    {
        ctermyrdp_queued_event* n;
        while ((n = dequeue(session)) != NULL) {
            sink->callback(&n->event, sink->user_data);
            free_queued(n);
        }
    }

    if (freerdp_shall_disconnect_context(ctx)) goto disconnected;
    return CTERMYRDP_STATUS_OK;

disconnected: {
        ctermyrdp_queued_event* n;
        while ((n = dequeue(session)) != NULL) {
            sink->callback(&n->event, sink->user_data);
            free_queued(n);
        }
        ctermyrdp_event ev;
        memset(&ev, 0, sizeof(ev));
        ev.kind = CTERMYRDP_EVENT_DISCONNECT;
        ev.payload.disconnect.last_error_code = session->last_error_code;
        ev.payload.disconnect.status_code =
            atomic_load_explicit(&session->disconnect_requested,
                                 memory_order_relaxed)
                ? CTERMYRDP_STATUS_DISCONNECTED
                : session->last_status;
        sink->callback(&ev, sink->user_data);
        session->last_status = CTERMYRDP_STATUS_DISCONNECTED;
        return CTERMYRDP_STATUS_DISCONNECTED;
    }
}

/* ── Input ───────────────────────────────────────────────────────────────── */

ctermyrdp_status ctermyrdp_send_key(ctermyrdp_session*         session,
                                    const ctermyrdp_key_event* event)
{
    if (!session) return CTERMYRDP_STATUS_NO_SESSION;
    if (!event || !session->instance) return CTERMYRDP_STATUS_INVALID_ARG;
    rdpInput* input = session->context->_p.input;
    if (!input) return CTERMYRDP_STATUS_CHANNEL_ERROR;
    UINT16 flags = (UINT16)((event->key_down ? KBD_FLAGS_DOWN : KBD_FLAGS_RELEASE) |
                            (event->extended ? KBD_FLAGS_EXTENDED : 0));
    /* R3: serialise against the pump's context pass. */
    EnterCriticalSection(&session->context_lock);
    BOOL ok = freerdp_input_send_keyboard_event(input, flags,
                                                (UINT16)event->scan_code);
    LeaveCriticalSection(&session->context_lock);
    return ok ? CTERMYRDP_STATUS_OK : CTERMYRDP_STATUS_CHANNEL_ERROR;
}

ctermyrdp_status ctermyrdp_send_pointer(ctermyrdp_session*             session,
                                        const ctermyrdp_pointer_event* event)
{
    if (!session) return CTERMYRDP_STATUS_NO_SESSION;
    if (!event || !session->instance) return CTERMYRDP_STATUS_INVALID_ARG;
    rdpInput* input = session->context->_p.input;
    if (!input) return CTERMYRDP_STATUS_CHANNEL_ERROR;
    /* R3: serialise against the pump's context pass. */
    EnterCriticalSection(&session->context_lock);
    BOOL ok = freerdp_input_send_mouse_event(input, event->flags,
                                             event->x, event->y);
    LeaveCriticalSection(&session->context_lock);
    return ok ? CTERMYRDP_STATUS_OK : CTERMYRDP_STATUS_CHANNEL_ERROR;
}

/* ── Channels ────────────────────────────────────────────────────────────── */

ctermyrdp_status ctermyrdp_send_clipboard(ctermyrdp_session*            session,
                                          const ctermyrdp_clipboard_tx* data)
{
    if (!session) return CTERMYRDP_STATUS_NO_SESSION;
    if (!data) return CTERMYRDP_STATUS_INVALID_ARG;
    if (!session->cliprdr) return CTERMYRDP_STATUS_CHANNEL_ERROR;

    /* R5: don't send an unsolicited FORMAT_DATA_RESPONSE (the previous code did,
     * which the server ignores). The correct flow is: announce availability via
     * ClientFormatList, then answer the server's FORMAT_DATA_REQUEST with the
     * stashed bytes (termy_cliprdr_server_format_data_request). Stash a private
     * copy here so the bytes outlive this call. */
    uint8_t* copy = NULL;
    if (data->size > 0 && data->data) {
        copy = (uint8_t*)malloc(data->size);
        if (!copy) return CTERMYRDP_STATUS_INTERNAL_ERROR;
        memcpy(copy, data->data, data->size);
    }
    EnterCriticalSection(&session->context_lock);
    free(session->pending_tx_data);
    session->pending_tx_data = copy;
    session->pending_tx_size = copy ? data->size : 0;
    session->pending_tx_format = data->format ? data->format : TERMY_CF_UNICODETEXT;
    UINT rc = termy_cliprdr_send_format_list(session->cliprdr,
                                             session->pending_tx_format);
    LeaveCriticalSection(&session->context_lock);
    return rc == CHANNEL_RC_OK ? CTERMYRDP_STATUS_OK
                               : CTERMYRDP_STATUS_CHANNEL_ERROR;
}

ctermyrdp_status ctermyrdp_submit_drive_response(
    ctermyrdp_session*              session,
    const ctermyrdp_drive_response* response)
{
    if (!session) return CTERMYRDP_STATUS_NO_SESSION;
    if (!response) return CTERMYRDP_STATUS_INVALID_ARG;
    /* rdpdr device IO completion is driven internally by FreeRDP's drive
     * device once FreeRDP_RedirectDrives + a drive path are configured; the
     * shim does not hand-roll IRP completions (spec scope: folder-drive via
     * FreeRDP's own drive client). Accepted no-op for the managed path. */
    if (!session->rdpdr) return CTERMYRDP_STATUS_CHANNEL_ERROR;
    return CTERMYRDP_STATUS_OK;
}

ctermyrdp_status ctermyrdp_submit_audio_format(
    ctermyrdp_session*            session,
    const ctermyrdp_audio_format* format)
{
    if (!session) return CTERMYRDP_STATUS_NO_SESSION;
    if (!format) return CTERMYRDP_STATUS_INVALID_ARG;
    /* Accepted no-op. PCM format negotiation is owned entirely by FreeRDP's
     * rdpsnd_main.c together with the vendored "termy" subsystem's
     * FormatSupported (PCM-only) gate (spec §6); nothing in the public API
     * drives it, so this entry point has no work to do. Retained for ABI
     * stability and the symmetric submit_* surface. */
    return CTERMYRDP_STATUS_OK;
}

/* ── Disconnect / destroy ─────────────────────────────────────────────────── */

void ctermyrdp_disconnect(ctermyrdp_session* session)
{
    if (!session) return;
    atomic_store_explicit(&session->disconnect_requested, 1,
                          memory_order_relaxed);
    if (session->instance && session->connected) {
        freerdp_abort_connect_context(&session->context->_p);
    }
}

void ctermyrdp_destroy(ctermyrdp_session* session)
{
    if (!session) return;

    if (session->instance && session->connected) {
        freerdp_disconnect(session->instance);
    }
    if (session->context) {
        freerdp_client_context_free(&session->context->_p);
    }

    ctermyrdp_queued_event* n;
    while ((n = dequeue(session)) != NULL) free_queued(n);
    DeleteCriticalSection(&session->context_lock);
    DeleteCriticalSection(&session->queue_lock);

    free(session->pending_tx_data);
    scrub_free(&session->password);
    free(session->host);
    free(session->username);
    free(session->domain);
    free(session);
}
