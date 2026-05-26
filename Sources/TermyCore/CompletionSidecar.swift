import Foundation
import Darwin

/// Per-session sidecar zsh actor.
///
/// Owns the state machine ({.booting, .ready, .crashed, .disabled}), the Q-frame
/// id sequence, and a pre-ready coalescing queue. Result files arriving in
/// `workDir` are surfaced via the injected `onEvent` callback when the parent
/// calls `pollResultsOnce()` (production wiring binds this to a
/// DispatchSource.write notification on the dir; tests call it directly).
///
/// Production entry point is `spawn(...)`. Tests use the `init(workDir:writer:onEvent:)`
/// closure-injection seam directly.
public actor CompletionSidecar {
    public enum State: Equatable, Sendable {
        // `.crashed` is set by Task 8's real Process termination handler;
        // current Task-6 actor only uses .booting / .ready / .disabled.
        case booting, ready, crashed, disabled
    }

    public private(set) var state: State = .booting
    public nonisolated let workDir: URL

    private let writer: @Sendable (String) -> Void
    private let onEvent: @Sendable (CompletionSidecarResultWatcher.Event) -> Void
    private let onStateChange: @Sendable (State) -> Void

    private var nextReqId: Int = 1
    /// Pre-ready coalescing slot: only the *latest* pending query survives boot.
    private var pendingPreReady: (buffer: String, cursor: Int, cwd: String, id: Int)?
    private var crashTimestamps: [Date] = []

    // Production-side resources (nil/−1 when constructed via closure-injection init).
    private var attachedWatchSource: DispatchSourceFileSystemObject?
    private var attachedDrainSource: DispatchSourceRead?
    private var attachedExitSource: DispatchSourceProcess?
    private var attachedPid: pid_t = -1
    private var attachedMasterFd: Int32 = -1

    /// Closure-injection init used by tests (and internally by `makeImmediatelyDisabled`).
    public init(
        workDir: URL,
        writer: @escaping @Sendable (String) -> Void,
        onEvent: @escaping @Sendable (CompletionSidecarResultWatcher.Event) -> Void,
        onStateChange: @escaping @Sendable (State) -> Void = { _ in },
        initialState: State = .booting
    ) {
        self.workDir = workDir
        self.writer = writer
        self.onEvent = onEvent
        self.onStateChange = onStateChange
        self.state = initialState
    }

    /// Mutates `state` and fires `onStateChange` when the value changes.
    private func setState(_ newState: State) {
        guard newState != state else { return }
        state = newState
        onStateChange(newState)
    }

    // MARK: - Query API

    /// Issue a completion request. Pre-ready queries are coalesced (only the
    /// latest survives). After boot the queued query is flushed, then all
    /// subsequent calls write immediately.
    public func query(buffer: String, cursor: Int, cwd: String) {
        guard state != .disabled else { return }
        let id = nextReqId
        nextReqId += 1
        if state != .ready {
            // Coalesce: replace any previous pre-ready entry with the latest.
            pendingPreReady = (buffer, cursor, cwd, id)
            return
        }
        writeQuery(buffer: buffer, cursor: cursor, cwd: cwd, id: id)
    }

    /// Notify the sidecar of a directory change. Dropped if not yet ready.
    public func notifyCwd(_ cwd: String) {
        guard state == .ready else { return }
        writer(CompletionSidecarTransport.encodeCd(cwd: cwd))
    }

    // MARK: - Polling

    /// Scan `workDir` for result files, apply events, and call `onEvent` for
    /// each one. Safe to call repeatedly; already-consumed files are deleted by
    /// the watcher so idempotent.
    public func pollResultsOnce() {
        guard state != .disabled else { return }
        let events = CompletionSidecarResultWatcher.consumeResultFiles(in: workDir)
        for event in events {
            if case .boot = event, state == .booting {
                setState(.ready)
                flushQueued()
            }
            onEvent(event)
        }
    }

    // MARK: - Lifecycle

    /// Simulate a crash (used in tests; Task 8 will call this from a real
    /// Process termination handler). Three crashes within 60 s → `.disabled`.
    public func simulateCrash() {
        guard state != .disabled else { return }
        let now = Date()
        crashTimestamps.append(now)
        // Expire timestamps older than 60 s.
        crashTimestamps = crashTimestamps.filter { now.timeIntervalSince($0) < 60 }
        if crashTimestamps.count >= 3 {
            setState(.disabled)
            return
        }
        setState(.booting)
        pendingPreReady = nil
    }

    /// v3 Shell §6.1 ("Sidecar · N crashes / 60s"): count of crashes within the
    /// trailing 60 s of `now`. Read-only — uses the same window rule as
    /// `simulateCrash`'s pruning; does not mutate state.
    public func recentCrashCount(now: Date = Date()) -> Int {
        crashTimestamps.filter { now.timeIntervalSince($0) < 60 }.count
    }

    /// Permanently shut down this sidecar. All further writes are silently dropped.
    /// Also tears down any production-side PTY resources (DispatchSources, Process,
    /// master fd) that were attached via `attachDispatchSource(...)`.
    public func terminate() {
        setState(.disabled)
        pendingPreReady = nil
        attachedWatchSource?.cancel()
        attachedWatchSource = nil
        attachedDrainSource?.cancel()   // cancel handler closes masterFd; drain handler stops
        attachedDrainSource = nil
        attachedExitSource?.cancel()
        attachedExitSource = nil
        if attachedPid > 0 {
            _ = kill(attachedPid, SIGTERM)
            var status: Int32 = 0
            _ = waitpid(attachedPid, &status, WNOHANG)
        }
        attachedPid = -1
        attachedMasterFd = -1
        try? FileManager.default.removeItem(at: workDir)
    }

    /// Remove every entry from a sidecar workdir parent. Called once at app
    /// launch — any UUID dirs already there belong to prior Termy runs that
    /// crashed or shut down without invoking `terminate()` on their sidecars.
    /// Safe because the calling instance has not yet spawned any sidecars.
    public static func sweepStaleWorkDirs(in parentDir: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: parentDir, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents {
            try? fm.removeItem(at: url)
        }
    }

    /// Attaches the production-side PTY resources for lifecycle cleanup.
    /// Called once (via an unstructured `Task`) from `spawn(...)`.
    public func attachDispatchSource(
        _ watchSource: DispatchSourceFileSystemObject,
        drainSource: DispatchSourceRead,
        exitSource: DispatchSourceProcess,
        pid: pid_t,
        masterFd: Int32
    ) {
        if state == .disabled {
            // terminate() raced ahead — clean up the resources we were just handed.
            drainSource.cancel()  // closes masterFd via cancel handler
            watchSource.cancel()
            exitSource.cancel()
            _ = kill(pid, SIGTERM)
            return
        }
        self.attachedWatchSource = watchSource
        self.attachedDrainSource = drainSource
        self.attachedExitSource = exitSource
        self.attachedPid = pid
        self.attachedMasterFd = masterFd
    }

    // MARK: - Private helpers

    private func flushQueued() {
        guard let q = pendingPreReady else { return }
        pendingPreReady = nil
        writeQuery(buffer: q.buffer, cursor: q.cursor, cwd: q.cwd, id: q.id)
    }

    private func writeQuery(buffer: String, cursor: Int, cwd: String, id: Int) {
        let line = CompletionSidecarTransport.encodeComplete(
            buffer: buffer, cursor: cursor, cwd: cwd, reqId: id
        )
        writer(line)
    }
}

