// FreeRDPSession — Swift wrapper around the CTermyRDP C shim (FreeRDP 3.26.0).
//
// Spec: docs/superpowers/specs/2026-05-19-m5-freerdp-shim-design.md §3/§4/§7.
//
// Post-Task-6 (cutover landed): this is the sole RDP engine in the codebase.
// The bespoke `RDPLiveConnectionBootstrapper` and its supporting
// CredSSP/NTLMv2/SPNEGO/MCS/connection-sequence stack were deleted in Task
// 6; this wrapper drives FreeRDP 3.26.0 through the CTermyRDP shim.
//
// Responsibilities:
//  • Own exactly one `ctermyrdp_session` on a dedicated off-main queue.
//  • Install the C `ctermyrdp_event_sink` trampoline; marshal each
//    `ctermyrdp_event` into the EXISTING seam value types
//    (`RDPTransportEvent`/`RDPRemoteDesktopFrame`/`RDPAudioOutputFrame`/…)
//    — the app contract is unchanged.
//  • Map `ctermyrdp_status` → `RDPDisconnectReason` (the existing 3-case
//    enum; the FreeRDP code rides in `.transportError`'s Int32).
//  • Resolve `descriptor.secretReferences.first` via an injectable
//    Keychain-backed loader, pass plaintext through `ctermyrdp_config`, and
//    ZERO the buffer once `ctermyrdp_connect` returns (success OR error).
//  • Convert an `RDPSessionDescriptor` into FreeRDP settings inputs via
//    `freeRDPSettings(from:)`.
//
// Buffer-lifetime contract (ctermyrdp.h): every pointer inside an event
// payload is valid ONLY for the callback's duration. The marshalling
// trampoline therefore COPIES every buffer/string before the callback
// returns; the produced Swift values own independent storage.

import Foundation
import TermyCore
import CTermyRDP

// MARK: - Architectural decision: bitmap-compositing path is dead
//
// `ctermyrdp.h` declares CTERMYRDP_EVENT_FRAME as a *full* BGRA frame from
// FreeRDP's GDI (which maintains the complete primary surface) and exposes
// NO partial-rectangle event — by design. FreeRDPSession therefore only ever
// produces whole `RDPRemoteDesktopFrame`s (via `.desktopFrame`); no
// partial-rectangle event ever flows through this trampoline.
//
// Task 6 carried the deletion through: `RDPBitmapUpdate`,
// `RDPBitmapUpdateRectangle`, `RDPFrameBuffer.apply(_ update:)`, the
// `RDPTransportEvent.bitmapUpdate` case, and the router's bitmap arm are
// all removed from `RDPSessionModel.swift`. `RDPFrameBuffer` (the struct
// itself) plus its `apply(_ frame:)` sequence-dedup gate are retained as
// engine-agnostic full-frame dedup state.

// MARK: - Typed credential errors

/// Typed credential resolution errors thrown by `withResolvedPassword`. The
/// three cases mirror what the bespoke `RDPCredSSPNTLMv2CredentialResolver`
/// (deleted in Task 6) emitted, preserving the typed-error contract across
/// the engine swap.
public enum FreeRDPCredentialError: Error, Equatable {
    case missingSecretReference
    case missingSecret(SecretReference)
    case invalidUTF8Secret(SecretReference)
}

// MARK: - FreeRDP settings inputs (pure Swift mirror of ctermyrdp_config)

/// A pure-Swift, Equatable mirror of the connection-relevant settings the
/// shim feeds into FreeRDP. Distinct from `ctermyrdp_config` (whose pointer
/// fields make it neither Equatable nor safe to retain) so the
/// descriptor→settings mapping is unit-testable WITHOUT a live session.
public struct FreeRDPSettings: Equatable, Sendable {
    public let host: String
    public let port: UInt16
    public let username: String
    /// NT domain split from a `DOMAIN\user` form; empty when none.
    public let domain: String
    public let desktopWidth: UInt32
    public let desktopHeight: UInt32
    /// Percent: 100 = 1:1, 200 = HiDPI ×2 (maps to FreeRDP_DesktopScaleFactor).
    public let desktopScaleFactorPercent: UInt32
    public let redirectClipboard: Bool
    public let audioPlayback: Bool
    public let redirectDrives: Bool
    public let driveLocalPath: String?
    /// The CTERMYRDP_REDIRECT_* bitfield the shim registers channels from.
    public let redirectionFlags: ctermyrdp_redirection_flags
}

