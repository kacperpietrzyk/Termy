// FreeRDPSessionTests — TDD coverage for the FreeRDP wrapper's tested seam.
//
// Scope (spec §8): the C event-sink marshalling trampoline, the
// ctermyrdp_status → RDPDisconnectReason mapping, the
// freeRDPSettings(from:) descriptor→settings conversion, and the
// Keychain→password credential resolution + buffer zeroing. Driven by a
// fake in-process sink + synthetic ctermyrdp_event/buffer inputs ONLY — no
// FreeRDP process, no RDP server, no live connect. The real-server connect +
// bitmap render + audible-audio round-trip is the explicit deferred
// verification gate (spec §8) and is NEVER simulated here.

import XCTest
import Foundation
import CTermyRDP
import TermyCore
@testable import TermyRDP

final class FreeRDPSessionMarshallingTests: XCTestCase {

    // MARK: FRAME → RDPRemoteDesktopFrame (BGRA8, sequence-stamped)

    func testFrameEventMarshalsToDesktopFrame() {
        let width: UInt32 = 4
        let height: UInt32 = 3
        var pixels = [UInt8](repeating: 0, count: Int(width * height) * 4)
        for i in pixels.indices { pixels[i] = UInt8(i & 0xff) }

        let event = pixels.withUnsafeBufferPointer { buf -> RDPTransportEvent? in
            var ev = ctermyrdp_event()
            ev.kind = CTERMYRDP_EVENT_FRAME
            ev.payload.frame = ctermyrdp_frame_payload(
                bgra_pixels: buf.baseAddress,
                width: width,
                height: height,
                sequence_number: 42
            )
            return withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        }

        guard case .desktopFrame(let frame)? = event else {
            return XCTFail("expected .desktopFrame, got \(String(describing: event))")
        }
        XCTAssertEqual(frame.width, 4)
        XCTAssertEqual(frame.height, 3)
        XCTAssertEqual(frame.sequence, 42)
        XCTAssertEqual(frame.pixelFormat, .bgra8)
        XCTAssertEqual(frame.data.count, Int(width * height) * 4)
        XCTAssertTrue(frame.hasValidPayload)
        XCTAssertEqual(Array(frame.data), pixels)
    }

    // The header's callback contract: payload pointers are valid ONLY for the
    // callback duration. The trampoline MUST copy. Proven by mutating then
    // freeing the source buffer AFTER marshalling and asserting the produced
    // Swift value is unaffected.
    func testFrameMarshallingCopiesBufferBeforeReturn() {
        let width: UInt32 = 2
        let height: UInt32 = 2
        let count = Int(width * height) * 4
        let raw = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        for i in 0..<count { raw[i] = 0xAB }

        var ev = ctermyrdp_event()
        ev.kind = CTERMYRDP_EVENT_FRAME
        ev.payload.frame = ctermyrdp_frame_payload(
            bgra_pixels: raw, width: width, height: height, sequence_number: 7
        )
        let event = withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }

        // Corrupt then free the source buffer (simulating the shim reclaiming it).
        for i in 0..<count { raw[i] = 0x00 }
        raw.deallocate()

