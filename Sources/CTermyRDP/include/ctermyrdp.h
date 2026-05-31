/* ctermyrdp.h — public C API for the CTermyRDP shim.
 *
 * Opaque-handle design: no FreeRDP types cross this boundary.
 * Only <stdint.h>, <stddef.h>, and <stdbool.h> are pulled in.
 * CTermyRDP's .c implementation includes <freerdp/...> internally.
 *
 * § Reference: docs/superpowers/specs/2026-05-19-m5-freerdp-shim-design.md §3
 */

#ifndef CTERMYRDP_H
#define CTERMYRDP_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ── Opaque session handle ──────────────────────────────────────────────── */

typedef struct ctermyrdp_session ctermyrdp_session;

/* ── Status / error codes ────────────────────────────────────────────────── */

typedef enum ctermyrdp_status {
    CTERMYRDP_STATUS_OK                  = 0,
    CTERMYRDP_STATUS_NOT_IMPLEMENTED     = 1,
    CTERMYRDP_STATUS_INVALID_ARG         = 2,
    CTERMYRDP_STATUS_CONNECT_FAILED      = 3,
    CTERMYRDP_STATUS_AUTH_FAILED         = 4,
    CTERMYRDP_STATUS_TLS_FAILED          = 5,
    CTERMYRDP_STATUS_NETWORK_ERROR       = 6,
    CTERMYRDP_STATUS_DISCONNECTED        = 7,
    CTERMYRDP_STATUS_CHANNEL_ERROR       = 8,
    CTERMYRDP_STATUS_NO_SESSION          = 9,
    CTERMYRDP_STATUS_INTERNAL_ERROR      = 10,
} ctermyrdp_status;

/* ── Resolution / scale ──────────────────────────────────────────────────── */

typedef struct ctermyrdp_resolution {
    uint32_t width;
    uint32_t height;
    uint32_t scale_factor_percent; /* 100 = 1:1, 200 = HiDPI ×2 */
} ctermyrdp_resolution;

/* ── Redirection flags (bitfield) ────────────────────────────────────────── */

typedef uint32_t ctermyrdp_redirection_flags;

#define CTERMYRDP_REDIRECT_NONE      (0u)
#define CTERMYRDP_REDIRECT_CLIPBOARD (1u << 0)
#define CTERMYRDP_REDIRECT_DRIVES    (1u << 1)
#define CTERMYRDP_REDIRECT_AUDIO     (1u << 2)

/* ── Session configuration (passed by value; secret fields zeroed after use) */

typedef struct ctermyrdp_config {
    /* Connection target */
    const char*               host;        /* UTF-8, not owned — caller retains */
    uint16_t                  port;        /* default 3389 */
    /* Credentials — zeroed in ctermyrdp_create after copy */
    const char*               username;    /* UTF-8 */
    const char*               domain;      /* UTF-8, may be NULL */
    const char*               password;    /* UTF-8, sensitive */
    /* Display */
    ctermyrdp_resolution      resolution;
    /* Channels */
    ctermyrdp_redirection_flags redirections;
} ctermyrdp_config;

/* ── Event kinds delivered through ctermyrdp_event_sink ─────────────────── */

typedef enum ctermyrdp_event_kind {
    CTERMYRDP_EVENT_FRAME        = 0,  /* full BGRA frame from GDI */
    CTERMYRDP_EVENT_CLIPBOARD_RX = 1,  /* server → client clipboard data */
    CTERMYRDP_EVENT_DRIVE_REQ    = 2,  /* drive-redirect request from server */
    CTERMYRDP_EVENT_AUDIO_PCM    = 3,  /* PCM audio frame from rdpsnd */
    CTERMYRDP_EVENT_DISCONNECT   = 4,  /* session ended */
} ctermyrdp_event_kind;

/* Frame payload (BGRA, stride = width * 4) */
typedef struct ctermyrdp_frame_payload {
    const uint8_t* bgra_pixels;
    uint32_t       width;
    uint32_t       height;
    uint64_t       sequence_number;
} ctermyrdp_frame_payload;

/* Clipboard receive payload */
typedef struct ctermyrdp_clipboard_rx_payload {
    const uint8_t* data;
    size_t         size;
    uint32_t       format; /* CF_UNICODETEXT etc. */
} ctermyrdp_clipboard_rx_payload;

/* Drive request payload */
typedef struct ctermyrdp_drive_req_payload {
    uint32_t    request_id;
    uint32_t    device_id;
    uint8_t     major_function;
    uint8_t     minor_function;
    const char* path;           /* UTF-8, may be NULL */
} ctermyrdp_drive_req_payload;

/* PCM audio frame payload */
typedef struct ctermyrdp_audio_pcm_payload {
    const uint8_t* pcm_data;
    size_t         size;
    uint32_t       sample_rate;
    uint8_t        channels;
    uint8_t        bits_per_sample;
} ctermyrdp_audio_pcm_payload;

/* Disconnect payload */
typedef struct ctermyrdp_disconnect_payload {
    ctermyrdp_status status_code;
    int32_t          last_error_code; /* mapped protocol error code (raw freerdp_get_last_error() value) */
} ctermyrdp_disconnect_payload;