// MARK: - Production PTY spawn

extension CompletionSidecar {
    /// Production entry point. Validates that `shellPath` is zsh, opens a
    /// `openpty(3)` PTY pair, spawns the shell on the slave fd, sources the
    /// bootstrap script, and installs a `DispatchSource` file-system watcher
    /// on `workDir` that calls `pollResultsOnce()` when the sidecar widget
    /// publishes a result file.
    ///
    /// **Fail-closed:** any error (non-zsh shell, `openpty` failure, `Process`
    /// launch failure) returns a sidecar already in `.disabled` with no
    /// further wiring. Callers should check `await sidecar.state` before
    /// issuing queries.
    ///
    /// **Wire format (Option A translation):**
    /// The transport layer (`CompletionSidecarTransport`) produces Q-lines of
    /// the form `__termy_complete <b64> <cursor> <cwd> <id>\n`. When sent raw
    /// to a PTY master the shell would treat them as unknown commands.
    ///
    /// Instead this writer translates each encoded line into the side-file +
    /// keystroke form the bootstrap script (`SidecarShellScript.template`)
    /// expects:
    ///
    ///   1. Atomically write the request id and cwd to
    ///      `$TERMY_SIDECAR_DIR/__request__.tsv`.
    ///
    ///   2. Send Ctrl-U, the decoded command buffer, cursor-left moves when
    ///      needed, and the ESC-q keystroke (`\x1b\x71`) to trigger
    ///      `bindkey '\eq' _termy_capture`.
    ///
    /// ZLE completion widgets expose `BUFFER`/`CURSOR` as read-only in this
    /// context on macOS zsh, so the sidecar must make the line editor state by
    /// typing into ZLE instead of assigning those parameters inside the widget.
    ///
    /// For `__termy_cd` lines the translation is:
    ///      `__termy_cd_target=<cwd>; _termy_cd\n`
    ///
    /// This keeps `SidecarShellScript.template` (Task 5) and the transport
    /// encoder (Task 3) decoupled from the PTY keystroke protocol.
    public static func spawn(
        shellPath: String,
        zdotdir: String?,
        extraEnvironment: [String: String],
        cwd: String,
        workDir: URL,
        onEvent: @escaping @Sendable (CompletionSidecarResultWatcher.Event) -> Void,
        onStateChange: @escaping @Sendable (CompletionSidecar.State) -> Void = { _ in }
    ) throws -> CompletionSidecar {
        // --- 1. Validate shell is zsh. ---
        // TODO(spec §7.11): version check for zsh ≥ 5.8 — currently we only
        // verify the binary identifies as zsh.
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: shellPath)
        probe.arguments = ["--version"]
        let probePipe = Pipe()
        probe.standardOutput = probePipe
        probe.standardError = Pipe()
        do {
            try probe.run()
            probe.waitUntilExit()
        } catch {
            return makeImmediatelyDisabled(workDir: workDir, onEvent: onEvent, onStateChange: onStateChange)
        }
        let versionData = probePipe.fileHandleForReading.readDataToEndOfFile()
        let versionString = String(data: versionData, encoding: .utf8) ?? ""
        guard versionString.lowercased().contains("zsh") else {
            return makeImmediatelyDisabled(workDir: workDir, onEvent: onEvent, onStateChange: onStateChange)
        }

