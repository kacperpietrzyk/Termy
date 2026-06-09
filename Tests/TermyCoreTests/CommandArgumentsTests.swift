import XCTest
@testable import TermyCore

final class CommandArgumentsTests: XCTestCase {

    // A small fixture catalog of arg-bearing actions, mirroring the real verbs.
    private let actions: [CommandAction] = [
        CommandAction(
            id: "connect-ssh", title: "Connect SSH", subtitle: "", area: .ssh, keywords: [],
            shortcut: nil, verb: "ssh",
            arguments: [CommandArgument(name: "destination", isRequired: false, completion: .none)]),
        CommandAction(
            id: "grep-scrollback", title: "Search Scrollback", subtitle: "", area: .terminal, keywords: [],
            shortcut: nil, verb: "grep",
            arguments: [CommandArgument(name: "pattern", isRequired: true, completion: .none)]),
        CommandAction(
            id: "cd-here", title: "Change Directory", subtitle: "", area: .terminal, keywords: [],
            shortcut: nil, verb: "cd",
            arguments: [CommandArgument(name: "path", isRequired: true, completion: .path)]),
        CommandAction(
            id: "git-branch", title: "Create Branch", subtitle: "", area: .git, keywords: [],
            shortcut: nil, verb: "branch",
            arguments: [CommandArgument(name: "name", isRequired: true, completion: .branch)]),
        CommandAction(
            id: "agent-prompt", title: "Prompt Agent", subtitle: "", area: .ai, keywords: [],
            shortcut: nil, verb: "agent-prompt",
            arguments: [CommandArgument(name: "text", isRequired: true, completion: .none)])
    ]

    // MARK: - activation rule

    func testBareVerbWithoutTrailingSpaceIsNotArgMode() {
        // "ssh" alone must keep finding the command via fuzzy search, NOT enter
        // arg mode (else the word "ssh" stops matching the action).
        XCTAssertNil(CommandArguments.parse("ssh", against: actions))
        XCTAssertNil(CommandArguments.parse("grep", against: actions))
    }

    func testVerbWithTrailingSpaceActivatesArgMode() {
        let parsed = CommandArguments.parse("ssh ", against: actions)
        XCTAssertEqual(parsed?.action.id, "connect-ssh")
        XCTAssertEqual(parsed?.rest, "")
    }

    func testVerbWithRestActivatesArgMode() {
        let parsed = CommandArguments.parse("ssh root@example.com", against: actions)
        XCTAssertEqual(parsed?.action.id, "connect-ssh")
        XCTAssertEqual(parsed?.rest, "root@example.com")
    }

    func testUnknownVerbIsNotArgMode() {
        XCTAssertNil(CommandArguments.parse("foobar baz", against: actions))
        XCTAssertNil(CommandArguments.parse("connect ssh", against: actions))
    }

    func testEmptyQueryIsNotArgMode() {
        XCTAssertNil(CommandArguments.parse("", against: actions))
        XCTAssertNil(CommandArguments.parse("   ", against: actions))
    }

    func testLeadingWhitespaceIsTolerated() {
        let parsed = CommandArguments.parse("  grep needle", against: actions)
        XCTAssertEqual(parsed?.action.id, "grep-scrollback")
        XCTAssertEqual(parsed?.rest, "needle")
    }

    func testVerbMatchIsCaseInsensitive() {
        let parsed = CommandArguments.parse("SSH host", against: actions)
        XCTAssertEqual(parsed?.action.id, "connect-ssh")
        XCTAssertEqual(parsed?.rest, "host")
    }

    // MARK: - rest preservation

    func testRestPreservesInternalWhitespaceAndArguments() {
        // agent-prompt takes free text — the rest must be kept verbatim, not split.
        let parsed = CommandArguments.parse("agent-prompt fix the   flaky test", against: actions)
        XCTAssertEqual(parsed?.action.id, "agent-prompt")
        XCTAssertEqual(parsed?.rest, "fix the   flaky test")
    }

    func testRestIsTrimmedOfEdgeWhitespace() {
        let parsed = CommandArguments.parse("ssh    host   ", against: actions)
        XCTAssertEqual(parsed?.rest, "host")
    }

    // MARK: - required / optional / default validation

    func testRequiredArgMissingIsIncomplete() {
        // grep needs a pattern; an empty rest must be flagged incomplete so the
        // UI can disable Enter rather than running an empty grep.
        let parsed = CommandArguments.parse("grep ", against: actions)
        XCTAssertNotNil(parsed)
        XCTAssertFalse(parsed!.isComplete)
        XCTAssertEqual(parsed!.firstRequiredMissing?.name, "pattern")
    }

    func testRequiredArgPresentIsComplete() {
        let parsed = CommandArguments.parse("grep needle", against: actions)
        XCTAssertTrue(parsed!.isComplete)
        XCTAssertNil(parsed!.firstRequiredMissing)
    }

    func testOptionalArgMissingIsStillComplete() {
        // connect-ssh's destination is optional (empty rest = seed the draft).
        let parsed = CommandArguments.parse("ssh ", against: actions)
        XCTAssertTrue(parsed!.isComplete)
    }

    func testDefaultValueFillsWhenRestEmpty() {
        let withDefault = [
            CommandAction(
                id: "cd-home", title: "Home", subtitle: "", area: .terminal, keywords: [],
                shortcut: nil, verb: "cd",
                arguments: [CommandArgument(name: "path", isRequired: false,
                                            defaultValue: "~", completion: .path)])
        ]
        let parsed = CommandArguments.parse("cd ", against: withDefault)
        XCTAssertTrue(parsed!.isComplete)
        XCTAssertEqual(parsed!.effectiveValue, "~")
    }

    func testEffectiveValueUsesRestWhenPresent() {
        let parsed = CommandArguments.parse("cd /tmp/work", against: actions)
        XCTAssertEqual(parsed!.effectiveValue, "/tmp/work")
    }

    // MARK: - completion kind exposure

    func testCompletionKindForPathArg() {
        let parsed = CommandArguments.parse("cd /usr/lo", against: actions)
        XCTAssertEqual(parsed!.completion, .path)
    }

    func testCompletionKindForBranchArg() {
        let parsed = CommandArguments.parse("branch feat", against: actions)
        XCTAssertEqual(parsed!.completion, .branch)
    }

    func testCompletionKindNoneForFreeText() {
        let parsed = CommandArguments.parse("grep TODO", against: actions)
        XCTAssertEqual(parsed!.completion, CommandArgument.Completion.none)
    }

    // MARK: - longest-verb wins (avoid prefix collision)

    func testLongerVerbWinsOverPrefixVerb() {
        // "agent-prompt" must not be shadowed by a hypothetical "agent" verb.
        let withCollision = actions + [
            CommandAction(
                id: "agent-generic", title: "Agent", subtitle: "", area: .ai, keywords: [],
                shortcut: nil, verb: "agent",
                arguments: [CommandArgument(name: "x", isRequired: false, completion: .none)])
        ]
        let parsed = CommandArguments.parse("agent-prompt do it", against: withCollision)
        XCTAssertEqual(parsed?.action.id, "agent-prompt")
        XCTAssertEqual(parsed?.rest, "do it")
    }

    // MARK: - actions without a verb never activate

    func testActionWithoutVerbNeverActivates() {
        let plain = [
            CommandAction(id: "toggle-git", title: "Toggle Git", subtitle: "", area: .git,
                          keywords: [], shortcut: nil)
        ]
        XCTAssertNil(CommandArguments.parse("toggle-git x", against: plain))
    }
}
