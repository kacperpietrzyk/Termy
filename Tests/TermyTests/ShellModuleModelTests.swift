import XCTest
@testable import Termy
import TermyCore

final class ShellModuleModelTests: XCTestCase {

    private func session(kind: ConnectionKind, name: String = "termy",
                         agentType: CLIAgent? = nil, cwd: String? = "~/dev",
                         started: Date = Date(),
                         user: String = "kacper", host: String = "localhost") -> TermySession {
        let profile: ConnectionProfile
        switch kind {
        case .local: profile = .local(name: name)
        case .ssh:   profile = .ssh(name: name, host: host, user: user, identity: .keychain("t"))
        case .rdp:   profile = .rdp(name: name, host: host, user: user, gateway: nil, credential: .keychain("t"))
        }
        var s = TermySession(title: name, profile: profile,
                             currentWorkingDirectory: cwd,
                             interactionMode: kind == .local ? .rawPTY : .commandLine,
                             agentType: agentType)
        s.startedAt = started
        return s
    }

    // MARK: partition
    func testPartitionSplitsLocalAndRemoteAndExcludesAgents() {
        let local = session(kind: .local, name: "shell")
        let agent = session(kind: .local, name: "claude", agentType: .claudeCode)
        let ssh   = session(kind: .ssh, name: "prod")
        let rdp   = session(kind: .rdp, name: "win")
        let (l, r) = ShellModuleModel.partition([local, agent, ssh, rdp])
        XCTAssertEqual(l.map(\.title), ["shell"])          // agent excluded
        XCTAssertEqual(Set(r.map(\.title)), ["prod", "win"]) // ssh + rdp both
    }

    func testPartitionOrdersByStartedAtOldestFirst() {
        let old = session(kind: .local, name: "old", started: Date(timeIntervalSince1970: 1))
        let new = session(kind: .local, name: "new", started: Date(timeIntervalSince1970: 2))
        let (l, _) = ShellModuleModel.partition([new, old])
        XCTAssertEqual(l.map(\.title), ["old", "new"])
    }

    // MARK: live-chip label
    func testLiveChipLabelLocalUsesVersionThenFallback() {
        // The probe yields a bare version ("5.9") → prefixed to "zsh 5.9".
        XCTAssertEqual(ShellModuleModel.liveChipLabel(kind: .local, zshVersion: "5.9"), "zsh 5.9")
        // Already-prefixed input is idempotent (no "zsh zsh 5.9").
        XCTAssertEqual(ShellModuleModel.liveChipLabel(kind: .local, zshVersion: "zsh 5.9"), "zsh 5.9")
        XCTAssertEqual(ShellModuleModel.liveChipLabel(kind: .local, zshVersion: nil), "zsh")
        XCTAssertEqual(ShellModuleModel.liveChipLabel(kind: .local, zshVersion: ""), "zsh")
    }
    func testLiveChipLabelRemote() {
        XCTAssertEqual(ShellModuleModel.liveChipLabel(kind: .ssh, zshVersion: nil), "ssh")
        XCTAssertEqual(ShellModuleModel.liveChipLabel(kind: .rdp, zshVersion: nil), "rdp")
    }

    // MARK: sub-rail count summary
    func testSessionCountSummaryShowsBothHalves() {
        XCTAssertEqual(ShellModuleModel.sessionCountSummary(local: 3, remote: 2), "3 local · 2 remote")
        XCTAssertEqual(ShellModuleModel.sessionCountSummary(local: 1, remote: 0), "1 local · 0 remote")
    }

    // MARK: AI-context endpoint display
    func testEndpointDisplayStripsScheme() {
        XCTAssertEqual(ShellModuleModel.endpointDisplay("http://localhost:11434"), "localhost:11434")
        XCTAssertEqual(ShellModuleModel.endpointDisplay("https://localhost:11434"), "localhost:11434")
        XCTAssertEqual(ShellModuleModel.endpointDisplay("localhost:11434"), "localhost:11434")
    }

