import XCTest
@testable import Termy
import TermyCore

/// CK-S7 store-level wiring for inline arguments. These exercise detection, the
/// feed short-circuit, and the locally-observable side effects (ad-hoc SSH
/// session creation, agent-prompt launch + pending seed). They never launch ssh
/// for real beyond constructing the session record, and never assert on network.
final class CKInlineArgumentsTests: XCTestCase {

    @MainActor
    func testCatalogVerbsArePresent() {
        let byVerb = Dictionary(
            grouping: FeatureCatalog.termDefault.commandCenterActions.compactMap { a -> (String, CommandAction)? in
                guard let v = a.verb else { return nil }
                return (v, a)
            },
            by: \.0)
        XCTAssertNotNil(byVerb["ssh"])
        XCTAssertNotNil(byVerb["grep"])
        XCTAssertNotNil(byVerb["cd"])
        XCTAssertNotNil(byVerb["branch"])
        XCTAssertNotNil(byVerb["agent-prompt"])
    }

    @MainActor
    func testBareVerbIsNotArgMode() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "ssh"
        XCTAssertNil(store.inlineArgCommand)
    }

    @MainActor
    func testVerbWithRestEntersArgMode() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "ssh root@example.com"
        XCTAssertEqual(store.inlineArgCommand?.action.id, "connect-ssh")
        XCTAssertEqual(store.inlineArgCommand?.rest, "root@example.com")
    }

    @MainActor
    func testArgModeShortCircuitsFeedToOneItem() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "grep TODO"
        let feed = store.rankedCommandCenterFeed
        XCTAssertEqual(feed.items.count, 1)
        XCTAssertEqual(feed.items.first?.id, "action-grep-scrollback")
    }

    @MainActor
    func testRequiredArgMissingIsIncompleteSoEnterIsNoOp() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "grep "
        let parsed = store.inlineArgCommand
        XCTAssertNotNil(parsed)
        XCTAssertFalse(parsed!.isComplete)
    }

    @MainActor
    func testCommandsScopePrefixStillEntersArgMode() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "> cd /tmp"
        XCTAssertEqual(store.inlineArgCommand?.action.id, "cd-directory")
        XCTAssertEqual(store.inlineArgCommand?.rest, "/tmp")
    }

    @MainActor
    func testSessionsScopePrefixDoesNotEnterArgMode() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "@ ssh host"
        XCTAssertNil(store.inlineArgCommand)
    }

    @MainActor
    func testAdHocSSHCreatesUnsavedSession() {
        let store = TermyStore(startInitialPTY: false)
        let beforeProfiles = store.profiles.count
        store.commandQuery = "ssh deploy@10.0.0.5"
        guard let parsed = store.inlineArgCommand else {
            return XCTFail("expected arg mode")
        }
        store.performInlineArgCommand(parsed)
        // A live SSH session is appended...
        let session = store.sessions.last
        XCTAssertEqual(session?.profile.kind, .ssh)
        XCTAssertEqual(session?.profile.host, "10.0.0.5")
        XCTAssertEqual(session?.profile.user, "deploy")
        // ...but the ad-hoc profile is NOT persisted to the saved list.
        XCTAssertEqual(store.profiles.count, beforeProfiles)
        // No secret inlined (P1).
        XCTAssertTrue(session?.profile.secretReferences.isEmpty ?? false)
    }

    @MainActor
    func testAgentPromptLaunchesClaudeSeeded() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "agent-prompt refactor the parser"
        guard let parsed = store.inlineArgCommand else {
            return XCTFail("expected arg mode")
        }
        store.performInlineArgCommand(parsed)
        XCTAssertEqual(store.sessions.last?.agentType, .claudeCode)
    }

    /// B4: the agent-prompt seed must reach the PTY input WITHOUT a trailing CR —
    /// it seeds the input line; the user presses Enter. A `\r` here would be the
    /// auto-execute B4 forbids. The seed is deferred until the sink registers.
    @MainActor
    func testAgentPromptSeedsWithoutSubmitting() {
        let store = TermyStore(startInitialPTY: false)
        store.commandQuery = "agent-prompt do the thing"
        guard let parsed = store.inlineArgCommand else {
            return XCTFail("expected arg mode")
        }
        store.performInlineArgCommand(parsed)
        guard let sessionID = store.sessions.last?.id else {
            return XCTFail("expected an agent session")
        }
        // Simulate the live terminal surface registering its input sink.
        var captured: [String] = []
        store.registerTerminalInputSink({ captured.append($0) }, for: sessionID)
        XCTAssertEqual(captured, ["do the thing"])
        XCTAssertFalse(captured.contains { $0.contains("\r") },
                       "seed must not carry a carriage return (no auto-execute)")
    }
}