// MARK: - FreeRDPSession

/// Owns one FreeRDP session on a dedicated off-main queue. The pump runs on
/// `pumpQueue`; the C event-sink callback fires on that thread, the
/// trampoline copies every payload, and marshalled `RDPTransportEvent`s are
/// delivered to `eventHandler`. The caller is responsible for bridging
/// these events back to the main actor (the existing
/// `RDPTransportEventRouter` consumer pattern, unchanged).
public final class FreeRDPSession: @unchecked Sendable {

    /// Loader seam. Tests inject a fake; production wires
    /// `KeychainSecretStore().load`. The reference to a Keychain-backed
    /// load is the sole credential path after Task 6.
    public typealias SecretLoader = (SecretReference) throws -> Data?

    private let descriptor: RDPSessionDescriptor
    private let secretLoader: SecretLoader
    private let pumpQueue: DispatchQueue

    /// Serialises mutation of `eventHandler` / the per-session sequence
    /// counters / `sessionHandle` with the pump thread.
    private let lock = NSLock()
    private var sessionHandle: OpaquePointer? // ctermyrdp_session* (opaque)
    private var eventHandler: (@Sendable (RDPTransportEvent) -> Void)?
    /// Per-session monotonic counters. Every event kind that is deduped
    /// downstream by sequence (`RDPFrameBuffer` for frames,
    /// `RDPAudioOutputBridge`/`RDPAudioOutputSynchronizer` for audio,
    /// clipboard) needs an independent strictly-increasing sequence —
    /// hardcoding 0 makes the dedup `guard lastSequence != frame.sequence`
    /// drop every frame after the first.
    private var clipboardSequence: Int = 0
    private var audioSequence: Int = 0
    private var frameSequence: Int = 0
    private var stopped = false

    /// Renderer scale (`RDPRemoteDesktopFrame.scale`) derived from the
    /// descriptor's negotiated scale; threaded into every produced frame so
    /// HiDPI fidelity is not lost post-cutover.
    private let frameScale: Double

    public init(
        descriptor: RDPSessionDescriptor,
        secretStore: KeychainSecretStore = KeychainSecretStore()
    ) {
        self.descriptor = descriptor
        self.secretLoader = { try secretStore.load($0) }
        self.frameScale = max(1, descriptor.scale)
        self.pumpQueue = DispatchQueue(label: "pl.kacper.Termy.freerdp.pump", qos: .userInitiated)
    }

    /// Injection initializer (testing / non-Keychain loaders).
    public init(
        descriptor: RDPSessionDescriptor,
        secretLoader: @escaping SecretLoader
    ) {
        self.descriptor = descriptor
        self.secretLoader = secretLoader
        self.frameScale = max(1, descriptor.scale)
        self.pumpQueue = DispatchQueue(label: "pl.kacper.Termy.freerdp.pump", qos: .userInitiated)
    }

    // MARK: Lifecycle

    /// Resolve credentials, build config, connect, then spin the pump on the
    /// dedicated off-main queue, delivering marshalled events to `handler`.
    /// The plaintext password buffer is zeroed the instant
    /// `ctermyrdp_connect` returns (success OR throw — guaranteed by the
    /// `defer` in `withResolvedPassword`).
    public func start(
        onEvent handler: @escaping @Sendable (RDPTransportEvent) -> Void
    ) throws {
        lock.lock()
        eventHandler = handler
        lock.unlock()

        let settings = Self.freeRDPSettings(from: descriptor)

        let connectStatus: ctermyrdp_status = try Self.withResolvedPassword(
            for: descriptor,
            secretLoader: secretLoader
        ) { passwordPtr in
            settings.host.withCString { hostPtr in
                settings.username.withCString { userPtr in
                    settings.domain.withCString { domainPtr in
                        var config = ctermyrdp_config()
                        config.host = hostPtr
                        config.port = settings.port
                        config.username = userPtr
                        config.domain = settings.domain.isEmpty ? nil : domainPtr
                        config.password = passwordPtr
                        config.resolution = ctermyrdp_resolution(
                            width: settings.desktopWidth,
                            height: settings.desktopHeight,
                            scale_factor_percent: settings.desktopScaleFactorPercent
                        )
                        config.redirections = settings.redirectionFlags

                        guard let handle = ctermyrdp_create(&config) else {
                            return CTERMYRDP_STATUS_INTERNAL_ERROR
                        }
                        self.lock.lock()
                        self.sessionHandle = handle
                        self.lock.unlock()
                        return ctermyrdp_connect(handle)
                    }
                }
            }
        }
        // `passwordPtr` storage is zeroed here (defer in withResolvedPassword).

        guard connectStatus == CTERMYRDP_STATUS_OK else {
            let reason = Self.disconnectReason(status: connectStatus, lastError: 0)
            handler(.disconnected(reason))
            return
        }

        pumpQueue.async { [weak self] in
            self?.runPumpLoop()
        }
    }

