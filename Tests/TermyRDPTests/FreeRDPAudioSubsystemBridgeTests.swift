// FreeRDPAudioSubsystemBridgeTests — TDD for M5 Task 5's NEW C-side seam:
// the vendored "termy" rdpsnd subsystem → ctermyrdp PCM enqueue → queued
// CTERMYRDP_EVENT_AUDIO_PCM → FreeRDPSession.marshal → RDPAudioOutputFrame.
//
// Task 4 already covered marshal(synthetic ctermyrdp_event) → frame. The
// gap this file closes is the C enqueue+copy logic that rdpsnd_termy.c's
// PlayEx feeds (ctermyrdp_internal_enqueue_pcm), driven with SYNTHETIC PCM
// through the REAL session queue (ctermyrdp_create / _test_pop_event /
// _destroy) and then through the REAL instance marshal path so the
// per-session monotonic audioSequence + RDPAudioOutputBridge dedup
// survival are exercised end-to-end — exactly the M5 audio-out half that
// silently regresses if sequences collide.
//
// NO server, NO live connect, NO speaker round-trip (the audible
// server→speaker test is the explicit deferred verification gate, spec §8;
// it is NEVER simulated here). The subsystem source itself
// (rdpsnd_termy.c) is compiled into the gitignored FreeRDP archive and is
// not unit-testable without a server; its PlayEx simply forwards to
// ctermyrdp_rdpsnd_termy_deliver_pcm, whose narrowing+enqueue logic IS
// what these tests pin (the deliver_pcm wrapper is a thin
// rdpContext→session + AUDIO_FORMAT→fields shim over the tested
// ctermyrdp_internal_enqueue_pcm).

import XCTest
import Foundation
import CTermyRDP
import TermyCore
@testable import TermyRDP

// Internal C seams (deliberately NOT in the public ctermyrdp.h module —
// the opaque boundary stays FreeRDP-type-free; Task 7 guards it). Resolved
// by static linkage, the same pattern rdpsnd_termy.c uses to reach the
// bridge. `ctermyrdp_session*` is opaque ⇒ OpaquePointer in Swift.
@_silgen_name("ctermyrdp_internal_enqueue_pcm")
private func ctermyrdp_internal_enqueue_pcm(
    _ session: OpaquePointer,
    _ sampleRate: UInt32,
    _ channels: UInt8,
    _ bitsPerSample: UInt8,
    _ data: UnsafePointer<UInt8>?,
    _ size: Int
) -> Int32

