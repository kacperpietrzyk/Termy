import XCTest
import TermyCore

final class SessionRestoreSnapshotTests: XCTestCase {
    func testSnapshotRoundTripsSchemaVersionOne() throws {
        let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let snapshot = SessionRestoreSnapshot(
            schemaVersion: SessionRestoreSnapshot.currentSchemaVersion,
            capturedAt: Date(timeIntervalSince1970: 1_779_340_800),
            selectedSessionID: sessionID,
            paneTree: "h:0.50(terminal|ai)",
            focusedPane: .terminal,
            activePanel: "ai",
            sessions: [
                SessionRestoreEntry(
                    id: sessionID,
                    title: "Local",
                    kind: .localPTY,
                    profileReference: .local,
                    workingDirectory: "/Users/kacper/Projects/Termy",
                    launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
                    scrollback: [
                        RestoredTerminalLine(role: .system, text: "boot"),
                        RestoredTerminalLine(role: .stdout, text: "output")
                    ],
                    scrollbackBytes: 10,
                    lastExitCode: 0,
                    capturedAt: Date(timeIntervalSince1970: 1_779_340_801)
                )
            ],
            globalByteCount: 10
        )

        let data = try JSONEncoder.sessionRestore.encode(snapshot)
        let decoded = try JSONDecoder.sessionRestore.decode(SessionRestoreSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testBoundedEntryKeepsNewestTwoThousandLines() {
        let lines = (0..<2_050).map { RestoredTerminalLine(role: .stdout, text: "line-\($0)") }

        let bounded = SessionRestoreEntry.boundedScrollback(from: lines)

        XCTAssertEqual(bounded.lines.count, 2_000)
        XCTAssertEqual(bounded.lines.first?.text, "line-50")
        XCTAssertEqual(bounded.lines.last?.text, "line-2049")
        XCTAssertLessThanOrEqual(bounded.bytes, SessionRestoreLimits.maxBytesPerSession)
    }

    func testBoundedEntryTruncatesSingleHugeLineWithMarker() {
        let huge = String(repeating: "x", count: SessionRestoreLimits.maxBytesPerSession + 100)

        let bounded = SessionRestoreEntry.boundedScrollback(from: [
            RestoredTerminalLine(role: .stdout, text: huge)
        ])

        XCTAssertEqual(bounded.lines.count, 1)
        XCTAssertTrue(bounded.lines[0].text.hasSuffix(SessionRestoreLimits.truncationMarker))
        XCTAssertLessThanOrEqual(bounded.bytes, SessionRestoreLimits.maxBytesPerSession)
    }

    func testDirectSnapshotInitializerCapsOversizedEntriesAndRecomputesGlobalByteCount() {
        let rawEntry = makeRawEntry(
            id: UUID(),
            title: "raw",
            lines: (0..<2_050).map { RestoredTerminalLine(role: .stdout, text: "line-\($0)") },
            scrollbackBytes: 99 * 1_024 * 1_024,
            capturedAt: Date(timeIntervalSince1970: 10)
        )

        let snapshot = SessionRestoreSnapshot(
            schemaVersion: SessionRestoreSnapshot.currentSchemaVersion,
            capturedAt: Date(timeIntervalSince1970: 20),
            selectedSessionID: rawEntry.id,
            paneTree: nil,
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [rawEntry],
            globalByteCount: 99 * 1_024 * 1_024
        )

        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.sessions[0].scrollback.count, 2_000)
        XCTAssertEqual(snapshot.sessions[0].scrollback.first?.text, "line-50")
        XCTAssertLessThanOrEqual(snapshot.sessions[0].scrollbackBytes, SessionRestoreLimits.maxBytesPerSession)
        XCTAssertEqual(snapshot.globalByteCount, snapshot.sessions[0].scrollbackBytes)
    }

    func testDecodingCapsOversizedScrollbackAndRecomputesGlobalByteCount() throws {
        let rawEntry = makeRawEntry(
            id: UUID(),
            title: "decoded",
            lines: [
                RestoredTerminalLine(
                    role: .stdout,
                    text: String(repeating: "x", count: SessionRestoreLimits.maxBytesPerSession + 128)
                )
            ],
            scrollbackBytes: 99 * 1_024 * 1_024,
            capturedAt: Date(timeIntervalSince1970: 10)
        )
        let entryJSON = String(data: try JSONEncoder.sessionRestore.encode(rawEntry), encoding: .utf8)!
        let json = """
        {
          "activePanel": null,
          "capturedAt": 20,
          "focusedPane": "terminal",
          "globalByteCount": 999999999,
          "paneTree": "h:0.50(terminal|unknown)",
          "schemaVersion": 1,
          "selectedSessionID": "\(rawEntry.id.uuidString)",
          "sessions": [\(entryJSON)]
        }
        """

        let snapshot = try JSONDecoder.sessionRestore.decode(SessionRestoreSnapshot.self, from: Data(json.utf8))

        XCTAssertNil(snapshot.paneTree)
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertEqual(snapshot.sessions[0].scrollback.count, 1)
        XCTAssertTrue(snapshot.sessions[0].scrollback[0].text.hasSuffix(SessionRestoreLimits.truncationMarker))
        XCTAssertLessThanOrEqual(snapshot.sessions[0].scrollbackBytes, SessionRestoreLimits.maxBytesPerSession)
        XCTAssertEqual(snapshot.globalByteCount, snapshot.sessions[0].scrollbackBytes)
    }

    func testSnapshotTypesExposeSpecCasesAndLabels() throws {
        let entry = SessionRestoreEntry(
            id: UUID(),
            title: "Codex",
            kind: .cliAgent,
            profileReference: .tool(kind: "codex", displayName: "Codex"),
            workingDirectory: "/tmp",
            launch: .cliAgent(kind: "codex", executable: "/usr/bin/codex", arguments: ["--help"]),
            scrollback: [
                RestoredTerminalLine(role: .prompt, text: "$ codex --help"),
                RestoredTerminalLine(role: .stderr, text: "warning"),
                RestoredTerminalLine(role: .system, text: "done")
            ],
            scrollbackBytes: 27,
            lastExitCode: nil,
            capturedAt: Date(timeIntervalSince1970: 11)
        )
        let rdp = SessionRestoreEntry(
            id: UUID(),
            title: "Windows",
            kind: .rdpPlaceholder,
            profileReference: .connectionProfile(id: "rdp-1", name: "windows", host: "windows.example.test"),
            workingDirectory: nil,
            launch: .rdpPlaceholder(profileID: "rdp-1", fallbackName: "windows"),
            scrollback: [],
            scrollbackBytes: 0,
            lastExitCode: nil,
            capturedAt: Date(timeIntervalSince1970: 12)
        )

        let snapshot = SessionRestoreSnapshot.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 10),
            selectedSessionID: entry.id,
            paneTree: nil,
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [entry, rdp]
        )