    /// Request graceful disconnect; the DISCONNECT event follows on the pump.
    public func stop() {
        lock.lock()
        stopped = true
        let handle = sessionHandle
        lock.unlock()
        if let handle { ctermyrdp_disconnect(handle) }
    }

    deinit {
        if let handle = sessionHandle {
            ctermyrdp_destroy(handle)
        }
    }

    private func runPumpLoop() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        var sink = ctermyrdp_event_sink(
            callback: { eventPtr, userData in
                guard let eventPtr, let userData else { return }
                let session = Unmanaged<FreeRDPSession>
                    .fromOpaque(userData).takeUnretainedValue()
                if let marshalled = session.marshal(eventPtr) {
                    session.lock.lock()
                    let handler = session.eventHandler
                    session.lock.unlock()
                    handler?(marshalled)
                }
            },
            user_data: context
        )

        while true {
            lock.lock()
            let handle = sessionHandle
            let isStopped = stopped
            lock.unlock()
            guard let handle, !isStopped else { break }

            let status = ctermyrdp_pump(handle, &sink)
            if status == CTERMYRDP_STATUS_DISCONNECTED {
                break
            }
            if status != CTERMYRDP_STATUS_OK {
                lock.lock()
                let handler = eventHandler
                lock.unlock()
                handler?(.disconnected(Self.disconnectReason(status: status, lastError: 0)))
                break
            }
        }
    }

    // MARK: - Marshalling trampoline (tested seam)

    /// Instance entry point used by the C trampoline. Stamps every
    /// dedup-sensitive event kind (FRAME, AUDIO_PCM, CLIPBOARD_RX) with an
    /// independent per-session strictly-increasing sequence, and threads the
    /// descriptor scale into frames. Without this the downstream dedup
    /// guards (`RDPFrameBuffer.apply`, `RDPAudioOutputBridge`,
    /// clipboard) would drop every event after the first (all sequence 0).
    func marshal(_ eventPtr: UnsafePointer<ctermyrdp_event>) -> RDPTransportEvent? {
        let event = eventPtr.pointee
        switch event.kind {
        case CTERMYRDP_EVENT_FRAME:
            lock.lock()
            let seq = frameSequence
            frameSequence += 1
            lock.unlock()
            return Self.marshalFrame(event.payload.frame,
                                     sequence: seq, scale: frameScale)
        case CTERMYRDP_EVENT_AUDIO_PCM:
            lock.lock()
            let seq = audioSequence
            audioSequence += 1
            lock.unlock()
            return Self.marshalAudio(event.payload.audio_pcm, sequence: seq)
        case CTERMYRDP_EVENT_CLIPBOARD_RX:
            lock.lock()
            let seq = clipboardSequence
            clipboardSequence += 1
            lock.unlock()
            return Self.marshalClipboard(event.payload.clipboard_rx, sequence: seq)
        default:
            return Self.marshalEvent(eventPtr)
        }
    }

    /// Pure, stateless marshalling of a synthetic/real `ctermyrdp_event`
    /// into the existing seam `RDPTransportEvent`. COPIES every payload
    /// buffer/string before returning (callback-duration-only lifetime per
    /// the ctermyrdp.h contract). Returns nil for unrepresentable input.
    ///
    /// Stateless ⇒ FRAME carries the C-supplied sequence_number and scale 1;
    /// AUDIO_PCM/CLIPBOARD_RX carry sequence 0. The instance `marshal`
    /// overlays per-session monotonic sequences + descriptor scale for the
    /// live path; the dedup-correctness guarantee lives there and is tested
    /// via the instance entry point.
    static func marshalEvent(_ eventPtr: UnsafePointer<ctermyrdp_event>) -> RDPTransportEvent? {
        let event = eventPtr.pointee
        switch event.kind {
        case CTERMYRDP_EVENT_FRAME:
            let p = event.payload.frame
            return marshalFrame(p,
                                sequence: Int(truncatingIfNeeded: p.sequence_number),
                                scale: 1)
        case CTERMYRDP_EVENT_CLIPBOARD_RX:
            return marshalClipboard(event.payload.clipboard_rx, sequence: 0)
        case CTERMYRDP_EVENT_DRIVE_REQ:
            return marshalDriveRequest(event.payload.drive_req)
        case CTERMYRDP_EVENT_AUDIO_PCM:
            return marshalAudio(event.payload.audio_pcm, sequence: 0)
        case CTERMYRDP_EVENT_DISCONNECT:
            let d = event.payload.disconnect
            return .disconnected(disconnectReason(status: d.status_code,
                                                  lastError: d.last_error_code))
        default:
            return nil
        }
    }

    private static func marshalFrame(
        _ p: ctermyrdp_frame_payload, sequence: Int, scale: Double
    ) -> RDPTransportEvent? {
        let width = Int(p.width)
        let height = Int(p.height)
        guard width > 0, height > 0, let base = p.bgra_pixels else { return nil }
        let byteCount = width * height * 4
        // COPY out of the shim-owned buffer immediately.
        let data = Data(bytes: base, count: byteCount)
        let frame = RDPRemoteDesktopFrame(
            sequence: sequence,
            width: width,
            height: height,
            scale: scale,
            pixelFormat: .bgra8,
            data: data
        )
        return .desktopFrame(frame)
    }

    private static func marshalClipboard(
        _ p: ctermyrdp_clipboard_rx_payload, sequence: Int
    ) -> RDPTransportEvent? {
        guard let base = p.data, p.size > 0 else {
            return .remoteClipboard(text: "", sequence: sequence)
        }
        // COPY before decoding (buffer is callback-duration-only).
        let bytes = Data(bytes: base, count: p.size)
        let text: String
        // CF_UNICODETEXT (13): UTF-16LE, NUL-terminated by convention.
        if p.format == 13 {
            text = decodeUTF16LE(bytes)
        } else {
            text = String(data: bytes, encoding: .utf8)
                ?? String(decoding: bytes, as: UTF8.self)
        }
        return .remoteClipboard(text: text, sequence: sequence)
    }

    private static func decodeUTF16LE(_ data: Data) -> String {
        var units: [UInt16] = []
        units.reserveCapacity(data.count / 2)
        var i = data.startIndex
        while i + 1 < data.endIndex {
            let lo = UInt16(data[i])
            let hi = UInt16(data[i + 1])
            let unit = lo | (hi << 8)
            if unit == 0 { break } // NUL terminator
            units.append(unit)
            i += 2
        }
        return String(decoding: units, as: UTF16.self)
    }

    /// Dormant: the in-tree shim does not emit `CTERMYRDP_EVENT_DRIVE_REQ`
    /// (FreeRDP handles drive redirection internally via CHANNEL_DRIVE +
    /// FreeRDP_RedirectDrives + DrivePath; the C-side `enqueue_drive` path
    /// is intentionally absent — see `ctermyrdp.c:761-772`'s accepted no-op
    /// `ctermyrdp_submit_drive_response`). Retained for spec §6.8 future
    /// Swift-side custom drive handling; exercised by
    /// `FreeRDPSessionTests.testRDP*Drive*` to pin the C-shim contract so
    /// the marshalling shape stays correct when/if drive-event enqueuing
    /// is wired up in a future shim revision.
    private static func marshalDriveRequest(
        _ p: ctermyrdp_drive_req_payload
    ) -> RDPTransportEvent? {
        let major = RDPDriveDeviceIOMajorFunction(
            rawProtocolValue: UInt32(p.major_function))
        var payload = Data()
        if let path = p.path {
            // COPY the C string before it is reclaimed.
            payload = Data(String(cString: path).utf8)
        }
        let request = RDPDriveDeviceIORequest(
            deviceID: p.device_id,
            fileID: 0,
            completionID: p.request_id,
            majorFunction: major,
            rawMajorFunction: UInt32(p.major_function),
            minorFunction: UInt32(p.minor_function),
            payload: payload
        )
        return .driveHandshake(.deviceIORequest(request))
    }

    private static func marshalAudio(
        _ p: ctermyrdp_audio_pcm_payload, sequence: Int
    ) -> RDPTransportEvent? {
        let count = p.size
        let data: Data
        if let base = p.pcm_data, count > 0 {
            data = Data(bytes: base, count: count) // COPY immediately
        } else {
            data = Data()
        }
        let frame = RDPAudioOutputFrame(
            sequence: sequence,
            sampleRate: Int(p.sample_rate),
            channelCount: Int(p.channels),
            format: .pcmSigned16LittleEndian,
            data: data
        )
        return .audioOutput(frame)
    }

    // MARK: - Status mapping (tested seam)

    /// Map a stable `ctermyrdp_status` (+ raw freerdp_get_last_error() code)
    /// to the EXISTING `RDPDisconnectReason`. The FreeRDP code rides in
    /// `.transportError`'s Int32 (spec §7). No new app error type/UX —
    /// downstream is the existing `RDPSessionLifecycle`/`RDPReconnectPlan`
    /// path. `.userInitiated` ⇒ no reconnect; `.networkFailure` /
    /// `.transportError` ⇒ reconnect (per `RDPReconnectPolicy`).
    static func disconnectReason(
        status: ctermyrdp_status,
        lastError: Int32
    ) -> RDPDisconnectReason {
        switch status {
        case CTERMYRDP_STATUS_DISCONNECTED:
            // A clean server/user-driven close carries no protocol error
            // code; a non-zero code means an abnormal drop → retryable.
            return lastError == 0 ? .userInitiated : .transportError(lastError)
        case CTERMYRDP_STATUS_NETWORK_ERROR:
            return .networkFailure
        case CTERMYRDP_STATUS_OK:
            // Not a disconnect; surface as userInitiated (terminal, no
            // reconnect) — the pump loop never feeds OK here.
            return .userInitiated
        default:
            // CONNECT_FAILED / AUTH_FAILED / TLS_FAILED / CHANNEL_ERROR /
            // NO_SESSION / INVALID_ARG / NOT_IMPLEMENTED / INTERNAL_ERROR:
            // the FreeRDP error code rides in the Int32.
            return .transportError(lastError)
        }
    }

    // MARK: - Settings mapping (tested seam)

    /// Convert an `RDPSessionDescriptor` (the unchanged app seam) into the
    /// FreeRDP settings inputs. `RDPResolution` →
    /// DesktopWidth/Height/ScaleFactor; `RDPRedirection` flags → which
    /// channels the shim registers + AudioPlayback / RedirectClipboard /
    /// drive redirection. These seam types are INPUTS here (not outputs).
    /// Pure — testable without a live FreeRDP session.
    static func freeRDPSettings(from descriptor: RDPSessionDescriptor) -> FreeRDPSettings {
        var clipboard = false
        var audio = false
        var drivePath: String?
        for redirection in descriptor.redirections {
            switch redirection {
            case .clipboard:
                clipboard = true
            case .audioOutput:
                audio = true
            case .folderDrive(let path):
                if !path.isEmpty { drivePath = path }
            }
        }

        var flags: ctermyrdp_redirection_flags = CTERMYRDP_REDIRECT_NONE
        if clipboard { flags |= CTERMYRDP_REDIRECT_CLIPBOARD }
        if audio { flags |= CTERMYRDP_REDIRECT_AUDIO }
        if drivePath != nil { flags |= CTERMYRDP_REDIRECT_DRIVES }

        let (domain, user) = Self.splitDomainUser(descriptor.user)

        // descriptor.scale: 1.0 → 100%, 2.0 → 200% (FreeRDP_DesktopScaleFactor
        // is an integer percent; clamp to its supported 100/140/180 family is
        // FreeRDP's concern — we pass the literal percent).
        let scalePercent = UInt32(max(100, (descriptor.scale * 100).rounded()))

        return FreeRDPSettings(
            host: descriptor.host,
            port: 3389, // the descriptor seam is host-only; RDP default
            username: user,
            domain: domain,
            desktopWidth: UInt32(max(0, descriptor.resolution.width)),
            desktopHeight: UInt32(max(0, descriptor.resolution.height)),
            desktopScaleFactorPercent: scalePercent,
            redirectClipboard: clipboard,
            audioPlayback: audio,
            redirectDrives: drivePath != nil,
            driveLocalPath: drivePath,
            redirectionFlags: flags
        )
    }

    /// Split a `DOMAIN\user` into (domain, user); mirrors the original
    /// resolver's `splitDomainUser` so credential identity is unchanged.
    private static func splitDomainUser(_ value: String) -> (domain: String, user: String) {
        guard let sep = value.firstIndex(of: "\\") else { return ("", value) }
        return (String(value[..<sep]), String(value[value.index(after: sep)...]))
    }

    // MARK: - Credential resolution (tested seam; re-implements the resolver)

    /// Resolve `descriptor.secretReferences.first` via the injected loader,
    /// hand the UTF-8 plaintext (NUL-terminated) to `body` as a C string,
    /// then ZERO the backing storage — guaranteed on BOTH the success path
    /// and any throw, because the wipe is in a `defer`. The plaintext never
    /// outlives this call; nothing copies it into a retained `Data`.
    ///
    /// Sole credential-resolution path post-cutover. Mirrors the three
    /// typed-error cases of the (deleted) bespoke
    /// `RDPCredSSPNTLMv2CredentialResolver`. The bespoke resolver was
    /// removed alongside the rest of the engine in Task 6.
    @discardableResult
    static func withResolvedPassword<T>(
        for descriptor: RDPSessionDescriptor,
        secretLoader: SecretLoader,
        body: (UnsafePointer<CChar>) throws -> T
    ) throws -> T {
        guard let reference = descriptor.secretReferences.first else {
            throw FreeRDPCredentialError.missingSecretReference
        }
        guard let passwordData = try secretLoader(reference) else {
            throw FreeRDPCredentialError.missingSecret(reference)
        }
        guard let password = String(data: passwordData, encoding: .utf8) else {
            throw FreeRDPCredentialError.invalidUTF8Secret(reference)
        }

        // NUL-terminated UTF-8 in mutable, contiguous, owned storage.
        var bytes = ContiguousArray<CChar>()
        bytes.reserveCapacity(password.utf8.count + 1)
        for byte in password.utf8 { bytes.append(CChar(bitPattern: byte)) }
        bytes.append(0)

        // The `defer` is what makes the error-path guarantee tight: whether
        // `body` returns or throws, the storage is memset to zero before this
        // function unwinds. `memset_s` is not optimised away by the compiler.
        defer {
            bytes.withUnsafeMutableBufferPointer { buf in
                if let base = buf.baseAddress {
                    _ = memset_s(base, buf.count, 0, buf.count)
                }
            }
        }
        return try bytes.withUnsafeBufferPointer { try body($0.baseAddress!) }
    }

    // MARK: - Client→server writes (Task 6 cutover)

    /// Write a batch of slow-path input events into the C shim. Keyboard
    /// scancodes map 1:1 to `ctermyrdp_send_key`; pointer events to
    /// `ctermyrdp_send_pointer`. The flag-bit layout used by
    /// `RDPPointerFlags` is the on-the-wire RDP TS_INPUT_EVENT pointer
    /// flag set, which is the exact shape `ctermyrdp_pointer_event.flags`
    /// expects — so the rawValue passes through unchanged.
    ///
    /// Best-effort policy: the count of successfully-sent events is returned;
    /// non-OK statuses from the C send path are silently dropped, and partial
    /// sends are inferred by callers from the count vs the array length.
    ///
    /// Threading (verified 2026-05-20 against ctermyrdp.c:713-737 + FreeRDP
    /// 3.x docs): the C side calls `freerdp_input_send_keyboard_event` /
    /// `freerdp_input_send_mouse_event` SYNCHRONOUSLY on the caller's thread.
    /// FreeRDP 3.x removed the `async-input` feature (per the upstream
    /// FreeRDP3-migration-notes), so the write path goes straight to
    /// transport_write_buffer → BIO_write on the (blocking-by-default) TLS
    /// BIO. The current callers are `@MainActor` (`TermyStore.swift`'s
    /// `handleLocalRDPInputEvents`). On a healthy network this is sub-
    /// millisecond per event; on a backpressured/slow link the call can
    /// stall the main thread.
    ///
    /// FOLLOW-UP (Tasks 7-9 / post-deferred-gate refactor): hop input
    /// writes onto a dedicated off-main "send" queue (separate from
    /// `pumpQueue`, or serialised onto it) before crossing into FreeRDP,
    /// so a slow server cannot block the UI on every keystroke. NOT done
    /// here — the spec §8 deferred gate must validate the live-server
    /// path first, and changing the threading model on the cutover commit
    /// would mix concerns. The simplification headline of Task 6 is the
    /// engine swap; the I/O threading model carries forward unchanged
    /// from the bespoke engine (which was also synchronous on the
    /// caller's thread via `transport.write`).
    @discardableResult
    public func sendInputEvents(_ events: [RDPSlowPathInputEvent]) -> Int {
        lock.lock()
        let handle = sessionHandle
        lock.unlock()
        guard let handle else { return 0 }
        var sent = 0
        for event in events {
            switch event {
            case .keyboard(let scancode, let isDown, let isExtended):
                var key = ctermyrdp_key_event(
                    scan_code: UInt32(scancode),
                    extended: isExtended,
                    key_down: isDown
                )
                // Synchronous transport_write under the hood — see threading
                // note in the function header.
                if ctermyrdp_send_key(handle, &key) == CTERMYRDP_STATUS_OK {
                    sent += 1
                }
            case .pointer(let flags, let x, let y):
                var pointer = ctermyrdp_pointer_event(
                    x: x, y: y, flags: flags.rawValue
                )
                // Synchronous transport_write under the hood — see threading
                // note in the function header.
                if ctermyrdp_send_pointer(handle, &pointer) == CTERMYRDP_STATUS_OK {
                    sent += 1
                }
            }
        }
        return sent
    }

    /// Push the local clipboard text to the server as CF_UNICODETEXT
    /// (UTF-16LE, NUL-terminated) — the format the server announces via the
    /// remote clipboard exchange. Returns true on OK, false otherwise.
    ///
    /// Threading (verified 2026-05-20 against ctermyrdp.c:741-758): the
    /// C side calls `cliprdr->ClientFormatDataResponse` SYNCHRONOUSLY on
    /// the caller's thread; that flows through the virtual-channel send
    /// path into the same blocking-BIO transport write as input events.
    /// Same caveat / same Tasks-7-9 follow-up as `sendInputEvents` —
    /// clipboard sync from `@MainActor` can stall the UI on a slow link.
    @discardableResult
    public func sendClipboardText(_ text: String) -> Bool {
        lock.lock()
        let handle = sessionHandle
        lock.unlock()
        guard let handle else { return false }
        // CF_UNICODETEXT (13) ⇒ UTF-16LE, NUL-terminated.
        var bytes = Data()
        for unit in text.utf16 {
            bytes.append(UInt8(unit & 0xff))
            bytes.append(UInt8((unit >> 8) & 0xff))
        }
        bytes.append(0); bytes.append(0)
        return bytes.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            var payload = ctermyrdp_clipboard_tx(
                data: base, size: raw.count, format: 13
            )
            return ctermyrdp_send_clipboard(handle, &payload) == CTERMYRDP_STATUS_OK
        }
    }

    // MARK: - Test support

    /// A session usable purely for the stateful instance `marshal` path
    /// (per-session frame/audio/clipboard sequence + scale threading). No
    /// connect, no pump, no Keychain.
    static func makeForMarshallingTests(scale: Double = 1) -> FreeRDPSession {
        // A minimal valid descriptor; never connected in tests.
        let profile = ConnectionProfile(
            kind: .rdp, name: "t", host: "t", user: "u", port: 3389,
            gateway: nil, groupPath: nil, sshOptions: [:],
            terminalOutputMode: .stream, secretReferences: [.keychain("t")]
        )
        // Force-unwrap is safe: profile is a valid .rdp with a user.
        let descriptor = try! RDPSessionDescriptor(
            profile: profile,
            resolution: RDPResolution(width: 1, height: 1),
            scale: scale,
            localFolderPath: nil
        )
        return FreeRDPSession(descriptor: descriptor) { _ in nil }
    }
}