        guard case .desktopFrame(let frame)? = event else {
            return XCTFail("expected .desktopFrame")
        }
        XCTAssertEqual(Array(frame.data), [UInt8](repeating: 0xAB, count: count),
                       "trampoline must have copied the buffer before the callback returned")
    }

    // MARK: CLIPBOARD_RX → .remoteClipboard(text:sequence:)

    func testClipboardUnicodeTextMarshalsToRemoteClipboard() {
        // CF_UNICODETEXT (13): UTF-16LE, NUL-terminated.
        let text = "héllo→"
        var utf16: [UInt16] = Array(text.utf16)
        utf16.append(0) // NUL terminator (server convention)
        let bytes = utf16.withUnsafeBufferPointer { Data(buffer: $0) }

        let event = bytes.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> RDPTransportEvent? in
            var ev = ctermyrdp_event()
            ev.kind = CTERMYRDP_EVENT_CLIPBOARD_RX
            ev.payload.clipboard_rx = ctermyrdp_clipboard_rx_payload(
                data: raw.bindMemory(to: UInt8.self).baseAddress,
                size: bytes.count,
                format: 13 // CF_UNICODETEXT
            )
            return withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        }

        guard case .remoteClipboard(let received, _)? = event else {
            return XCTFail("expected .remoteClipboard, got \(String(describing: event))")
        }
        XCTAssertEqual(received, text)
    }

    func testClipboardSequenceIsMonotonicPerSession() {
        let session = FreeRDPSession.makeForMarshallingTests()
        func clip(_ s: String) -> Int {
            var u: [UInt16] = Array(s.utf16); u.append(0)
            let d = u.withUnsafeBufferPointer { Data(buffer: $0) }
            return d.withUnsafeBytes { raw -> Int in
                var ev = ctermyrdp_event()
                ev.kind = CTERMYRDP_EVENT_CLIPBOARD_RX
                ev.payload.clipboard_rx = ctermyrdp_clipboard_rx_payload(
                    data: raw.bindMemory(to: UInt8.self).baseAddress, size: d.count, format: 13)
                let e = withUnsafePointer(to: &ev) { session.marshal($0) }
                guard case .remoteClipboard(_, let seq)? = e else { return -1 }
                return seq
            }
        }
        let a = clip("one")
        let b = clip("two")
        XCTAssertGreaterThanOrEqual(a, 0)
        XCTAssertEqual(b, a + 1, "clipboard sequence must increase monotonically per session")
    }

    // MARK: DRIVE_REQ → .driveHandshake(.deviceIORequest)

    func testDriveRequestMarshalsToDriveHandshake() {
        let path = "/remote/dir"
        let event = path.withCString { cpath -> RDPTransportEvent? in
            var ev = ctermyrdp_event()
            ev.kind = CTERMYRDP_EVENT_DRIVE_REQ
            ev.payload.drive_req = ctermyrdp_drive_req_payload(
                request_id: 11,
                device_id: 5,
                major_function: 0x03, // IRP_MJ_READ
                minor_function: 0,
                path: cpath
            )
            return withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        }

        guard case .driveHandshake(.deviceIORequest(let req))? = event else {
            return XCTFail("expected .driveHandshake(.deviceIORequest), got \(String(describing: event))")
        }
        XCTAssertEqual(req.deviceID, 5)
        XCTAssertEqual(req.completionID, 11)
        XCTAssertEqual(req.majorFunction, .read)
        XCTAssertEqual(req.rawMajorFunction, 0x03)
    }

    func testDriveRequestWithNullPathDoesNotCrash() {
        var ev = ctermyrdp_event()
        ev.kind = CTERMYRDP_EVENT_DRIVE_REQ
        ev.payload.drive_req = ctermyrdp_drive_req_payload(
            request_id: 1, device_id: 1, major_function: 0x02, minor_function: 0, path: nil)
        let event = withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        guard case .driveHandshake(.deviceIORequest(let req))? = event else {
            return XCTFail("expected .driveHandshake(.deviceIORequest)")
        }
        XCTAssertEqual(req.majorFunction, .close)
    }

    // MARK: AUDIO_PCM → RDPAudioOutputFrame

    func testAudioPCMMarshalsToAudioOutputFrame() {
        var samples = [UInt8](repeating: 0, count: 64)
        for i in samples.indices { samples[i] = UInt8((i * 3) & 0xff) }

        let event = samples.withUnsafeBufferPointer { buf -> RDPTransportEvent? in
            var ev = ctermyrdp_event()
            ev.kind = CTERMYRDP_EVENT_AUDIO_PCM
            ev.payload.audio_pcm = ctermyrdp_audio_pcm_payload(
                pcm_data: buf.baseAddress,
                size: buf.count,
                sample_rate: 44_100,
                channels: 2,
                bits_per_sample: 16
            )
            return withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        }

        guard case .audioOutput(let frame)? = event else {
            return XCTFail("expected .audioOutput, got \(String(describing: event))")
        }
        XCTAssertEqual(frame.sampleRate, 44_100)
        XCTAssertEqual(frame.channelCount, 2)
        XCTAssertEqual(frame.format, .pcmSigned16LittleEndian)
        XCTAssertEqual(frame.data.count, 64)
        XCTAssertEqual(Array(frame.data), samples)
    }

    // Regression: audio frames must carry an independent per-session
    // monotonic sequence. Hardcoding 0 makes RDPAudioOutputBridge's
    // `lastRemoteSequence != frame.sequence` guard drop every frame after
    // the first — exactly the M5 audio-out gate failing silently.
    func testAudioSequenceIsMonotonicPerSessionAndSurvivesBridgeDedup() {
        let session = FreeRDPSession.makeForMarshallingTests()
        func audio() -> RDPAudioOutputFrame? {
            var pcm = [UInt8](repeating: 0x11, count: 16)
            return pcm.withUnsafeMutableBufferPointer { buf -> RDPAudioOutputFrame? in
                var ev = ctermyrdp_event()
                ev.kind = CTERMYRDP_EVENT_AUDIO_PCM
                ev.payload.audio_pcm = ctermyrdp_audio_pcm_payload(
                    pcm_data: buf.baseAddress, size: buf.count,
                    sample_rate: 48_000, channels: 2, bits_per_sample: 16)
                let e = withUnsafePointer(to: &ev) { session.marshal($0) }
                guard case .audioOutput(let f)? = e else { return nil }
                return f
            }
        }
        guard let f0 = audio(), let f1 = audio(), let f2 = audio() else {
            return XCTFail("audio marshalling failed")
        }
        XCTAssertEqual(f1.sequence, f0.sequence + 1)
        XCTAssertEqual(f2.sequence, f1.sequence + 1)

        // Prove the produced frames actually survive the downstream dedup
        // (the real consumer path) — not just that the integers differ.
        var bridge = RDPAudioOutputBridge(redirections: [.audioOutput])
        XCTAssertNotNil(bridge.receiveRemoteOutputFrame(f0))
        XCTAssertNotNil(bridge.receiveRemoteOutputFrame(f1),
                        "second audio frame must NOT be dropped by the bridge dedup")
        XCTAssertNotNil(bridge.receiveRemoteOutputFrame(f2))
    }

    // Frames must carry an independent per-session monotonic sequence AND
    // the descriptor scale; consecutive frames must survive RDPFrameBuffer.
    func testFrameSequenceMonotonicAndScaleThreadedThroughInstanceMarshal() {
        let session = FreeRDPSession.makeForMarshallingTests(scale: 2)
        func frame(_ fill: UInt8) -> RDPRemoteDesktopFrame? {
            var px = [UInt8](repeating: fill, count: 2 * 2 * 4)
            return px.withUnsafeMutableBufferPointer { buf -> RDPRemoteDesktopFrame? in
                var ev = ctermyrdp_event()
                ev.kind = CTERMYRDP_EVENT_FRAME
                ev.payload.frame = ctermyrdp_frame_payload(
                    bgra_pixels: buf.baseAddress, width: 2, height: 2,
                    sequence_number: 999 /* C value must be overridden */)
                let e = withUnsafePointer(to: &ev) { session.marshal($0) }
                guard case .desktopFrame(let f)? = e else { return nil }
                return f
            }
        }
        guard let a = frame(0x10), let b = frame(0x20) else {
            return XCTFail("frame marshalling failed")
        }
        XCTAssertEqual(a.scale, 2, "descriptor scale must be threaded into the frame")
        XCTAssertEqual(b.sequence, a.sequence + 1,
                       "frame sequence must be per-session monotonic, not the C-supplied 999")
        XCTAssertNotEqual(a.sequence, 999)

        var fb = RDPFrameBuffer()
        XCTAssertNotNil(fb.apply(a))
        XCTAssertNotNil(fb.apply(b),
                        "second frame must NOT be dropped by RDPFrameBuffer dedup")
    }

    func testAudioPCMMarshallingCopiesBuffer() {
        let count = 32
        let raw = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        for i in 0..<count { raw[i] = 0x5A }
        var ev = ctermyrdp_event()
        ev.kind = CTERMYRDP_EVENT_AUDIO_PCM
        ev.payload.audio_pcm = ctermyrdp_audio_pcm_payload(
            pcm_data: raw, size: count, sample_rate: 48_000, channels: 1, bits_per_sample: 16)
        let event = withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        for i in 0..<count { raw[i] = 0xFF }
        raw.deallocate()
        guard case .audioOutput(let frame)? = event else { return XCTFail("expected .audioOutput") }
        XCTAssertEqual(Array(frame.data), [UInt8](repeating: 0x5A, count: count),
                       "audio PCM must be copied before the callback returns")
    }

    // MARK: DISCONNECT → .disconnected(reason)

    func testDisconnectEventMarshalsToDisconnectedWithMappedReason() {
        var ev = ctermyrdp_event()
        ev.kind = CTERMYRDP_EVENT_DISCONNECT
        ev.payload.disconnect = ctermyrdp_disconnect_payload(
            status_code: CTERMYRDP_STATUS_NETWORK_ERROR,
            last_error_code: 0x2000_0009
        )
        let event = withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        guard case .disconnected(let reason)? = event else {
            return XCTFail("expected .disconnected, got \(String(describing: event))")
        }
        XCTAssertEqual(reason, .networkFailure)
    }

    func testDisconnectUserInitiatedMapsToUserInitiated() {
        var ev = ctermyrdp_event()
        ev.kind = CTERMYRDP_EVENT_DISCONNECT
        ev.payload.disconnect = ctermyrdp_disconnect_payload(
            status_code: CTERMYRDP_STATUS_DISCONNECTED,
            last_error_code: 0
        )
        let event = withUnsafePointer(to: &ev) { FreeRDPSession.marshalEvent($0) }
        guard case .disconnected(.userInitiated)? = event else {
            return XCTFail("expected .disconnected(.userInitiated), got \(String(describing: event))")
        }
    }
}

