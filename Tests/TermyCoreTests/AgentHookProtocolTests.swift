import XCTest
@testable import TermyCore

final class AgentHookProtocolTests: XCTestCase {
    func testKeywordRoundTrip() {
        XCTAssertEqual(AgentHookProtocol.signal(forKeyword: "working"), .active)
        XCTAssertEqual(AgentHookProtocol.signal(forKeyword: "waiting"), .waiting)
        XCTAssertNil(AgentHookProtocol.signal(forKeyword: "bogus"))
    }

    func testNilHelperYieldsNoArguments() {
        let args = AgentHookProtocol.claudeCodeLaunchArguments(
            helperPath: nil, stateDir: "/tmp/state", sessionID: UUID())
        XCTAssertTrue(args.isEmpty)
    }

    func testLaunchArgumentsAreValidSettingsJSON() throws {
        let id = UUID()
        let args = AgentHookProtocol.claudeCodeLaunchArguments(
            helperPath: "/Apps/Termy.app/Contents/Resources/termy-agent-hook.sh",
            stateDir: "/Users/me/Library/Application Support/Termy/agent-state",
            sessionID: id)
        XCTAssertEqual(args.count, 2)
        XCTAssertEqual(args[0], "--settings")

        // The payload must be valid JSON with hooks for the three events.
        let data = try XCTUnwrap(args[1].data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = try XCTUnwrap(obj?["hooks"] as? [String: Any])
        XCTAssertNotNil(hooks["SessionStart"])
        XCTAssertNotNil(hooks["Stop"])
        XCTAssertNotNil(hooks["Notification"])

        // The Stop command must invoke the helper with the session id, the
        // (space-containing) state dir, and the "waiting" keyword — shell-quoted.
        let stop = try XCTUnwrap((hooks["Stop"] as? [[String: Any]])?.first)
        let stopHook = try XCTUnwrap((stop["hooks"] as? [[String: Any]])?.first)
        // Claude Code requires the hook entry's `type` to be "command".
        XCTAssertEqual(stopHook["type"] as? String, "command")
        let cmd = try XCTUnwrap(stopHook["command"] as? String)
        XCTAssertTrue(cmd.contains(id.uuidString))
        XCTAssertTrue(cmd.contains("'/Users/me/Library/Application Support/Termy/agent-state'"))
        XCTAssertTrue(cmd.hasSuffix(" waiting"))
        XCTAssertTrue(cmd.hasPrefix("'/Apps/Termy.app/Contents/Resources/termy-agent-hook.sh'"))
    }

    func testSettingsIncludePostToolUseMatcher() throws {
        let args = AgentHookProtocol.claudeCodeLaunchArguments(
            helperPath: "/Apps/Termy.app/Contents/Resources/termy-agent-hook.sh",
            stateDir: "/Users/me/Library/Application Support/Termy/agent-state",
            sessionID: UUID())
        let data = try XCTUnwrap(args[1].data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hooks = try XCTUnwrap(obj?["hooks"] as? [String: Any])

        // The three FB-3-2 events are unchanged and carry no matcher.
        let stop = try XCTUnwrap((hooks["Stop"] as? [[String: Any]])?.first)
        XCTAssertNil(stop["matcher"])

        // FB-3-5 adds a PostToolUse entry scoped to the five tools, command "tool".
        let post = try XCTUnwrap((hooks["PostToolUse"] as? [[String: Any]])?.first)
        XCTAssertEqual(post["matcher"] as? String, "TaskCreate|TaskUpdate|Edit|Write|MultiEdit")
        let hook = try XCTUnwrap((post["hooks"] as? [[String: Any]])?.first)
        XCTAssertEqual(hook["type"] as? String, "command")
        XCTAssertTrue(try XCTUnwrap(hook["command"] as? String).hasSuffix(" tool"))
    }
}
