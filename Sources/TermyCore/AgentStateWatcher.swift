import Foundation

/// Thin `DispatchSourceFileSystemObject` watch over the agent-state directory
/// (FB-3-2), mirroring F-4's `CompletionSidecar` watch. Fires `onChange` when
/// the directory's entries change (the helper's atomic `rename` of a `.state`
/// file). The consume/parse logic lives in `AgentStateFiles` (unit-tested);
/// this is glue, verified by the manual visual gate.
public final class AgentStateWatcher {
    private let directory: URL
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "termy.agent-state-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1

    public init(directory: URL, onChange: @escaping @Sendable () -> Void) {
        self.directory = directory
        self.onChange = onChange
    }

    /// Returns `false` if the directory fd could not be opened (so the caller
    /// can avoid retaining a dead watcher and retry later).
    @discardableResult
    public func start() -> Bool {
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return false }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: queue)
        let onChange = self.onChange
        src.setEventHandler { onChange() }
        let capturedFD = fd
        src.setCancelHandler { close(capturedFD) }
        source = src
        src.resume()
        return true
    }

    public func stop() {
        source?.cancel()
        source = nil
        fd = -1
    }

    deinit { source?.cancel() }
}