        // --- 1b. Helper: ioctl(TIOCSWINSZ) for the PTY pair. ---
        // zsh in `-i` mode checks the controlling-tty winsize; a 0×0 PTY
        // (openpty's default) causes some completion functions to misbehave.
        // Spike used `set_winsize(master_fd)`; mirror it.

        // --- 2-4. Spawn via forkpty() instead of Foundation.Process. ---
        //
        // Foundation.Process intercepts standardOutput/standardError into
        // internal pipes even when a FileHandle pointing at a TTY fd is
        // provided (empirically caught by visual gate 2026-05-20: child
        // ends up with fd0=TTY but fd1=pipe → zsh sees isatty(1)==0 → ZLE
        // refuses to start → bootstrap runs to completion but typed input
        // is never dispatched as keystrokes).
        //
        // forkpty() does what Python's pty.fork() does in spike.py:
        // openpty + fork + (in child) setsid + dup2(slave → 0/1/2) +
        // TIOCSCTTY + execvp. All three stdio handles end up on the same
        // slave PTY → isatty() returns 1 on all → ZLE starts.

        var env = ProcessInfo.processInfo.environment
        env["TERMY_SIDECAR"] = "1"
        env["TERMY_SIDECAR_DIR"] = workDir.path
        env["PROMPT"] = ""
        env["RPROMPT"] = ""
        if let zdotdir { env["ZDOTDIR"] = zdotdir }
        for (k, v) in extraEnvironment { env[k] = v }