final class FreeRDPSessionStatusMappingTests: XCTestCase {

    func testUserInitiatedDisconnect() {
        // Graceful disconnect (no error code) → userInitiated → no reconnect.
        XCTAssertEqual(
            FreeRDPSession.disconnectReason(status: CTERMYRDP_STATUS_DISCONNECTED, lastError: 0),
            .userInitiated
        )
    }

    func testNetworkErrorMapsToNetworkFailure() {
        XCTAssertEqual(
            FreeRDPSession.disconnectReason(status: CTERMYRDP_STATUS_NETWORK_ERROR, lastError: 123),
            .networkFailure
        )
    }

    func testConnectFailureMapsToTransportErrorCarryingFreeRDPCode() {
        XCTAssertEqual(
            FreeRDPSession.disconnectReason(status: CTERMYRDP_STATUS_CONNECT_FAILED, lastError: 0x2000_0001),
            .transportError(0x2000_0001)
        )
    }

    func testAuthFailureMapsToTransportError() {
        XCTAssertEqual(
            FreeRDPSession.disconnectReason(status: CTERMYRDP_STATUS_AUTH_FAILED, lastError: 0x0002_0009),
            .transportError(0x0002_0009)
        )
    }

    func testTLSFailureMapsToTransportError() {
        XCTAssertEqual(
            FreeRDPSession.disconnectReason(status: CTERMYRDP_STATUS_TLS_FAILED, lastError: 0x0102_0005),
            .transportError(0x0102_0005)
        )
    }

