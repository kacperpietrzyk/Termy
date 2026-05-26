import Foundation

extension WorkspacePaneKind: Codable {}

public enum SessionRestoreLimits {
    public static let maxLinesPerSession = 2_000
    public static let maxBytesPerSession = 1 * 1_024 * 1_024
    public static let maxBytesGlobal = 25 * 1_024 * 1_024
    public static let truncationMarker = " [truncated by Termy session restore]"
}

public struct SessionRestoreSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let capturedAt: Date
    public let selectedSessionID: UUID?
    public let paneTree: String?
    public let focusedPane: WorkspacePaneKind
    public let activePanel: String?
    public let sessions: [SessionRestoreEntry]
    public let globalByteCount: Int

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case capturedAt
        case selectedSessionID
        case paneTree
        case focusedPane
        case activePanel
        case sessions
        case globalByteCount
    }

    public init(
        schemaVersion: Int,
        capturedAt: Date,
        selectedSessionID: UUID?,
        paneTree: String?,
        focusedPane: WorkspacePaneKind,
        activePanel: String?,
        sessions: [SessionRestoreEntry],
        globalByteCount: Int
    ) {
        let bounded = Self.boundedSessionsAndByteCount(from: sessions)
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.selectedSessionID = selectedSessionID
        self.paneTree = Self.validPaneTreeStorageValue(paneTree)
        self.focusedPane = focusedPane
        self.activePanel = activePanel
        self.sessions = bounded.sessions
        self.globalByteCount = bounded.globalByteCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            capturedAt: try container.decode(Date.self, forKey: .capturedAt),
            selectedSessionID: try container.decodeIfPresent(UUID.self, forKey: .selectedSessionID),
            paneTree: try container.decodeIfPresent(String.self, forKey: .paneTree),
            focusedPane: try container.decode(WorkspacePaneKind.self, forKey: .focusedPane),
            activePanel: try container.decodeIfPresent(String.self, forKey: .activePanel),
            sessions: try container.decode([SessionRestoreEntry].self, forKey: .sessions),
            globalByteCount: try container.decode(Int.self, forKey: .globalByteCount)
        )
    }

    public static func makeBounded(
        capturedAt: Date,
        selectedSessionID: UUID?,
        paneTree: String?,
        focusedPane: WorkspacePaneKind,
        activePanel: String?,
        sessions: [SessionRestoreEntry]
    ) -> SessionRestoreSnapshot {
        SessionRestoreSnapshot(
            schemaVersion: currentSchemaVersion,
            capturedAt: capturedAt,
            selectedSessionID: selectedSessionID,
            paneTree: paneTree,
            focusedPane: focusedPane,
            activePanel: activePanel,
            sessions: sessions,
            globalByteCount: 0
        )
    }

    private static func boundedSessionsAndByteCount(
        from sessions: [SessionRestoreEntry]
    ) -> (sessions: [SessionRestoreEntry], globalByteCount: Int) {
        var boundedSessions = sessions.map { entry in
            let bounded = SessionRestoreEntry.boundedScrollback(from: entry.scrollback)
            return entry.withScrollback(bounded.lines, bytes: bounded.bytes)
        }

        var globalByteCount = boundedSessions.reduce(0) { $0 + $1.scrollbackBytes }
        let trimmingOrder = boundedSessions.indices.sorted { lhs, rhs in
            if boundedSessions[lhs].capturedAt == boundedSessions[rhs].capturedAt {
                return lhs < rhs
            }
            return boundedSessions[lhs].capturedAt < boundedSessions[rhs].capturedAt
        }
        for trimmingIndex in trimmingOrder where globalByteCount > SessionRestoreLimits.maxBytesGlobal {
            let entry = boundedSessions[trimmingIndex]
            let overflow = globalByteCount - SessionRestoreLimits.maxBytesGlobal
            if entry.scrollbackBytes <= overflow {
                boundedSessions[trimmingIndex] = entry.withScrollback([], bytes: 0)
                globalByteCount -= entry.scrollbackBytes
            } else {
                let trimmed = SessionRestoreEntry.scrollbackByDroppingOldestBytes(
                    from: entry.scrollback,
                    bytesToDrop: overflow
                )
                boundedSessions[trimmingIndex] = entry.withScrollback(trimmed.lines, bytes: trimmed.bytes)
                globalByteCount = boundedSessions.reduce(0) { $0 + $1.scrollbackBytes }
            }
        }

        return (boundedSessions, globalByteCount)
    }

    public static func validPaneTreeStorageValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let paneTree = WorkspacePaneTree(storageValue: trimmed) else {
            return nil
        }
        return paneTree.storageValue
    }
}

public enum SessionRestoreKind: String, Codable, Equatable, Sendable {
    case localPTY
    case ssh
    case cliAgent
    case rdpPlaceholder
}

public enum SessionRestoreProfileReference: Codable, Equatable, Sendable {
    case local
    case connectionProfile(id: String, name: String, host: String)
    case tool(kind: String, displayName: String)
}

public enum SessionRestoreLaunch: Codable, Equatable, Sendable {
    case localShell(shellKind: String, executable: String, arguments: [String])
    case sshProfile(profileID: String, fallbackName: String, executable: String, arguments: [String])
    case cliAgent(kind: String, executable: String, arguments: [String])
    case rdpPlaceholder(profileID: String, fallbackName: String)
}