@_silgen_name("ctermyrdp_test_pop_event")
private func ctermyrdp_test_pop_event(
    _ session: OpaquePointer,
    _ outEvent: UnsafeMutablePointer<ctermyrdp_event>,
    _ outBuf0: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int32

final class FreeRDPAudioSubsystemBridgeTests: XCTestCase {

    /// A real (never-connected) shim session with audio redirection OFF, so
    /// apply_settings does not register the rdpsnd channel — the queue/copy
    /// path under test is independent of channel negotiation.
    private func makeSession() -> OpaquePointer {
        var cfg = ctermyrdp_config()
        let host = strdup("test.invalid")
        let user = strdup("u")
        defer { free(host); free(user) }
        cfg.host = UnsafePointer(host)
        cfg.username = UnsafePointer(user)
        cfg.port = 3389
        cfg.resolution = ctermyrdp_resolution(
            width: 8, height: 8, scale_factor_percent: 100)
        cfg.redirections = CTERMYRDP_REDIRECT_NONE
        guard let s = ctermyrdp_create(&cfg) else {
            fatalError("ctermyrdp_create returned NULL")
        }
        return s
    }

    /// Enqueue one synthetic PCM block and pop the produced event. Returns
    /// the event plus the transferred buffer (caller frees) so assertions
    /// can inspect the COPIED bytes after the source is mutated/freed.
    private func enqueueAndPop(
        session: OpaquePointer,
        pcm: [UInt8],
        sampleRate: UInt32,
        channels: UInt8,
        bits: UInt8
    ) -> (event: ctermyrdp_event, buf: UnsafeMutableRawPointer?)? {
        let rc = pcm.withUnsafeBufferPointer { buf in
            ctermyrdp_internal_enqueue_pcm(
                session, sampleRate, channels, bits,
                buf.baseAddress, buf.count)
        }
        guard rc == 1 else { return nil }
        var ev = ctermyrdp_event()
        var raw: UnsafeMutableRawPointer? = nil
        let popped = ctermyrdp_test_pop_event(session, &ev, &raw)
        guard popped == 1 else { return nil }
        return (ev, raw)
    }

    // 1. The enqueue path produces a well-formed AUDIO_PCM event with the
    //    format fields the rdpsnd_termy PlayEx → deliver_pcm path supplies.
    func testEnqueuePCMProducesAudioPCMEventWithFormatFields() {
        let session = makeSession()
        defer { ctermyrdp_destroy(session) }

        var pcm = [UInt8](repeating: 0, count: 96)
        for i in pcm.indices { pcm[i] = UInt8((i * 7) & 0xff) }

        guard let (ev, buf) = enqueueAndPop(
            session: session, pcm: pcm,
            sampleRate: 48_000, channels: 2, bits: 16) else {
            return XCTFail("enqueue/pop failed")
        }
        defer { free(buf) }

        XCTAssertEqual(ev.kind, CTERMYRDP_EVENT_AUDIO_PCM)
        let p = ev.payload.audio_pcm
        XCTAssertEqual(p.sample_rate, 48_000)
        XCTAssertEqual(p.channels, 2)
        XCTAssertEqual(p.bits_per_sample, 16)
        XCTAssertEqual(p.size, 96)
        XCTAssertNotNil(p.pcm_data)
        let out = Array(UnsafeBufferPointer(
            start: p.pcm_data, count: p.size))
        XCTAssertEqual(out, pcm, "enqueued PCM must round-trip byte-exact")
    }

    // 2. The PCM is COPIED into a shim-owned buffer (rdpsnd device contract:
    //    the server-decoded buffer is callback-duration-only). Mutating the
    //    source after enqueue must not change the queued event's bytes.
    func testEnqueuePCMCopiesBufferBeforeReturn() {
        let session = makeSession()
        defer { ctermyrdp_destroy(session) }

        let count = 64
        let src = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        defer { src.deallocate() }
        for i in 0..<count { src[i] = 0xA5 }

        let rc = ctermyrdp_internal_enqueue_pcm(
            session, 44_100, 1, 16, src, count)
        XCTAssertEqual(rc, 1)

        // Mutate the source AFTER enqueue — a non-copying impl would leak this.
        for i in 0..<count { src[i] = 0x00 }

        var ev = ctermyrdp_event()
        var raw: UnsafeMutableRawPointer? = nil
        XCTAssertEqual(ctermyrdp_test_pop_event(session, &ev, &raw), 1)
        defer { free(raw) }

        let p = ev.payload.audio_pcm
        let out = Array(UnsafeBufferPointer(start: p.pcm_data, count: p.size))
        XCTAssertEqual(out, [UInt8](repeating: 0xA5, count: count),
                       "PCM must be copied before ctermyrdp_internal_enqueue_pcm returns")
    }

    // 3. End-to-end: the REAL C enqueue path → REAL instance marshal →
    //    RDPAudioOutputBridge. Three consecutive blocks must each produce a
    //    frame, carry a strictly-increasing per-session sequence, and SURVIVE
    //    the bridge dedup. This is the M5 audio-out gate's regression guard
    //    expressed through the actual subsystem-fed queue (not a hand-built
    //    Swift event as in Task 4's analogous test).
    func testEnqueuedPCMMarshalsToMonotonicFramesThatSurviveBridgeDedup() {
        let cSession = makeSession()
        defer { ctermyrdp_destroy(cSession) }
        let swiftSession = FreeRDPSession.makeForMarshallingTests()

        func nextFrame(_ fill: UInt8) -> RDPAudioOutputFrame? {
            let pcm = [UInt8](repeating: fill, count: 32)
            guard let (ev, buf) = enqueueAndPop(
                session: cSession, pcm: pcm,
                sampleRate: 48_000, channels: 2, bits: 16) else { return nil }
            defer { free(buf) }
            var event = ev
            let marshalled = withUnsafePointer(to: &event) {
                swiftSession.marshal($0)
            }
            guard case .audioOutput(let f)? = marshalled else { return nil }
            return f
        }

        guard let f0 = nextFrame(0x01),
              let f1 = nextFrame(0x02),
              let f2 = nextFrame(0x03) else {
            return XCTFail("subsystem-fed PCM did not marshal to audio frames")
        }

        // Format threaded through from the synthetic PCM.
        XCTAssertEqual(f0.sampleRate, 48_000)
        XCTAssertEqual(f0.channelCount, 2)
        XCTAssertEqual(f0.format, .pcmSigned16LittleEndian)
        XCTAssertEqual(f0.data.count, 32)

        // Per-session monotonic sequence (NOT a constant 0).
        XCTAssertEqual(f1.sequence, f0.sequence + 1)
        XCTAssertEqual(f2.sequence, f1.sequence + 1)

        // The real consumer: every frame must clear RDPAudioOutputBridge's
        // `lastRemoteSequence != frame.sequence` dedup. A constant sequence
        // would silently drop f1/f2 — the exact audio-gate failure mode.
        var bridge = RDPAudioOutputBridge(redirections: [.audioOutput])
        XCTAssertNotNil(bridge.receiveRemoteOutputFrame(f0))
        XCTAssertNotNil(bridge.receiveRemoteOutputFrame(f1),
                        "2nd subsystem-fed audio frame must NOT be dropped by bridge dedup")
        XCTAssertNotNil(bridge.receiveRemoteOutputFrame(f2),
                        "3rd subsystem-fed audio frame must NOT be dropped by bridge dedup")
    }

    // 4. Defensive: empty/NULL PCM is rejected by the enqueue contract
    //    (rc == 0, nothing queued) — the subsystem only forwards size>0
    //    blocks, but the seam must not enqueue a zero-length event that the
    //    marshal path would turn into a spurious empty audio frame.
    func testEnqueueRejectsEmptyPCM() {
        let session = makeSession()
        defer { ctermyrdp_destroy(session) }

        XCTAssertEqual(
            ctermyrdp_internal_enqueue_pcm(session, 48_000, 2, 16, nil, 0), 0)
        let dummy = [UInt8](repeating: 0, count: 4)
        let rcZero = dummy.withUnsafeBufferPointer {
            ctermyrdp_internal_enqueue_pcm(
                session, 48_000, 2, 16, $0.baseAddress, 0)
        }
        XCTAssertEqual(rcZero, 0, "zero-size PCM must not enqueue")

        var ev = ctermyrdp_event()
        var raw: UnsafeMutableRawPointer? = nil
        XCTAssertEqual(ctermyrdp_test_pop_event(session, &ev, &raw), 0,
                       "no event should have been queued")
    }
}