    func testChannelErrorMapsToTransportError() {
        XCTAssertEqual(
            FreeRDPSession.disconnectReason(status: CTERMYRDP_STATUS_CHANNEL_ERROR, lastError: 99),
            .transportError(99)
        )
    }

    func testDisconnectedWithErrorCodeIsTransportErrorNotUserInitiated() {
        // DISCONNECTED but with a non-zero protocol error code: not a clean
        // user-initiated close — surface as transportError so the reconnect
        // policy can retry.
        XCTAssertEqual(
            FreeRDPSession.disconnectReason(status: CTERMYRDP_STATUS_DISCONNECTED, lastError: 0x2000_000C),
            .transportError(0x2000_000C)
        )
    }

    func testReasonFeedsExistingLifecycleReconnectPath() throws {
        // Status mapping must surface through the EXISTING lifecycle/reconnect
        // path with no new app error UX. networkFailure → reconnect plan;
        // userInitiated → terminal, no plan.
        let profile = ConnectionProfile.rdp(name: "h", host: "h", user: "u",
                                            gateway: nil, credential: .keychain("a"))
        let descriptor = try RDPSessionDescriptor(
            profile: profile,
            resolution: RDPResolution(width: 800, height: 600),
            scale: 1,
            localFolderPath: nil
        )
        var lifecycle = RDPSessionLifecycle(descriptor: descriptor)

        let netReason = FreeRDPSession.disconnectReason(
            status: CTERMYRDP_STATUS_NETWORK_ERROR, lastError: 0)
        let plan = lifecycle.handleDisconnect(reason: netReason)
        XCTAssertNotNil(plan, "networkFailure must drive the existing reconnect path")

        var lifecycle2 = RDPSessionLifecycle(descriptor: descriptor)
        let userReason = FreeRDPSession.disconnectReason(
            status: CTERMYRDP_STATUS_DISCONNECTED, lastError: 0)
        XCTAssertNil(lifecycle2.handleDisconnect(reason: userReason),
                     "userInitiated must terminate without a reconnect plan")
    }
}

