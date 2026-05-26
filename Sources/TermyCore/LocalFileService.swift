import Foundation

private extension String {
    func appendingPathComponent(_ component: String) -> String {
        isEmpty ? component : "\(self)/\(component)"
    }
}

public enum LocalFileServiceError: Error, Equatable {
    case pathEscapesRoot
    case invalidName
}

public struct LocalFileItem: Equatable, Identifiable, Sendable {
    public var id: String { relativePath }

    public let name: String
    public let relativePath: String
    public let isDirectory: Bool
    public let byteCount: Int?

    public init(name: String, relativePath: String, isDirectory: Bool, byteCount: Int? = nil) {
        self.name = name
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.byteCount = byteCount
    }
}

public struct LocalFileTreeItem: Equatable, Identifiable, Sendable {
    public var id: String { item.relativePath }

    public let item: LocalFileItem
    public let depth: Int
    public let iconName: String
    public let isExpandable: Bool

    public init(item: LocalFileItem, depth: Int, iconName: String? = nil, isExpandable: Bool? = nil) {
        self.item = item
        self.depth = depth
        self.iconName = iconName ?? LocalFileTypeIcon.iconName(for: item)
        self.isExpandable = isExpandable ?? item.isDirectory
    }
}

public enum LocalFileTypeIcon: Sendable {
    public static func iconName(for item: LocalFileItem) -> String {
        guard !item.isDirectory else { return "folder" }

        switch URL(fileURLWithPath: item.name).pathExtension.lowercased() {
        case "swift", "js", "jsx", "ts", "tsx", "rs", "py", "html", "css", "json":
            return "curlybraces"
        case "md", "markdown", "txt", "rtf":
            return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "heic", "webp", "svg":
            return "photo"
        case "sh", "zsh", "bash", "fish":
            return "terminal"
        default:
            return "doc"
        }
    }
}

public struct LocalFileSearch: Sendable {
    public let items: [LocalFileItem]

    public init(items: [LocalFileItem]) {
        self.items = items
    }

    public func search(_ query: String) -> [LocalFileItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return items }

        let tokens = normalizedQuery.split(separator: " ").map(String.init)
        return items
            .compactMap { item -> (LocalFileItem, Int)? in
                let name = item.name.lowercased()
                let path = item.relativePath.lowercased()
                guard tokens.allSatisfy({ name.contains($0) || path.contains($0) }) else {
                    return nil
                }

                var score = 0
                for token in tokens {
                    if name == token {
                        score += 100
                    } else if name.hasPrefix(token) {
                        score += 70
                    } else if name.contains(token) {
                        score += 50
                    } else if path.contains(token) {
                        score += 10
                    }
                }
                if item.isDirectory {
                    score += 5
                }
                return (item, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.relativePath.localizedStandardCompare(rhs.0.relativePath) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }
}

public struct LocalFileService {
    public let root: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        self.fileManager = fileManager
    }

    public func list(relativePath: String = "") throws -> [LocalFileItem] {
        let directory = try resolvedURL(for: relativePath)
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        return try urls
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                return LocalFileItem(
                    name: url.lastPathComponent,
                    relativePath: relativePath.isEmpty ? url.lastPathComponent : "\(relativePath)/\(url.lastPathComponent)",
                    isDirectory: values.isDirectory == true,
                    byteCount: values.isDirectory == true ? nil : values.fileSize
                )
            }
    }

    public func tree(relativePath: String = "") throws -> [LocalFileTreeItem] {
        try treeItems(relativePath: relativePath, depth: 0)
    }

    public func createFile(named relativePath: String, contents: String = "") throws {
        let url = try resolvedURL(for: relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    public func readText(_ relativePath: String) throws -> String {
        let url = try resolvedURL(for: relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func writeText(_ text: String, to relativePath: String) throws {
        let url = try resolvedURL(for: relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public func createDirectory(named relativePath: String) throws {
        let url = try resolvedURL(for: relativePath)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func rename(_ relativePath: String, to newRelativePath: String) throws {
        let source = try resolvedURL(for: relativePath)
        let destination = try resolvedURL(for: newRelativePath)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: source, to: destination)
    }

    @discardableResult
    public func move(_ relativePath: String, toDirectory destinationDirectory: String) throws -> String {
        let source = try resolvedURL(for: relativePath)
        let directory = try resolvedURL(for: destinationDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destinationRelativePath = destinationDirectory
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .appendingPathComponent(source.lastPathComponent)
        let destination = try resolvedURL(for: destinationRelativePath)
        try fileManager.moveItem(at: source, to: destination)
        return destinationRelativePath
    }

    public func delete(_ relativePath: String) throws {
        let url = try resolvedURL(for: relativePath)
        try fileManager.removeItem(at: url)
    }

    private func resolvedURL(for relativePath: String) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || relativePath.isEmpty else {
            throw LocalFileServiceError.invalidName
        }

        let candidate = root
            .appendingPathComponent(trimmed)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path == root.path || candidate.path.hasPrefix(rootPath) else {
            throw LocalFileServiceError.pathEscapesRoot
        }
        return candidate
    }

    private func treeItems(relativePath: String, depth: Int) throws -> [LocalFileTreeItem] {
        var result: [LocalFileTreeItem] = []
        for item in try list(relativePath: relativePath).sorted(by: fileTreeSort) {
            result.append(LocalFileTreeItem(item: item, depth: depth))
            if item.isDirectory {
                result.append(contentsOf: try treeItems(relativePath: item.relativePath, depth: depth + 1))
            }
        }
        return result
    }

    private func fileTreeSort(_ lhs: LocalFileItem, _ rhs: LocalFileItem) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
