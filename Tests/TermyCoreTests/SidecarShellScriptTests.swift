import XCTest
import Foundation
@testable import TermyCore

final class SidecarShellScriptTests: XCTestCase {
    func test_template_isNonEmpty() {
        XCTAssertFalse(SidecarShellScript.template.isEmpty)
        XCTAssertGreaterThan(SidecarShellScript.template.count, 500,
                             "Script should be substantial — bootstrap + shadow + widget + boot frame")
    }

    func test_template_containsFunctionShadow_notAlias() {
        // Advisor-flagged: aliases don't intercept builtins called from compsys.
        XCTAssertTrue(SidecarShellScript.template.contains("function compadd"))
        XCTAssertFalse(SidecarShellScript.template.contains("alias compadd"))
    }

    func test_template_invokesMainCompleteInsideWidget() {
        XCTAssertTrue(SidecarShellScript.template.contains("_main_complete"))
    }

    func test_template_widgetIsCompletionKind_notGeneric() {
        // Spike finding #1: zle -C, NOT zle -N. With -N, _main_complete sees no compstate.
        XCTAssertTrue(SidecarShellScript.template.contains("zle -C _termy_capture"))
        XCTAssertFalse(SidecarShellScript.template.contains("zle -N _termy_capture"))
    }

    func test_template_bindsTriggerKey() {
        XCTAssertTrue(SidecarShellScript.template.contains("bindkey"))
        XCTAssertTrue(SidecarShellScript.template.contains("_termy_capture"))
    }

    func test_template_definesDefensiveCompinit() {
        // Spike finding #5: user .zshrc may defer compinit via plugin manager.
        XCTAssertTrue(SidecarShellScript.template.contains("compinit"))
        XCTAssertTrue(SidecarShellScript.template.contains("_comps"))
    }

    func test_template_emitsResultViaAtomicTempRename() {
        // Post-spike protocol: write to .tmp then mv -f to final (atomic publish).
        XCTAssertTrue(SidecarShellScript.template.contains(".tsv.tmp"))
        XCTAssertTrue(SidecarShellScript.template.contains("mv -f"))
        XCTAssertTrue(SidecarShellScript.template.contains("TERMY_SIDECAR_DIR"))
    }

    func test_template_doesNotPrintOSCFrames() {
        // Spike finding #2: widget print goes to terminal display, not parent reader.
        // The post-spike protocol does NOT use OSC 133 M.
        XCTAssertFalse(SidecarShellScript.template.contains("\\e]133;M"))
        XCTAssertFalse(SidecarShellScript.template.contains("OSC 133"))
    }

    func test_template_emitsBootFlag() {
        // Boot handshake = empty __boot__.flag file (post-spike).
        XCTAssertTrue(SidecarShellScript.template.contains("__boot__.flag"))
    }

    func test_template_capsCandidatesAt100() {
        // Spec §7.8: cap at 100. The slice is 0-based in zsh — :0:100 takes
        // the first 100; :1:100 silently drops the highest-ranked candidate.
        XCTAssertTrue(SidecarShellScript.template.contains(":0:100"))
        XCTAssertFalse(SidecarShellScript.template.contains(":1:100"))
    }

    func test_template_compaddWalker_consumesFlagsWithArguments() {
        // zsh 5.9 zshcompwid(1): these compadd options consume a following
        // value and those values must never leak as phantom candidates.
        for flag in ["-P", "-S", "-p", "-s", "-i", "-I", "-W", "-d", "-J", "-X",
                     "-x", "-V", "-r", "-R", "-F", "-M", "-O", "-A", "-D", "-E"] {
            XCTAssertTrue(
                SidecarShellScript.template.contains(flag),
                "compadd argv walker must account for \(flag)'s value argument"
            )
        }
        XCTAssertTrue(
            SidecarShellScript.template.contains("__t_order_values"),
            "compadd -o's optional order value must be handled explicitly"
        )
    }

    func test_template_compaddCaptureUsesZshMatchedSubset() {
        // The shadow sees raw compadd argv before builtin matching. It must ask
        // zsh which completions actually match PREFIX so "git p" does not show
        // every git subcommand.
        XCTAssertTrue(SidecarShellScript.template.contains("builtin compadd -O __t_matched"))
        XCTAssertTrue(SidecarShellScript.template.contains("__t_should_capture=0"))
    }

    func test_compaddShadow_preservesPerCandidateDescriptionsForGitDescribeShape() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-sidecar-shadow-\(UUID().uuidString)")
        let workDir = root.appendingPathComponent("work")
        let zdotdir = root.appendingPathComponent("zdot")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: zdotdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bootstrap = root.appendingPathComponent("bootstrap.zsh")
        try SidecarShellScript.template.write(to: bootstrap, atomically: true, encoding: .utf8)

        let driver = root.appendingPathComponent("driver.zsh")
        try """
        export TERMY_SIDECAR_DIR='\(workDir.path)'
        source '\(bootstrap.path)'

        function builtin {
          if [[ "$1" == "compadd" ]]; then
            shift
            if [[ "$1" == "-O" ]]; then
              local __out="$2"
              eval "$__out=(pull push)"
            fi
            return 0
          fi
          command builtin "$@"
        }

        _tmpm=(pull push)
        _tmpd=(
          'pull  -- fetch from and merge with another repository or a local branch'
          'push  -- update remote refs along with associated objects'
        )
        curtag=common-commands
        compadd -J -default- -ld _tmpd -a _tmpm
        printf '%s\\n' "${__termy_captured[@]}"
        """.write(to: driver, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-i", driver.path]
        process.environment = [
            "ZDOTDIR": zdotdir.path,
            "TERMY_SIDECAR": "1",
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
            "HOME": NSHomeDirectory(),
            "PROMPT": "",
            "RPROMPT": ""
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        XCTAssertEqual(process.terminationStatus, 0, err)
        XCTAssertTrue(out.contains("common-commands\tpull\tpull\tfetch from"), out)
        XCTAssertTrue(out.contains("common-commands\tpush\tpush\tupdate remote refs"), out)
    }

    func test_template_disablesAutosuggestionsDefensively() {
        // Spec §4.9: defensive guard against user's zsh-autosuggestions plugin.
        XCTAssertTrue(SidecarShellScript.template.contains("_zsh_autosuggest_disable"))
    }

    func test_template_definesCdHelper() {
        // __termy_cd op-code (separate from completion).
        XCTAssertTrue(SidecarShellScript.template.contains("_termy_cd"))
    }

    func test_template_setsErrHandlingOptions() {
        // Errors in user completion functions must not kill the sidecar.
        XCTAssertTrue(SidecarShellScript.template.contains("NO_ERR_RETURN"))
        XCTAssertTrue(SidecarShellScript.template.contains("NO_ERR_EXIT"))
    }
}