final class FreeRDPSessionCredentialTests: XCTestCase {

    private func descriptor(
        secretReferences: [SecretReference],
        user: String = "CORP\\alice"
    ) throws -> RDPSessionDescriptor {
        let profile = ConnectionProfile(
            kind: .rdp,
            name: "n",
            host: "host.example",
            user: user,
            port: 3389,
            gateway: nil,
            groupPath: nil,
            sshOptions: [:],
            terminalOutputMode: .stream,
            secretReferences: secretReferences
        )
        return try RDPSessionDescriptor(
            profile: profile,
            resolution: RDPResolution(width: 1280, height: 720),
            scale: 1,
            localFolderPath: nil
        )
    }

    func testResolvesPasswordFromInjectedStoreAndPassesPlaintext() throws {
        let ref = SecretReference.keychain("acct-1")
        let desc = try descriptor(secretReferences: [ref])
        let store = FakeSecretLoader(secrets: [ref: Data("s3cr3t".utf8)])

        var seen: String?
        try FreeRDPSession.withResolvedPassword(
            for: desc, secretLoader: store.load
        ) { ptr in
            seen = String(cString: ptr)
        }
        XCTAssertEqual(seen, "s3cr3t")
    }

    func testMissingSecretReferenceThrowsTypedError() throws {
        let desc = try descriptor(secretReferences: [])
        let store = FakeSecretLoader(secrets: [:])
        XCTAssertThrowsError(
            try FreeRDPSession.withResolvedPassword(for: desc, secretLoader: store.load) { _ in }
        ) { error in
            XCTAssertEqual(error as? FreeRDPCredentialError, .missingSecretReference)
        }
    }

    func testMissingSecretThrowsTypedError() throws {
        let ref = SecretReference.keychain("absent")
        let desc = try descriptor(secretReferences: [ref])
        let store = FakeSecretLoader(secrets: [:]) // ref not present → nil
        XCTAssertThrowsError(
            try FreeRDPSession.withResolvedPassword(for: desc, secretLoader: store.load) { _ in }
        ) { error in
            XCTAssertEqual(error as? FreeRDPCredentialError, .missingSecret(ref))
        }
    }

