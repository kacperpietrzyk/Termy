import Foundation

public struct ShellCommandResult: Equatable, Sendable {
    public let command: String
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
}

public final class ShellCommandRunner: @unchecked Sendable {
    private let shellPath: String
    private let workingDirectory: URL?

    public init(shellPath: String = "/bin/zsh", workingDirectory: URL? = nil) {
        self.shellPath = shellPath
        self.workingDirectory = workingDirectory
    }

    public func run(_ command: String) throws -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-lc", command]
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let readerGroup = DispatchGroup()
        var stdoutData = Data()
        var stderrData = Data()
        readerGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            readerGroup.leave()
        }
        readerGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
            readerGroup.leave()
        }
        process.waitUntilExit()
        readerGroup.wait()

        return ShellCommandResult(
            command: command,
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }
}