        let data = try JSONEncoder.sessionRestore.encode(snapshot)
        let decoded = try JSONDecoder.sessionRestore.decode(SessionRestoreSnapshot.self, from: data)

        XCTAssertEqual(decoded.sessions, snapshot.sessions)
    }

    func testSnapshotGlobalCapTrimsOldestSessionScrollback() {
        let old = makeRawEntry(
            id: UUID(),
            title: "old",
            lines: [RestoredTerminalLine(role: .stdout, text: String(repeating: "o", count: SessionRestoreLimits.maxBytesPerSession))],
            scrollbackBytes: SessionRestoreLimits.maxBytesPerSession,
            capturedAt: Date(timeIntervalSince1970: 10)
        )
        let new = makeRawEntry(
            id: UUID(),
            title: "new",
            lines: [RestoredTerminalLine(role: .stdout, text: String(repeating: "n", count: SessionRestoreLimits.maxBytesPerSession))],
            scrollbackBytes: SessionRestoreLimits.maxBytesPerSession,
            capturedAt: Date(timeIntervalSince1970: 20)
        )
        let fillers = (0..<24).map { index in
            makeRawEntry(
                id: UUID(),
                title: "filler-\(index)",
                lines: [RestoredTerminalLine(role: .stdout, text: String(repeating: "f", count: SessionRestoreLimits.maxBytesPerSession))],
                scrollbackBytes: SessionRestoreLimits.maxBytesPerSession,
                capturedAt: Date(timeIntervalSince1970: 100 + Double(index))
            )
        }

        let snapshot = SessionRestoreSnapshot.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 10),
            selectedSessionID: new.id,
            paneTree: nil,
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [old, new] + fillers
        )

        XCTAssertLessThanOrEqual(snapshot.globalByteCount, SessionRestoreLimits.maxBytesGlobal)
        XCTAssertEqual(snapshot.sessions[1].title, "new")
        XCTAssertGreaterThan(snapshot.sessions[1].scrollback.count, 0)
        XCTAssertEqual(snapshot.sessions[0].title, "old")
        XCTAssertEqual(snapshot.sessions[0].scrollback.count, 0)
    }

    func testSnapshotGlobalCapTrimsOldestCapturedSessionWhenInputIsUnsorted() {
        let newest = makeEntry(
            id: UUID(),
            title: "newest",
            text: String(repeating: "n", count: SessionRestoreLimits.maxBytesPerSession),
            capturedAt: Date(timeIntervalSince1970: 30)
        )
        let oldest = makeEntry(
            id: UUID(),
            title: "oldest",
            text: String(repeating: "o", count: SessionRestoreLimits.maxBytesPerSession),
            capturedAt: Date(timeIntervalSince1970: 10)
        )
        let fillers = (0..<24).map { index in
            makeEntry(
                id: UUID(),
                title: "filler-\(index)",
                text: String(repeating: "f", count: SessionRestoreLimits.maxBytesPerSession),
                capturedAt: Date(timeIntervalSince1970: 100 + Double(index))
            )
        }

        let snapshot = SessionRestoreSnapshot.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 200),
            selectedSessionID: newest.id,
            paneTree: nil,
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [newest, oldest] + fillers
        )

        XCTAssertEqual(snapshot.sessions.map(\.title).prefix(2), ["newest", "oldest"])
        XCTAssertGreaterThan(snapshot.sessions[0].scrollback.count, 0)
        XCTAssertEqual(snapshot.sessions[1].scrollback.count, 0)
        XCTAssertLessThanOrEqual(snapshot.globalByteCount, SessionRestoreLimits.maxBytesGlobal)
    }

    func testGlobalPartialLineTrimPreservesNewestSuffixContent() {
        let oldestText = "old-prefix-" + String(repeating: "m", count: SessionRestoreLimits.maxBytesPerSession - 31) + "-newest-suffix"
        let oldest = makeEntry(
            id: UUID(),
            title: "oldest",
            text: oldestText,
            capturedAt: Date(timeIntervalSince1970: 10)
        )
        let fillers = (0..<24).map { index in
            makeEntry(
                id: UUID(),
                title: "filler-\(index)",
                text: String(repeating: "f", count: SessionRestoreLimits.maxBytesPerSession),
                capturedAt: Date(timeIntervalSince1970: 100 + Double(index))
            )
        }
        let overflow = makeEntry(
            id: UUID(),
            title: "overflow",
            text: String(repeating: "x", count: 128),
            capturedAt: Date(timeIntervalSince1970: 200)
        )

        let snapshot = SessionRestoreSnapshot.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 300),
            selectedSessionID: nil,
            paneTree: nil,
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [oldest] + fillers + [overflow]
        )

        let trimmedOldest = snapshot.sessions[0].scrollback.first?.text
        XCTAssertTrue(trimmedOldest?.contains("-newest-suffix") == true)
        XCTAssertFalse(trimmedOldest?.contains("old-prefix-") == true)
        XCTAssertLessThanOrEqual(snapshot.globalByteCount, SessionRestoreLimits.maxBytesGlobal)
    }

    func testSerializedSnapshotDoesNotContainSecretFieldNames() throws {
        let snapshot = SessionRestoreSnapshot.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 10),
            selectedSessionID: nil,
            paneTree: nil,
            focusedPane: .terminal,
            activePanel: nil,
            sessions: [
                makeEntry(id: UUID(), title: "ssh", repeatedByteCount: 128)
                    .withProfileReference(.connectionProfile(id: "profile-1", name: "prod", host: "prod.example.test"))
                    .withLaunch(.sshProfile(profileID: "profile-1", fallbackName: "prod", executable: "/usr/bin/ssh", arguments: ["prod"]))
            ]
        )

        let json = String(data: try JSONEncoder.sessionRestore.encode(snapshot), encoding: .utf8)!

        XCTAssertFalse(json.localizedCaseInsensitiveContains("password"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("passphrase"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("token"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("credential"))
    }

    func testValidPaneTreeIsAcceptedAndInvalidPaneTreeIsCleared() {
        XCTAssertEqual(
            SessionRestoreSnapshot.validPaneTreeStorageValue("h:0.34(terminal|ai)"),
            "h:0.34(terminal|ai)"
        )
        XCTAssertNil(SessionRestoreSnapshot.validPaneTreeStorageValue("h:0.50(terminal|unknown)"))
    }

    func testDecodingClearsInvalidPaneTree() throws {
        let snapshot = SessionRestoreSnapshot.makeBounded(
            capturedAt: Date(timeIntervalSince1970: 10),
            selectedSessionID: nil,
            paneTree: "h:0.50(terminal|ai)",
            focusedPane: .terminal,
            activePanel: nil,
            sessions: []
        )
        var json = String(data: try JSONEncoder.sessionRestore.encode(snapshot), encoding: .utf8)!
        json = json.replacingOccurrences(of: "h:0.50(terminal|ai)", with: "h:0.50(terminal|unknown)")

        let decoded = try JSONDecoder.sessionRestore.decode(SessionRestoreSnapshot.self, from: Data(json.utf8))

        XCTAssertNil(decoded.paneTree)
    }

    private func makeEntry(id: UUID, title: String, repeatedByteCount: Int) -> SessionRestoreEntry {
        let text = String(repeating: "a", count: repeatedByteCount)
        return makeEntry(id: id, title: title, text: text, capturedAt: Date(timeIntervalSince1970: 10))
    }

    private func makeEntry(id: UUID, title: String, text: String, capturedAt: Date) -> SessionRestoreEntry {
        let bounded = SessionRestoreEntry.boundedScrollback(from: [
            RestoredTerminalLine(role: .stdout, text: text)
        ])
        return SessionRestoreEntry(
            id: id,
            title: title,
            kind: .localPTY,
            profileReference: .local,
            workingDirectory: "/tmp",
            launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
            scrollback: bounded.lines,
            scrollbackBytes: bounded.bytes,
            lastExitCode: nil,
            capturedAt: capturedAt
        )
    }

    private func makeRawEntry(
        id: UUID,
        title: String,
        lines: [RestoredTerminalLine],
        scrollbackBytes: Int,
        capturedAt: Date
    ) -> SessionRestoreEntry {
        SessionRestoreEntry(
            id: id,
            title: title,
            kind: .localPTY,
            profileReference: .local,
            workingDirectory: "/tmp",
            launch: .localShell(shellKind: "zsh", executable: "/bin/zsh", arguments: ["-l"]),
            scrollback: lines,
            scrollbackBytes: scrollbackBytes,
            lastExitCode: nil,
            capturedAt: capturedAt
        )
    }
}

private extension SessionRestoreEntry {
    func withProfileReference(_ reference: SessionRestoreProfileReference) -> SessionRestoreEntry {
        SessionRestoreEntry(
            id: id, title: title, kind: kind, profileReference: reference,
            workingDirectory: workingDirectory, launch: launch, scrollback: scrollback,
            scrollbackBytes: scrollbackBytes, lastExitCode: lastExitCode, capturedAt: capturedAt
        )
    }

    func withLaunch(_ launch: SessionRestoreLaunch) -> SessionRestoreEntry {
        SessionRestoreEntry(
            id: id, title: title, kind: kind, profileReference: profileReference,
            workingDirectory: workingDirectory, launch: launch, scrollback: scrollback,
            scrollbackBytes: scrollbackBytes, lastExitCode: lastExitCode, capturedAt: capturedAt
        )
    }
}
