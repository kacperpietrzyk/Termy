import Foundation

public struct SessionRestoreMetadata: Equatable, Sendable {
    public let capturedAt: Date
    public let sessionCount: Int
    public let globalByteCount: Int
}

public struct SessionRestoreStore: @unchecked Sendable {
    public let directoryURL: URL
    public let fileManager: FileManager

    public init() {
        self.init(directoryURL: Self.defaultDirectoryURL(), fileManager: .default)
    }

    public init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    public static func defaultDirectoryURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("Termy/SessionRestore", isDirectory: true)
    }

    public var snapshotURL: URL {
        directoryURL.appendingPathComponent("last-session.json", isDirectory: false)
    }

    public var temporarySnapshotURL: URL {
        directoryURL.appendingPathComponent(".last-session.json.tmp", isDirectory: false)
    }

    public var corruptSnapshotURL: URL {
        directoryURL.appendingPathComponent("last-session.json.bad", isDirectory: false)
    }

    public func save(_ snapshot: SessionRestoreSnapshot) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let tempURL = uniqueTemporarySnapshotURL()
        let bounded = SessionRestoreSnapshot.makeBounded(
            capturedAt: snapshot.capturedAt,
            selectedSessionID: snapshot.selectedSessionID,
            paneTree: snapshot.paneTree,
            focusedPane: snapshot.focusedPane,
            activePanel: snapshot.activePanel,
            sessions: snapshot.sessions
        )
        let data = try JSONEncoder.sessionRestore.encode(bounded)
        try data.write(to: tempURL, options: [.atomic])
        defer {
            try? fileManager.removeItem(at: tempURL)
        }

        if fileManager.fileExists(atPath: snapshotURL.path) {
            try replaceSnapshot(with: tempURL)
        } else {
            do {
                try fileManager.moveItem(at: tempURL, to: snapshotURL)
            } catch {
                if fileManager.fileExists(atPath: snapshotURL.path) {
                    try replaceSnapshot(with: tempURL)
                } else {
                    throw error
                }
            }
        }
    }

    public func load() throws -> SessionRestoreSnapshot? {
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: snapshotURL)
        } catch {
            if !fileManager.fileExists(atPath: snapshotURL.path),
               hasCorruptSnapshot() {
                return nil
            }
            throw error
        }

        let schema: SessionRestoreSchemaEnvelope
        do {
            schema = try JSONDecoder.sessionRestore.decode(
                SessionRestoreSchemaEnvelope.self,
                from: data
            )
        } catch is DecodingError {
            try moveCorruptSnapshotAside(matching: data)
            return nil
        }

        guard schema.schemaVersion <= SessionRestoreSnapshot.currentSchemaVersion else {
            return nil
        }

        do {
            let snapshot = try JSONDecoder.sessionRestore.decode(
                SessionRestoreSnapshot.self,
                from: data
            )
            guard snapshot.schemaVersion == SessionRestoreSnapshot.currentSchemaVersion else {
                return nil
            }
            return snapshot
        } catch is DecodingError {
            try moveCorruptSnapshotAside(matching: data)
            return nil
        }
    }

    public func hasValidSnapshot() -> Bool {
        guard let snapshot = try? load() else { return false }
        return !snapshot.sessions.isEmpty
    }

    public func metadata() throws -> SessionRestoreMetadata? {
        guard let snapshot = try load(),
              !snapshot.sessions.isEmpty else { return nil }
        return SessionRestoreMetadata(
            capturedAt: snapshot.capturedAt,
            sessionCount: snapshot.sessions.count,
            globalByteCount: snapshot.globalByteCount
        )
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: snapshotURL.path) else { return }
        try fileManager.removeItem(at: snapshotURL)
    }

    private func uniqueTemporarySnapshotURL() -> URL {
        directoryURL.appendingPathComponent(".last-session.\(UUID().uuidString).tmp", isDirectory: false)
    }

    private func replaceSnapshot(with tempURL: URL) throws {
        _ = try fileManager.replaceItemAt(
            snapshotURL,
            withItemAt: tempURL,
            backupItemName: nil,
            options: []
        )
    }

    func moveCorruptSnapshotAside(matching failedData: Data) throws {
        let currentData: Data
        do {
            currentData = try Data(contentsOf: snapshotURL)
        } catch {
            if !fileManager.fileExists(atPath: snapshotURL.path),
               hasCorruptSnapshot() {
                return
            }
            throw error
        }

        guard currentData == failedData else {
            return
        }

        do {
            try fileManager.moveItem(at: snapshotURL, to: availableCorruptSnapshotURL())
        } catch {
            if !fileManager.fileExists(atPath: snapshotURL.path),
               hasCorruptSnapshot() {
                return
            }
            throw error
        }
    }

    private func availableCorruptSnapshotURL() -> URL {
        guard fileManager.fileExists(atPath: corruptSnapshotURL.path) else {
            return corruptSnapshotURL
        }
        return directoryURL.appendingPathComponent("last-session.\(UUID().uuidString).json.bad", isDirectory: false)
    }

    private func hasCorruptSnapshot() -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        return contents.contains { $0.lastPathComponent.hasSuffix(".bad") }
    }
}

private struct SessionRestoreSchemaEnvelope: Decodable {
    let schemaVersion: Int
}
