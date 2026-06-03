import XCTest
@testable import TermyCore

/// Slice-2c: the C marker carries `branch=`/`gitstatus=`/`node=` ahead of `cmd=`,
/// and the parser emits a `.commandContext` event right after `.commandStarted`.
/// Also locks the duplicate-key hardening (a command containing `;cmd=` must not
/// trap) and that the legacy cmd-only C marker is unchanged.
final class ShellIntegrationParserContextTests: XCTestCase {

    private func marker(_ payload: String) -> String { "\u{1B}]133;\(payload)\u{7}" }

    func testContextMarkerEmitsStartedThenContext() {
        var p = ShellIntegrationParser()
        let events = p.consume(marker("C;branch=main;gitstatus=*;node=v20.11.0;cmd=ls -la"))
        XCTAssertEqual(events, [
            .commandStarted("ls -la"),
            .commandContext(branch: "main", gitStatus: "*", node: "v20.11.0"),
        ])
    }

    func testLegacyCmdOnlyMarkerIsUnchanged() {
        var p = ShellIntegrationParser()
        let events = p.consume(marker("C;cmd=echo hi"))
        XCTAssertEqual(events, [.commandStarted("echo hi")],
                       "a C marker with no context fields must emit only .commandStarted")
    }

    func testEmptyContextFieldsEmitNoContextEvent() {
        var p = ShellIntegrationParser()
        // Not in a repo, no node → all fields empty.
        let events = p.consume(marker("C;branch=;gitstatus=;node=;cmd=pwd"))
        XCTAssertEqual(events, [.commandStarted("pwd")],
                       "all-empty context fields must NOT produce a .commandContext")
    }

    func testPartialContextOnlyBranch() {
        var p = ShellIntegrationParser()
        let events = p.consume(marker("C;branch=feature;gitstatus=;node=;cmd=git status"))
        XCTAssertEqual(events, [
            .commandStarted("git status"),
            .commandContext(branch: "feature", gitStatus: nil, node: nil),
        ])
    }

    func testDuplicateCmdKeyDoesNotTrapAndRealFieldsWin() {
        var p = ShellIntegrationParser()
        // The command literally contains ";cmd=foo" — preexec emits it as the LAST
        // field, producing a duplicate `cmd` key. First-wins must keep the real
        // earlier fields and NOT trap (uniqueKeysWithValues would have).
        let events = p.consume(marker("C;branch=main;gitstatus=*;node=v20;cmd=true;cmd=foo;branch=evil"))
        XCTAssertEqual(events, [
            .commandStarted("true"),
            .commandContext(branch: "main", gitStatus: "*", node: "v20"),
        ], "first-wins: real branch/cmd survive an injected duplicate")
    }

    /// Guards the silent-nil failure mode: if the script's printf key names ever
    /// drift from the keys the parser reads, the header field goes quietly nil.
    /// Feed the parser the EXACT marker the script emits (printf %s substituted).
    func testParserConsumesTheScriptsExactCMarker() {
        let script = ShellIntegrationScript.zsh()
        for key in ["branch=", "gitstatus=", "node=", "cmd="] {
            XCTAssertTrue(script.contains(key), "script C marker must emit \(key)")
        }
        // The literal payload the script's printf produces for a real command.
        var p = ShellIntegrationParser()
        let events = p.consume(marker("C;branch=main;gitstatus=*;node=v20.11.0;cmd=ls"))
        guard case .commandContext(let b, let g, let n)? = events.last else {
            return XCTFail("expected a .commandContext from the script's marker shape")
        }
        XCTAssertEqual([b, g, n], ["main", "*", "v20.11.0"],
                       "parser keys must match the script's printf keys")
    }

    // MARK: - Bug 1: precmd (D marker) carries LIVE prompt context

    /// The D marker (precmd, fired before EVERY prompt incl. the first) now also
    /// carries branch/gitstatus/node for the CURRENT $PWD, so the pinned input
    /// bar reflects the branch right after a `cd` — without waiting for a command.
    func testDMarkerCarriesPromptContext() {
        var p = ShellIntegrationParser()
        let events = p.consume(marker("D;exit=0;pwd=/repo;branch=main;gitstatus=*;node=v20.11.0"))
        XCTAssertEqual(events, [
            .commandFinished(exitCode: 0, workingDirectory: "/repo"),
            .promptContext(branch: "main", gitStatus: "*", node: "v20.11.0"),
        ])
    }

    /// `cd` into a non-repo emits the context KEYS but with empty values → a
    /// `.promptContext(nil,nil,nil)` that CLEARS the stale pinned-bar context
    /// (otherwise the previous repo's branch would linger).
    func testDMarkerWithEmptyContextClearsPromptContext() {
        var p = ShellIntegrationParser()
        let events = p.consume(marker("D;exit=0;pwd=/home/me;branch=;gitstatus=;node="))
        XCTAssertEqual(events, [
            .commandFinished(exitCode: 0, workingDirectory: "/home/me"),
            .promptContext(branch: nil, gitStatus: nil, node: nil),
        ])
    }

    /// A legacy D marker (exit+pwd only, no context keys) must stay exactly
    /// `.commandFinished` — no spurious promptContext.
    func testLegacyDMarkerEmitsOnlyCommandFinished() {
        var p = ShellIntegrationParser()
        let events = p.consume(marker("D;exit=3;pwd=/tmp"))
        XCTAssertEqual(events, [.commandFinished(exitCode: 3, workingDirectory: "/tmp")])
    }

    /// Bug 3 (Warp parity) + Bug 1: the generated script must gate the `node=`
    /// field on a node-flavored project (package.json walk-up) and emit the live
    /// prompt context on the precmd D marker. Behavioural verification needs a real
    /// zsh; this asserts the load-bearing script shape (the most a unit test can do).
    func testScriptGatesNodeOnProjectAndEmitsLivePromptContext() {
        let script = ShellIntegrationScript.zsh()
        XCTAssertTrue(script.contains("termy_probe_context"),
                      "shared context probe must exist")
        XCTAssertTrue(script.contains("package.json"),
                      "Bug 3: node must be gated on a package.json walk-up, not probed unconditionally")
        XCTAssertTrue(script.contains("D;exit=%d;pwd=%s;branch=%s;gitstatus=%s;node=%s"),
                      "Bug 1: precmd D marker must carry live branch/gitstatus/node")
        // The exact precmd-shaped D marker must parse to commandFinished + promptContext.
        var p = ShellIntegrationParser()
        let events = p.consume(marker("D;exit=0;pwd=/p/app;branch=main;gitstatus=;node=v20"))
        XCTAssertEqual(events, [
            .commandFinished(exitCode: 0, workingDirectory: "/p/app"),
            .promptContext(branch: "main", gitStatus: nil, node: "v20"),
        ])
    }

    func testContextMarkerSplitAcrossChunksReassembles() {
        var p = ShellIntegrationParser()
        let full = marker("C;branch=dev;gitstatus=*;node=v18;cmd=make")
        let mid = full.index(full.startIndex, offsetBy: full.count / 2)
        var events = p.consume(String(full[..<mid]))
        XCTAssertTrue(events.isEmpty, "incomplete marker is buffered, not leaked as output")
        events = p.consume(String(full[mid...]))
        XCTAssertEqual(events, [
            .commandStarted("make"),
            .commandContext(branch: "dev", gitStatus: "*", node: "v18"),
        ])
    }
}
