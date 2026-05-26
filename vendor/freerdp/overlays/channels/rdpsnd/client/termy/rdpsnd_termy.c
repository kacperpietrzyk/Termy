/**
 * FreeRDP: A Remote Desktop Protocol Implementation
 * Audio Output Virtual Channel — Termy custom PCM subsystem
 *
 * Vendored build-time rdpsnd subsystem for Termy (M5, design spec §6 +
 * its 2026-05-19 plan-sync mechanism correction). This file is dropped
 * into channels/rdpsnd/client/termy/ by script/build_freerdp.sh's overlay
 * hook and compiled into libfreerdp-client3.a as the static "termy"
 * rdpsnd subsystem (registered via add_channel_client_subsystem in the
 * parent CMakeLists; selected at connect via the rdpsnd channel arg
 * "sys:termy"). It does NOT open any audio device — it forwards received
 * PCM out of FreeRDP into Termy's CTermyRDP shim, which routes it to the
 * app-side AVAudioEngine player (RDPAudioOutputPlayer). This deliberately
 * bypasses FreeRDP's native CoreAudio "mac" subsystem (upstream #6882).
 *
 * PCM only: FormatSupported() accepts WAVE_FORMAT_PCM exclusively. With
 * Opus/AAC/GSM codec deps off in the build (spec §1), rdpsnd_main.c's
 * freerdp_dsp_decode handles any non-PCM the server sends down to PCM
 * before Play; this subsystem additionally rejects non-PCM at the
 * FormatSupported gate so only linear PCM is ever delivered upward.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * (mirrors the FreeRDP fake subsystem this is modelled on).
 */

#include <freerdp/config.h>

#include <stdlib.h>
#include <string.h>

#include <winpr/crt.h>

#include <freerdp/types.h>
#include <freerdp/settings.h>
#include <freerdp/codec/audio.h>

#include "rdpsnd_main.h"

/* Bridge into the CTermyRDP shim. Declared in the shim's internal header;
 * the symbol is resolved at app-link time because both this subsystem
 * (inside libfreerdp-client3.a) and ctermyrdp.c are statically linked into
 * the Termy binary. No runtime function-pointer registration is needed —
 * static linkage is the registration. Kept FreeRDP-type-free at the public
 * boundary: the rdpContext and AUDIO_FORMAT pointers appear only in this
 * internal seam, never in ctermyrdp.h. */
extern void ctermyrdp_rdpsnd_termy_deliver_pcm(rdpContext* context,
                                               const AUDIO_FORMAT* format,
                                               const BYTE* data, size_t size);

typedef struct
{
	rdpsndDevicePlugin device;
	AUDIO_FORMAT format; /* last format from Open(); used by Play() fallback */
	BOOL haveFormat;
} rdpsndTermyPlugin;

static BOOL rdpsnd_termy_format_supported(rdpsndDevicePlugin* device,
                                          const AUDIO_FORMAT* format)
{
	WINPR_UNUSED(device);
	if (!format)
		return FALSE;
	/* PCM-only enforcement (spec §1). Non-PCM is decoded to PCM upstream
	 * by rdpsnd_main.c before it would ever reach Play/PlayEx.
	 *
	 * Task 6 tightening (16-bit only): RDPAudioOutputPlayer.play hard-
	 * requires .pcmSigned16LittleEndian, and at cutover that constraint
	 * becomes load-bearing — there is no longer any other player path.
	 * Reject any non-16-bit PCM at this gate so negotiation never converges
	 * on a sample width the player cannot deliver. (8/24/32-bit PCM
	 * upstream would otherwise be considered "supported" here even though
	 * the player would later throw.) */
	return (format->wFormatTag == WAVE_FORMAT_PCM
	        && format->wBitsPerSample == 16)
	           ? TRUE
	           : FALSE;
}

static BOOL rdpsnd_termy_open(rdpsndDevicePlugin* device, const AUDIO_FORMAT* format,
                              UINT32 latency)
{
	rdpsndTermyPlugin* termy = (rdpsndTermyPlugin*)device;
	WINPR_UNUSED(latency);
	if (!termy)
		return FALSE;
	if (format)
	{
		termy->format = *format;
		termy->format.data = NULL; /* do not retain server-owned pointer */
		termy->haveFormat = TRUE;
	}
	return TRUE;
}