public struct SessionRestoreEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let kind: SessionRestoreKind
    public let profileReference: SessionRestoreProfileReference
    public let workingDirectory: String?
    public let launch: SessionRestoreLaunch
    public let scrollback: [RestoredTerminalLine]
    public let scrollbackBytes: Int
    public let lastExitCode: Int?
    public let capturedAt: Date

    public init(
        id: UUID,
        title: String,
        kind: SessionRestoreKind,
        profileReference: SessionRestoreProfileReference,
        workingDirectory: String?,
        launch: SessionRestoreLaunch,
        scrollback: [RestoredTerminalLine],
        scrollbackBytes: Int,
        lastExitCode: Int?,
        capturedAt: Date
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.profileReference = profileReference
        self.workingDirectory = workingDirectory
        self.launch = launch
        self.scrollback = scrollback
        self.scrollbackBytes = scrollbackBytes
        self.lastExitCode = lastExitCode
        self.capturedAt = capturedAt
    }

    public static func boundedScrollback(
        from lines: [RestoredTerminalLine]
    ) -> (lines: [RestoredTerminalLine], bytes: Int) {
        var boundedLines: [RestoredTerminalLine] = []
        var byteCount = 0

        for line in lines.suffix(SessionRestoreLimits.maxLinesPerSession).reversed() {
            let lineBytes = line.byteCount
            let remainingBytes = SessionRestoreLimits.maxBytesPerSession - byteCount
            guard remainingBytes > 0 else { break }

            if lineBytes <= remainingBytes {
                boundedLines.insert(line, at: 0)
                byteCount += lineBytes
            } else {
                let truncatedLine = line.truncatedToByteLimit(remainingBytes)
                boundedLines.insert(truncatedLine, at: 0)
                byteCount += truncatedLine.byteCount
                break
            }
        }

        return (boundedLines, byteCount)
    }

    fileprivate static func scrollbackByDroppingOldestBytes(
        from lines: [RestoredTerminalLine],
        bytesToDrop: Int
    ) -> (lines: [RestoredTerminalLine], bytes: Int) {
        var remainingDrop = bytesToDrop
        var keptLines: [RestoredTerminalLine] = []

        for line in lines {
            let byteCount = line.byteCount
            if remainingDrop >= byteCount {
                remainingDrop -= byteCount
            } else if remainingDrop > 0 {
                let targetBytes = max(0, byteCount - remainingDrop)
                let truncated = line.truncatedFromStartToByteLimit(targetBytes)
                keptLines.append(truncated)
                remainingDrop = 0
            } else {
                keptLines.append(line)
            }
        }

        return boundedScrollback(from: keptLines)
    }

    fileprivate func withScrollback(
        _ scrollback: [RestoredTerminalLine],
        bytes: Int
    ) -> SessionRestoreEntry {
        SessionRestoreEntry(
            id: id,
            title: title,
            kind: kind,
            profileReference: profileReference,
            workingDirectory: workingDirectory,
            launch: launch,
            scrollback: scrollback,
            scrollbackBytes: bytes,
            lastExitCode: lastExitCode,
            capturedAt: capturedAt
        )
    }
}

public struct RestoredTerminalLine: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Equatable, Sendable {
        case prompt
        case stdout
        case stderr
        case system
    }

    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }

    fileprivate var byteCount: Int {
        text.utf8.count
    }

    fileprivate func truncatedToByteLimit(_ byteLimit: Int) -> RestoredTerminalLine {
        let markerBytes = SessionRestoreLimits.truncationMarker.utf8.count
        guard byteLimit > 0 else {
            return RestoredTerminalLine(role: role, text: "")
        }
        guard byteLimit > markerBytes else {
            return RestoredTerminalLine(role: role, text: SessionRestoreLimits.truncationMarker.prefixUTF8(byteLimit))
        }

        let prefixByteLimit = byteLimit - markerBytes
        var truncatedText = text
        while truncatedText.utf8.count > prefixByteLimit {
            truncatedText.removeLast()
        }
        return RestoredTerminalLine(role: role, text: truncatedText + SessionRestoreLimits.truncationMarker)
    }

    fileprivate func truncatedFromStartToByteLimit(_ byteLimit: Int) -> RestoredTerminalLine {
        let markerBytes = SessionRestoreLimits.truncationMarker.utf8.count
        guard byteLimit > 0 else {
            return RestoredTerminalLine(role: role, text: "")
        }
        guard byteLimit > markerBytes else {
            return RestoredTerminalLine(role: role, text: SessionRestoreLimits.truncationMarker.prefixUTF8(byteLimit))
        }

        let suffixByteLimit = byteLimit - markerBytes
        var truncatedText = text
        while truncatedText.utf8.count > suffixByteLimit {
            truncatedText.removeFirst()
        }
        return RestoredTerminalLine(role: role, text: SessionRestoreLimits.truncationMarker + truncatedText)
    }
}

private extension String {
    func prefixUTF8(_ byteLimit: Int) -> String {
        guard byteLimit > 0 else { return "" }
        var result = self
        while result.utf8.count > byteLimit {
            result.removeLast()
        }
        return result
    }
}

public extension JSONEncoder {
    static var sessionRestore: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var sessionRestore: JSONDecoder {
        JSONDecoder()
    }
}