        // Reasonable defaults; some completion functions branch on $COLUMNS.
        var winSize = winsize(ws_row: 24, ws_col: 200, ws_xpixel: 0, ws_ypixel: 0)
        var masterFd: Int32 = -1
        let pid = forkpty(&masterFd, nil, nil, &winSize)
        if pid < 0 {
            return makeImmediatelyDisabled(workDir: workDir, onEvent: onEvent, onStateChange: onStateChange)
        }
        if pid == 0 {
            // CHILD — keep this path tight; only signal-safe operations
            // until execvp. setenv is acceptable for our spawn-immediately
            // pattern since no other threads in the child compete.
            cwd.withCString { _ = chdir($0) }
            for (k, v) in env {
                k.withCString { kc in
                    v.withCString { vc in
                        _ = setenv(kc, vc, 1)
                    }
                }
            }
            let argv0 = strdup(shellPath)
            let argv1 = strdup("-i")
            var argv: [UnsafeMutablePointer<CChar>?] = [argv0, argv1, nil]
            argv.withUnsafeMutableBufferPointer { buf in
                _ = execv(shellPath, buf.baseAddress)
            }
            Darwin._exit(127)  // execv only returns on failure
        }
        // PARENT — fall through; masterFd is our end, child has slave on 0/1/2.

        // --- 5. Build the sidecar actor with the PTY-writer closure. ---
        //
        // The writer receives transport-encoded lines and translates them to the
        // two-phase PTY wire format described above (see Option A notes in the
        // doc comment). The master fd copy is captured by value; it is safe to
        // use from any thread since writes to a PTY master fd are atomic for our
        // small payloads.
        //
        // NOTE: writes are blocking. For the small Q-lines we emit (< 512 bytes)
        // the PTY buffer will never fill, so blocking is harmless. If a future
        // change emits large payloads, make the fd non-blocking and buffer.
        let masterCopy = masterFd
        let writer: @Sendable (String) -> Void = { line in
            CompletionSidecar.writePTYLine(line, toMaster: masterCopy, workDir: workDir)
        }

        let sidecar = CompletionSidecar(
            workDir: workDir,
            writer: writer,
            onEvent: onEvent,
            onStateChange: onStateChange
        )

        // --- 6. (Process.run replaced by forkpty above.) ---

        // --- 7. Drain PTY display output on a background DispatchSource. ---
        // Using a read DispatchSource instead of a blocking thread avoids UAF:
        // when the source is cancelled (in terminate()) no further reads occur.
        // The cancel handler below owns the close(masterFd) — nowhere else does.
        let drainQueue = DispatchQueue(label: "termy.sidecar.drain", qos: .utility)
        let drainSource = DispatchSource.makeReadSource(
            fileDescriptor: masterCopy, queue: drainQueue
        )
        drainSource.setEventHandler {
            var buf = [UInt8](repeating: 0, count: 4096)
            _ = buf.withUnsafeMutableBufferPointer { ptr in
                Darwin.read(masterCopy, ptr.baseAddress, ptr.count)
            }
            // Discard all display bytes; result delivery uses the workDir watcher.
        }
        drainSource.setCancelHandler { close(masterCopy) }
        drainSource.resume()

