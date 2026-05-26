import Foundation

public struct SFTPRemoteItem: Equatable, Sendable {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int

    public init(name: String, path: String, isDirectory: Bool, size: Int) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
    }
}

public struct SFTPDirectoryListingParser: Sendable {
    public init() {}

    public func parse(_ output: String, currentDirectory: String) -> [SFTPRemoteItem] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0), currentDirectory: currentDirectory) }
    }

    private func parseLine(_ line: String, currentDirectory: String) -> SFTPRemoteItem? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 9 else { return nil }
        let permissions = String(parts[0])
        let size = Int(parts[4]) ?? 0
        let name = parts[8...].joined(separator: " ")
        guard name != "." && name != ".." else { return nil }
        let directory = currentDirectory.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let path = "/" + ([directory, name].filter { !$0.isEmpty }.joined(separator: "/"))
        return SFTPRemoteItem(
            name: name,
            path: path,
            isDirectory: permissions.hasPrefix("d"),
            size: size
        )
    }
}

public struct SFTPBatchCommand: Equatable, Sendable {
    public let script: String

    public static func upload(localPath: String, remotePath: String) -> SFTPBatchCommand {
        SFTPBatchCommand(script: "put \(batchPath(localPath)) \(batchPath(remotePath))\n")
    }

    public static func download(remotePath: String, localPath: String) -> SFTPBatchCommand {
        SFTPBatchCommand(script: "get \(batchPath(remotePath)) \(batchPath(localPath))\n")
    }

    public static func listDirectory(remotePath: String) -> SFTPBatchCommand {
        SFTPBatchCommand(script: "cd \(batchPath(remotePath.isEmpty ? "." : remotePath))\nls -l\n")
    }

    public static func createDirectory(remotePath: String) -> SFTPBatchCommand {
        SFTPBatchCommand(script: "mkdir \(batchPath(remotePath))\n")
    }

    public static func rename(remotePath: String, to newRemotePath: String) -> SFTPBatchCommand {
        SFTPBatchCommand(script: "rename \(batchPath(remotePath)) \(batchPath(newRemotePath))\n")
    }

    public static func delete(remotePath: String, isDirectory: Bool) -> SFTPBatchCommand {
        SFTPBatchCommand(script: "\(isDirectory ? "rmdir" : "rm") \(batchPath(remotePath))\n")
    }

    private static func batchPath(_ path: String) -> String {
        let escaped = path.reduce(into: "") { result, character in
            switch character {
            case "\\":
                result += "\\\\"
            case "\"":
                result += "\\\""
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            default:
                result.append(character)
            }
        }
        return "\"\(escaped)\""
    }
}

public struct SFTPTransferPlanner: Sendable {
    public let localRoot: URL
    public let remoteDirectory: String

    public init(localRoot: URL, remoteDirectory: String) {
        self.localRoot = localRoot
        self.remoteDirectory = remoteDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func uploadDroppedLocalFile(_ localURL: URL) -> SFTPBatchCommand {
        let remoteBase = remoteDirectory.isEmpty ? "." : remoteDirectory
        let remotePath = "\(remoteBase)/\(localURL.lastPathComponent)"
        return .upload(localPath: localURL.path, remotePath: remotePath)
    }

    public func downloadDroppedRemoteItem(_ item: SFTPRemoteItem) -> SFTPBatchCommand {
        .download(
            remotePath: item.path,
            localPath: localRoot.appendingPathComponent(item.name).path
        )
    }

    public func createDirectory(named name: String) -> SFTPBatchCommand {
        .createDirectory(remotePath: joinedRemotePath(directory: remoteDirectory, name: name))
    }

    public func rename(_ item: SFTPRemoteItem, to newName: String) -> SFTPBatchCommand {
        .rename(
            remotePath: item.path,
            to: joinedRemotePath(directory: parentDirectory(of: item.path), name: newName)
        )
    }

    public func delete(_ item: SFTPRemoteItem) -> SFTPBatchCommand {
        .delete(remotePath: item.path, isDirectory: item.isDirectory)
    }

    public func move(_ item: SFTPRemoteItem, toDirectory destinationDirectory: String) -> SFTPBatchCommand {
        .rename(
            remotePath: item.path,
            to: joinedRemotePath(directory: destinationDirectory, name: item.name)
        )
    }

    private func joinedRemotePath(directory: String, name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDirectory = directory.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedDirectory.isEmpty else { return trimmedName.isEmpty ? "." : trimmedName }
        return "/" + [trimmedDirectory, trimmedName].filter { !$0.isEmpty }.joined(separator: "/")
    }

    private func parentDirectory(of path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        return parent.isEmpty ? "." : parent
    }
}