static void rdpsnd_termy_close(rdpsndDevicePlugin* device)
{
	rdpsndTermyPlugin* termy = (rdpsndTermyPlugin*)device;
	if (termy)
		termy->haveFormat = FALSE;
}

static UINT32 rdpsnd_termy_get_volume(rdpsndDevicePlugin* device)
{
	WINPR_UNUSED(device);
	/* Output volume is governed app-side by the AVAudioEngine player /
	 * macOS; report unity (max both channels) to the server. */
	return 0xFFFFFFFF;
}

static BOOL rdpsnd_termy_set_volume(rdpsndDevicePlugin* device, UINT32 value)
{
	WINPR_UNUSED(device);
	WINPR_UNUSED(value);
	return TRUE;
}

/* PlayEx is preferred by rdpsnd_main.c: it carries the negotiated
 * AUDIO_FORMAT alongside the (already PCM-decoded) sample bytes. Forward
 * straight to the shim. */
static UINT rdpsnd_termy_play_ex(rdpsndDevicePlugin* device, const AUDIO_FORMAT* format,
                                 const BYTE* data, size_t size)
{
	if (device && device->rdpsnd && format && data && size > 0)
	{
		rdpContext* ctx = freerdp_rdpsnd_get_context(device->rdpsnd);
		if (ctx)
			ctermyrdp_rdpsnd_termy_deliver_pcm(ctx, format, data, size);
	}
	return 0; /* latency contribution in ms; 0 = none reported */
}

/* Defensive fallback: rdpsnd_main.c calls Play only when PlayEx is NULL.
 * We always set PlayEx, so this should not fire — but if it ever does,
 * use the format cached at Open() time. */
static UINT rdpsnd_termy_play(rdpsndDevicePlugin* device, const BYTE* data, size_t size)
{
	rdpsndTermyPlugin* termy = (rdpsndTermyPlugin*)device;
	if (termy && termy->device.rdpsnd && termy->haveFormat && data && size > 0)
	{
		rdpContext* ctx = freerdp_rdpsnd_get_context(termy->device.rdpsnd);
		if (ctx)
			ctermyrdp_rdpsnd_termy_deliver_pcm(ctx, &termy->format, data, size);
	}
	return 0;
}

static void rdpsnd_termy_free(rdpsndDevicePlugin* device)
{
	rdpsndTermyPlugin* termy = (rdpsndTermyPlugin*)device;
	if (termy)
		free(termy);
}

/**
 * Static subsystem entry point. The name is fixed by FreeRDP's static
 * channel-table generator: "<subsystem>_freerdp_rdpsnd_client_subsystem_entry"
 * → termy_freerdp_rdpsnd_client_subsystem_entry. Registered in the table
 * because the parent CMakeLists calls
 * add_channel_client_subsystem(${MODULE_PREFIX} ${CHANNEL_NAME} "termy" "").
 */
FREERDP_ENTRY_POINT(UINT VCAPITYPE termy_freerdp_rdpsnd_client_subsystem_entry(
    PFREERDP_RDPSND_DEVICE_ENTRY_POINTS pEntryPoints))
{
	rdpsndTermyPlugin* termy = NULL;

	if (!pEntryPoints)
		return ERROR_INVALID_PARAMETER;

	termy = (rdpsndTermyPlugin*)calloc(1, sizeof(rdpsndTermyPlugin));
	if (!termy)
		return CHANNEL_RC_NO_MEMORY;

	termy->device.FormatSupported = rdpsnd_termy_format_supported;
	termy->device.Open = rdpsnd_termy_open;
	termy->device.GetVolume = rdpsnd_termy_get_volume;
	termy->device.SetVolume = rdpsnd_termy_set_volume;
	termy->device.Play = rdpsnd_termy_play;
	termy->device.PlayEx = rdpsnd_termy_play_ex;
	termy->device.Close = rdpsnd_termy_close;
	termy->device.Free = rdpsnd_termy_free;

	pEntryPoints->pRegisterRdpsndDevice(pEntryPoints->rdpsnd, &termy->device);
	return CHANNEL_RC_OK;
}