    func testInvalidUTF8SecretThrowsTypedError() throws {
        let ref = SecretReference.keychain("bad")
        let desc = try descriptor(secretReferences: [ref])
        // 0xFF 0xFE is not valid UTF-8.
        let store = FakeSecretLoader(secrets: [ref: Data([0xFF, 0xFE, 0xFD])])
        XCTAssertThrowsError(
            try FreeRDPSession.withResolvedPassword(for: desc, secretLoader: store.load) { _ in }
        ) { error in
            XCTAssertEqual(error as? FreeRDPCredentialError, .invalidUTF8Secret(ref))
        }
    }

    // (a) DELIVERY — assert the resolved plaintext is correctly handed to
    // the C-config consumer. The assertion is made strictly INSIDE `body`,
    // copying the C string into test-owned storage while the buffer is still
    // alive. No pointer escapes the closure (the post-return read in the
    // prior version was a use-after-free of the freed ContiguousArray).
    func testPasswordIsDeliveredAsCStringToBody() throws {
        let ref = SecretReference.keychain("z")
        let desc = try descriptor(secretReferences: [ref])
        let store = FakeSecretLoader(secrets: [ref: Data("passw0rd".utf8)])

        var deliveredInsideBody: String?
        try FreeRDPSession.withResolvedPassword(for: desc, secretLoader: store.load) { ptr in
            // Copy out of the live buffer; do NOT let the pointer escape.
            XCTAssertEqual(strlen(ptr), 8)
            deliveredInsideBody = String(cString: ptr)
        }
        XCTAssertEqual(deliveredInsideBody, "passw0rd",
                       "resolved plaintext must reach body as a NUL-terminated C string")
    }

    // The error path must still propagate (and the buffer must still be
    // wiped — asserted as a contract in
    // testWithResolvedPasswordZeroesBufferViaDeferContract). We assert here
    // only that a throwing body's error propagates unchanged; no freed
    // memory is read.
    func testThrowingBodyPropagatesErrorUnchanged() throws {
        struct BodyError: Error, Equatable {}
        let ref = SecretReference.keychain("z2")
        let desc = try descriptor(secretReferences: [ref])
        let store = FakeSecretLoader(secrets: [ref: Data("leakme!!".utf8)])

        var enteredBody = false
        XCTAssertThrowsError(
            try FreeRDPSession.withResolvedPassword(for: desc, secretLoader: store.load) { ptr in
                enteredBody = true
                XCTAssertEqual(strlen(ptr), 8) // delivered before the throw
                throw BodyError()
            }
        ) { error in
            XCTAssertEqual(error as? BodyError, BodyError())
        }
        XCTAssertTrue(enteredBody)
    }

    // (b) ZEROING CONTRACT — the plaintext buffer cannot be observed zeroed
    // at runtime without a use-after-free (the ContiguousArray storage is
    // freed the instant withResolvedPassword unwinds). Instead assert the
    // production mechanism *structurally*: withResolvedPassword must wipe the
    // buffer with memset_s INSIDE a `defer`, so the wipe runs on BOTH the
    // normal-return and the throw paths before the function unwinds. This is
    // the repo's established source-scan guard idiom (cf.
    // TermyRDPTests.testTermyCoreHasNoRDPBackEdge); it is neither UB nor a
    // tautology — removing the `defer`, the `memset_s`, or moving the wipe
    // out of withResolvedPassword fails this test.
    func testWithResolvedPasswordZeroesBufferViaDeferContract() throws {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()  // Tests/TermyRDPTests
            .deletingLastPathComponent()              // Tests
            .deletingLastPathComponent()              // repo root
        let source = root.appendingPathComponent(
            "Sources/TermyRDP/FreeRDPSession.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        // Isolate the withResolvedPassword function body.
        guard let fnRange = text.range(
            of: #"static func withResolvedPassword<T>\([\s\S]*?\n    \}"#,
            options: .regularExpression
        ) else {
            return XCTFail("withResolvedPassword(_:) not found — guard cannot verify the zeroing contract")
        }
        let fnBody = String(text[fnRange])

        // The wipe must be a memset_s call lexically inside a `defer { ... }`
        // within withResolvedPassword (so it fires on return AND throw).
        let deferWithMemset = #"defer\s*\{[\s\S]*?memset_s\([\s\S]*?\}"#
        XCTAssertNotNil(
            fnBody.range(of: deferWithMemset, options: .regularExpression),
            "withResolvedPassword must zero the plaintext buffer with memset_s inside a `defer` (covers both the return and the throw paths)"
        )
        XCTAssertTrue(
            fnBody.contains("memset_s"),
            "the credential buffer wipe must use memset_s (not a compiler-elidable memset)"
        )
    }

    private struct FakeSecretLoader {
        let secrets: [SecretReference: Data]
        func load(_ ref: SecretReference) throws -> Data? { secrets[ref] }
    }
}

final class FreeRDPSettingsMappingTests: XCTestCase {

