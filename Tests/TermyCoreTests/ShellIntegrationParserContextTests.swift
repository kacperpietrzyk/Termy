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