        // --- 8. Watch workDir for result files. ---
        let dirFd = open(workDir.path, O_EVTONLY)
        guard dirFd >= 0 else {
            drainSource.cancel()  // cancel handler closes masterFd
            return makeImmediatelyDisabled(workDir: workDir, onEvent: onEvent, onStateChange: onStateChange)
        }
        let watchQueue = DispatchQueue(label: "termy.sidecar.watch", qos: .utility)
        let watchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFd, eventMask: .write, queue: watchQueue
        )
        watchSource.setEventHandler { [weak sidecar] in
            guard let sidecar else { return }
            Task { await sidecar.pollResultsOnce() }
        }
        watchSource.setCancelHandler { close(dirFd) }
        watchSource.resume()

        // --- 9. Source the bootstrap script via a temp file. ---
        // IMPORTANT: We do NOT write the 4KB script inline to the PTY master.
        // zsh receives PTY master bytes via ZLE (the line editor), which has
        // Tab bound to `complete-word`. A literal Tab character inside the
        // script (e.g., in the __termy_captured+= TSV literal) would be
        // intercepted by ZLE and fire the completion widget mid-sourcing,
        // corrupting the shell state.
        //
        // The spike (spike.py) writes the script to a tmpfile and sends
        // `source <path>\n` instead — a 40-byte command with no ZLE-sensitive
        // characters. We follow the same approach.
        //
        // The bootstrap file lives in workDir so it is cleaned up automatically
        // when the caller removes workDir after the session ends.
        let bootstrapURL = workDir.appendingPathComponent("__bootstrap__.zsh")
        do {
            try SidecarShellScript.template.write(to: bootstrapURL, atomically: true, encoding: .utf8)
        } catch {
            watchSource.cancel()
            drainSource.cancel()  // cancel handler closes masterFd
            return makeImmediatelyDisabled(workDir: workDir, onEvent: onEvent, onStateChange: onStateChange)
        }
        let escapedPath = bootstrapURL.path.replacingOccurrences(of: "'", with: "'\\''")

        // The bootstrap sequence runs on a detached Task so spawn() returns
        // promptly. zsh in `-i` mode enables bracketed-paste-mode by default
        // (sends `ESC[?2004h` to its TTY). Without disabling it, our
        // subsequent `source '...'\n` write is interpreted by the line
        // editor as PASTED content — it lands in $BUFFER literally and
        // never executes. The spike (script/f4-spike/spike.py) caught this:
        // it sends `unset zle_bracketed_paste; printf '\033[?2004l'` to
        // turn the mode off before sourcing.
        //
        // Sequence (each delay lets zsh process the prior bytes through
        // .zshrc / ZLE init):
        //   1. wait 300ms for .zshrc to finish loading
        //   2. write disable-bracketed-paste line
        //   3. wait 100ms
        //   4. write `source '<path>'`
        // The bootstrap script itself then writes __boot__.flag which the
        // workDir DispatchSource picks up and surfaces as a .boot event.
        Task.detached {
            // Heavy `.zshrc` (oh-my-zsh, nvm, p10k) can take ~1s on first
            // load. Wait generously so ZLE is initialized before we
            // inject input.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let disablePaste = "unset zle_bracketed_paste 2>/dev/null; printf '\\033[?2004l'\n"
            var bytes = Array(disablePaste.utf8)
            _ = bytes.withUnsafeBufferPointer { buf in
                Darwin.write(masterCopy, buf.baseAddress!, buf.count)
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            let sourceCmd = "source '\(escapedPath)'\n"
            bytes = Array(sourceCmd.utf8)
            _ = bytes.withUnsafeBufferPointer { buf in
                Darwin.write(masterCopy, buf.baseAddress!, buf.count)
            }
        }

        // --- 10. Termination monitor — replaces Process.terminationHandler. ---
        // DispatchSource.makeProcessSource fires when `pid` exits.
        let exitQueue = DispatchQueue(label: "termy.sidecar.exit", qos: .utility)
        let exitSource = DispatchSource.makeProcessSource(
            identifier: pid, eventMask: .exit, queue: exitQueue
        )
        exitSource.setEventHandler { [weak sidecar] in
            // Reap the child to avoid a zombie.
            var status: Int32 = 0
            _ = waitpid(pid, &status, WNOHANG)
            Task { await sidecar?.simulateCrash() }
        }
        exitSource.resume()

        // --- 11. Attach resources to the actor for lifecycle cleanup. ---
        // attachDispatchSource stores the resources; if terminate() already ran
        // it cleans them up immediately. The drain source cancel handler owns
        // masterFd — no other code closes it after this point.
        Task {
            await sidecar.attachDispatchSource(
                watchSource,
                drainSource: drainSource,
                exitSource: exitSource,
                pid: pid,
                masterFd: masterFd
            )
        }

        return sidecar
    }

    /// Translates a Q-line from `CompletionSidecarTransport` into the PTY
    /// keystrokes the bootstrap script's bound widget expects. Returns nil for
    /// unknown or malformed lines (silently dropped — caller may log if it
    /// cares).
    ///
    /// Q-line shape (encoded by CompletionSidecarTransport):
    ///   __termy_complete <b64> <cursor> <cwd> <reqId>\n   — completion request
    ///   __termy_cd <cwd>\n                                 — cwd change
    ///
    /// PTY wire (post-spike protocol, spec §5.3):
    ///   complete: Ctrl-U + decoded buffer + cursor-left moves + ESC q
    ///   cd:       __termy_cd_target=...; _termy_cd \n
    internal static func ptyWireString(forQLine line: String) -> String? {
        if let request = parseCompleteQLine(line) {
            guard
                let data = Data(base64Encoded: request.bufferBase64),
                let buffer = String(data: data, encoding: .utf8)
            else { return nil }
            let clampedCursor = max(0, min(request.cursor, buffer.count))
            let leftMoves = String(repeating: "\u{001B}[D", count: buffer.count - clampedCursor)
            return "\u{0015}" + buffer + leftMoves + "\u{001B}q"
        }
        let trimmed = line.hasSuffix("\n") ? String(line.dropLast()) : line
        if trimmed.hasPrefix("__termy_cd ") {
            let cwd = trimmed.dropFirst("__termy_cd ".count)
            // cwd is single-arg-shape (no spaces from OSC 133 D in practice).
            return "__termy_cd_target=\(cwd); _termy_cd\n"
        }
        return nil
    }

    private static func writePTYLine(_ line: String, toMaster fd: Int32, workDir: URL) {
        if let request = parseCompleteQLine(line) {
            guard writeRequestMetadata(request, to: workDir) else { return }
        }
        guard let wire = ptyWireString(forQLine: line) else { return }
        let bytes = Array(wire.utf8)
        _ = bytes.withUnsafeBufferPointer { buf in
            Darwin.write(fd, buf.baseAddress, buf.count)
        }
    }

    private struct ParsedComplete {
        let bufferBase64: String
        let cursor: Int
        let cwd: String
        let reqId: String
    }

    private static func parseCompleteQLine(_ line: String) -> ParsedComplete? {
        let trimmed = line.hasSuffix("\n") ? String(line.dropLast()) : line
        guard trimmed.hasPrefix("__termy_complete ") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: false)
        guard parts.count == 5, let cursor = Int(parts[2]) else { return nil }
        return ParsedComplete(
            bufferBase64: String(parts[1]),
            cursor: cursor,
            cwd: String(parts[3]),
            reqId: String(parts[4])
        )
    }

    private static func writeRequestMetadata(_ request: ParsedComplete, to workDir: URL) -> Bool {
        let body = "\(request.reqId)\t\(request.cwd.replacingOccurrences(of: "\t", with: " "))\n"
        let tmpURL = workDir.appendingPathComponent("__request__.tsv.tmp")
        let finalURL = workDir.appendingPathComponent("__request__.tsv")
        do {
            try body.write(to: tmpURL, atomically: true, encoding: .utf8)
            let result = tmpURL.path.withCString { tmpPath in
                finalURL.path.withCString { finalPath in
                    rename(tmpPath, finalPath)
                }
            }
            if result != 0 {
                try? FileManager.default.removeItem(at: tmpURL)
                return false
            }
            return true
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            return false
        }
    }

    private static func makeImmediatelyDisabled(
        workDir: URL,
        onEvent: @escaping @Sendable (CompletionSidecarResultWatcher.Event) -> Void,
        onStateChange: @escaping @Sendable (CompletionSidecar.State) -> Void = { _ in }
    ) -> CompletionSidecar {
        // Using initialState: .disabled means the actor is disabled synchronously
        // with no async Task hop required — the test can check state immediately.
        // Note: setState won't fire on init (state starts at .disabled already).
        // Callers that need to know the initial disabled state should check
        // sidecar.state synchronously after spawn returns.
        return CompletionSidecar(
            workDir: workDir,
            writer: { _ in },
            onEvent: onEvent,
            onStateChange: onStateChange,
            initialState: .disabled
        )
    }
}