    private func descriptor(
        redirections explicitFolder: String?,
        width: Int = 1920, height: Int = 1080, scale: Double = 2
    ) throws -> RDPSessionDescriptor {
        let profile = ConnectionProfile.rdp(
            name: "n", host: "rdp.example", user: "u",
            gateway: nil, credential: .keychain("k")
        )
        return try RDPSessionDescriptor(
            profile: profile,
            resolution: RDPResolution(width: width, height: height),
            scale: scale,
            localFolderPath: explicitFolder
        )
    }

    func testResolutionAndScaleMapping() throws {
        let desc = try descriptor(redirections: nil, width: 2560, height: 1440, scale: 2)
        let settings = FreeRDPSession.freeRDPSettings(from: desc)
        XCTAssertEqual(settings.desktopWidth, 2560)
        XCTAssertEqual(settings.desktopHeight, 1440)
        XCTAssertEqual(settings.desktopScaleFactorPercent, 200)
    }

    func testScaleOneMapsTo100Percent() throws {
        let desc = try descriptor(redirections: nil, scale: 1)
        let settings = FreeRDPSession.freeRDPSettings(from: desc)
        XCTAssertEqual(settings.desktopScaleFactorPercent, 100)
    }

    func testClipboardAndAudioRedirectionsAlwaysOn() throws {
        // RDPSessionDescriptor always appends .clipboard and .audioOutput.
        let desc = try descriptor(redirections: nil)
        let settings = FreeRDPSession.freeRDPSettings(from: desc)
        XCTAssertTrue(settings.redirectClipboard)
        XCTAssertTrue(settings.audioPlayback)
        XCTAssertFalse(settings.redirectDrives, "no localFolderPath ⇒ no drive redirection")
        XCTAssertNil(settings.driveLocalPath)
    }

    func testFolderDriveRedirectionMapping() throws {
        let desc = try descriptor(redirections: "/Users/me/Shared")
        let settings = FreeRDPSession.freeRDPSettings(from: desc)
        XCTAssertTrue(settings.redirectDrives)
        XCTAssertEqual(settings.driveLocalPath, "/Users/me/Shared")
        XCTAssertTrue(settings.redirectClipboard)
        XCTAssertTrue(settings.audioPlayback)
    }

    func testRedirectionFlagsBitfieldForShim() throws {
        let desc = try descriptor(redirections: "/tmp/x")
        let settings = FreeRDPSession.freeRDPSettings(from: desc)
        let flags = settings.redirectionFlags
        XCTAssertNotEqual(flags & CTERMYRDP_REDIRECT_CLIPBOARD, 0)
        XCTAssertNotEqual(flags & CTERMYRDP_REDIRECT_AUDIO, 0)
        XCTAssertNotEqual(flags & CTERMYRDP_REDIRECT_DRIVES, 0)
    }

    func testHostAndUserCarriedIntoSettings() throws {
        let desc = try descriptor(redirections: nil)
        let settings = FreeRDPSession.freeRDPSettings(from: desc)
        XCTAssertEqual(settings.host, "rdp.example")
        XCTAssertEqual(settings.username, "u")
    }
}