    // MARK: dt-header subtitle
    func testHeaderSubtitleLocalComposesUserHostCwdStartedCommands() {
        let s = session(kind: .local, cwd: "~/dev", started: Date().addingTimeInterval(-120))
        let spans = ShellModuleModel.headerSubtitle(s, commandsToday: 7, localHostName: "rmbp")
        let joined = spans.map(\.text).joined()
        XCTAssertTrue(joined.contains("@rmbp"))          // local shows the machine name…
        XCTAssertFalse(joined.contains("@localhost"))    // …not the loopback identity
        XCTAssertTrue(joined.contains(":~/dev"))
        XCTAssertTrue(joined.contains("started "))
        XCTAssertFalse(joined.contains(" ago"))          // absolute clock, not relative age
        XCTAssertTrue(joined.contains("7 commands today"))
    }
    func testHeaderSubtitleOmitsCwdWhenNil() {
        let s = session(kind: .ssh, cwd: nil)
        let spans = ShellModuleModel.headerSubtitle(s, commandsToday: 0)
        XCTAssertFalse(spans.contains { $0.text == ":" && $0.accent == .dim }, "no cwd separator span when cwd is nil")
        let joined = spans.map(\.text).joined()
        XCTAssertTrue(joined.contains("0 commands today"))
    }
    func testHeaderSubtitleSingularCommand() {
        let s = session(kind: .local)
        let joined = ShellModuleModel.headerSubtitle(s, commandsToday: 1).map(\.text).joined()
        XCTAssertTrue(joined.contains("1 command today"))
        XCTAssertFalse(joined.contains("1 commands today"))
    }

    // MARK: sub-card meta
    func testSubCardMetaLocalShowsCwdAndCount() {
        let s = session(kind: .local, cwd: "~/dev")
        XCTAssertEqual(ShellModuleModel.subCardMeta(s, blockCount: 12), "~/dev · 12 cmds")
    }
    func testSubCardMetaRemoteShowsUserHost() {
        let s = session(kind: .rdp, user: "kacper", host: "win.acme")
        XCTAssertEqual(ShellModuleModel.subCardMeta(s, blockCount: 0), "kacper@win.acme")
    }
    func testSubCardStatusTextLocalIsAgeRemoteNil() {
        let local = session(kind: .local, started: Date().addingTimeInterval(-120))
        XCTAssertEqual(ShellModuleModel.subCardStatusText(local), "2m")
        XCTAssertNil(ShellModuleModel.subCardStatusText(session(kind: .ssh)))
    }

    // MARK: real-source display helpers
    func testAbbreviateTilde() {
        XCTAssertEqual(ShellModuleModel.abbreviateTilde("/Users/kacper", home: "/Users/kacper"), "~")
        XCTAssertEqual(ShellModuleModel.abbreviateTilde("/Users/kacper/code/termy", home: "/Users/kacper"), "~/code/termy")
        XCTAssertEqual(ShellModuleModel.abbreviateTilde("/opt/x", home: "/Users/kacper"), "/opt/x")
    }
    func testClockTimeIsAbsolute24h() {
        var c = DateComponents(); c.year = 2026; c.month = 5; c.day = 26; c.hour = 13; c.minute = 50
        let d = Calendar.current.date(from: c)!
        XCTAssertEqual(ShellModuleModel.clockTime(d), "13:50")
    }

    // MARK: last-explain summary
    func testLastExplainSummaryNilWhenNoRecord() {
        XCTAssertNil(ShellModuleModel.lastExplainSummary(nil))
    }
    func testLastExplainSummaryFull() {
        let r = TerminalExplainRecord(blockOrdinal: 3, blockStartLine: 0, command: "keychain test",
                                      durationSeconds: 0.92, finishedAt: Date(), succeeded: true)
        XCTAssertEqual(ShellModuleModel.lastExplainSummary(r), "block 3 · keychain test · 0.92s")
    }
    func testLastExplainSummaryOmitsNilOrdinalAndEmptyCommand() {
        let r = TerminalExplainRecord(blockOrdinal: nil, blockStartLine: 0, command: "",
                                      durationSeconds: 1.5, finishedAt: Date(), succeeded: false)
        XCTAssertEqual(ShellModuleModel.lastExplainSummary(r), "1.50s")
    }

    // MARK: sidecar summary
    func testSidecarSummaryDisabled() {
        XCTAssertEqual(ShellModuleModel.sidecarSummary(disabled: true, crashCount: 2), "disabled")
    }
    func testSidecarSummaryHealthyPluralizes() {
        XCTAssertEqual(ShellModuleModel.sidecarSummary(disabled: false, crashCount: 0), "healthy · 0 crashes / 60s")
        XCTAssertEqual(ShellModuleModel.sidecarSummary(disabled: false, crashCount: 1), "healthy · 1 crash / 60s")
    }

    // MARK: block duration formatter
    func testFormatBlockDuration() {
        XCTAssertEqual(ShellModuleModel.formatBlockDuration(0.008), "8ms")
        XCTAssertEqual(ShellModuleModel.formatBlockDuration(0.092), "92ms")
        XCTAssertEqual(ShellModuleModel.formatBlockDuration(0.9994), "999ms")
        XCTAssertEqual(ShellModuleModel.formatBlockDuration(4.2), "4.2s")
        XCTAssertEqual(ShellModuleModel.formatBlockDuration(63), "1m 3s")
        XCTAssertEqual(ShellModuleModel.formatBlockDuration(0), "0ms")
    }
}