/* Tagged-union event */
typedef struct ctermyrdp_event {
    ctermyrdp_event_kind kind;
    union {
        ctermyrdp_frame_payload        frame;
        ctermyrdp_clipboard_rx_payload clipboard_rx;
        ctermyrdp_drive_req_payload    drive_req;
        ctermyrdp_audio_pcm_payload    audio_pcm;
        ctermyrdp_disconnect_payload   disconnect;
    } payload;
} ctermyrdp_event;

/* Callback invoked by ctermyrdp_pump for each event; user_data is caller's.
 *
 * ── Callback contract ───────────────────────────────────────────────────
 *  • Threading: the callback fires on the *pump thread* (off-main) — the
 *    thread that called ctermyrdp_pump, never the main/UI thread.
 *  • Re-entrancy: the consumer MUST NOT call ctermyrdp_pump (i.e. re-enter
 *    the pump) from within the callback.
 *  • Pointer lifetime: ALL pointers inside the event payload
 *    (frame.bgra_pixels, audio_pcm.pcm_data, clipboard_rx.data,
 *    drive_req.path, and every other payload buffer/string) are valid
 *    ONLY for the duration of this callback invocation. They are owned by
 *    the shim and may be freed or reused the instant the callback returns.
 *    The consumer MUST copy anything it needs to retain beyond return.
 *  TODO(Task 4): confirm and enforce this ownership model at the Swift
 *  trampoline. */
typedef void (*ctermyrdp_event_callback)(const ctermyrdp_event* event,
                                         void*                   user_data);

/* Event sink: callback + opaque context */
typedef struct ctermyrdp_event_sink {
    ctermyrdp_event_callback callback;
    void*                    user_data;
} ctermyrdp_event_sink;

/* ── Clipboard send payload (client → server) ───────────────────────────── */

typedef struct ctermyrdp_clipboard_tx {
    const uint8_t* data;
    size_t         size;
    uint32_t       format;
} ctermyrdp_clipboard_tx;

/* ── Keyboard / pointer input ────────────────────────────────────────────── */

typedef struct ctermyrdp_key_event {
    uint32_t scan_code;
    bool     extended; /* e.g. right Alt, numpad Enter */
    bool     key_down;
} ctermyrdp_key_event;

typedef struct ctermyrdp_pointer_event {
    uint16_t  x;
    uint16_t  y;
    uint16_t  flags; /* RDP pointer flags */
} ctermyrdp_pointer_event;

/* ── Drive response ──────────────────────────────────────────────────────── */

typedef struct ctermyrdp_drive_response {
    uint32_t       request_id;
    ctermyrdp_status status;
    const uint8_t* data;   /* may be NULL for write/close responses */
    size_t         size;
} ctermyrdp_drive_response;

/* ── Audio format negotiation ────────────────────────────────────────────── */

typedef struct ctermyrdp_audio_format {
    uint16_t wave_format_tag;  /* WAVE_FORMAT_PCM etc. */
    uint16_t channels;
    uint32_t samples_per_sec;
    uint16_t bits_per_sample;
} ctermyrdp_audio_format;

/* ── Session lifecycle API ───────────────────────────────────────────────── */

/** Create a new session from config. Returns NULL on allocation failure.
 *  Secret fields (password) are zeroed inside after copy. */
ctermyrdp_session* ctermyrdp_create(const ctermyrdp_config* config);

/** Initiate the RDP connection (blocking until protocol-complete or error). */
ctermyrdp_status ctermyrdp_connect(ctermyrdp_session* session);

/** Non-blocking pump: deliver pending events through sink. Call on a
 *  dedicated thread; returns CTERMYRDP_STATUS_DISCONNECTED when done. */
ctermyrdp_status ctermyrdp_pump(ctermyrdp_session*       session,
                                const ctermyrdp_event_sink* sink);

/** Send a keyboard scancode event to the server. */
ctermyrdp_status ctermyrdp_send_key(ctermyrdp_session*       session,
                                    const ctermyrdp_key_event* event);

/** Send a pointer (mouse) event to the server. */
ctermyrdp_status ctermyrdp_send_pointer(ctermyrdp_session*          session,
                                        const ctermyrdp_pointer_event* event);

/** Send clipboard data from client to server. */
ctermyrdp_status ctermyrdp_send_clipboard(ctermyrdp_session*          session,
                                          const ctermyrdp_clipboard_tx* data);

/** Preferred text paste format (CF_UNICODETEXT > CF_TEXT > CF_OEMTEXT) chosen
 *  from a server-announced format-id list; 0 when none is a known text format.
 *  Pure helper exposed for unit testing the cliprdr handshake's format choice. */
uint32_t ctermyrdp_preferred_paste_format(const uint32_t* formats, size_t count);

/** Reply to a CTERMYRDP_EVENT_DRIVE_REQ event. */
ctermyrdp_status ctermyrdp_submit_drive_response(
    ctermyrdp_session*             session,
    const ctermyrdp_drive_response* response);

/** Submit an audio format accepted by the client (PCM negotiation). */
ctermyrdp_status ctermyrdp_submit_audio_format(
    ctermyrdp_session*           session,
    const ctermyrdp_audio_format* format);

/** Request graceful disconnect. Non-blocking; DISCONNECT event follows. */
void ctermyrdp_disconnect(ctermyrdp_session* session);

/** Destroy session and free all resources. session must not be used after. */
void ctermyrdp_destroy(ctermyrdp_session* session);

#ifdef __cplusplus
}
#endif

#endif /* CTERMYRDP_H */
