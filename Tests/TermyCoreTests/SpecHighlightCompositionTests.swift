import XCTest
@testable import TermyCore

/// Task-5 integration tests for the command-spec highlighter:
///   - Composition: both `main` and `termy_spec` layers fire; `termy_spec` must NOT emit
///     for option-argument ("hello") or argument (/tmp) cells (Gate-3 contract).
///   - Perf: steady-state < 5 ms/call.
///   - Real-zsh smoke: highlighter sources cleanly and F-1's termy_buffer_publish hook survives.
///
/// Setup: TERMY_SPEC_DIR = vendor/specs/out (spec data); highlighter sourced from
/// script/shell/termy-spec-highlighter.zsh (only reads spec data from TERMY_SPEC_DIR,
/// so pointing TERMY_SPEC_DIR at vendor/specs/out is sufficient).
final class SpecHighlightCompositionTests: XCTestCase {

    var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - Composition test

    /// Drives `_zsh_highlight` on `git commit -m "hello" --amend /tmp` and asserts:
    ///   1. `main` layer emits a colour entry for `"hello"` at offsets [14,21) (string literal).
    ///   2. `main` layer emits an underline entry for `/tmp` at offsets [30,34) (path).
    ///   3. `termy_spec` layer emits entries for `git` (command), `commit` (subcommand),
    ///      `-m` (option), and `--amend` (option).
    ///   4. `termy_spec` layer emits NO entry covering the `"hello"` cell [14,21).
    ///   5. `termy_spec` layer emits NO entry covering the `/tmp` cell [30,34).
    ///
    /// Facts 4 and 5 are the Gate-3 production proof: the paint hook skips option-argument
    /// and argument roles, so `main`'s string/path styling is never clobbered.
    func testComposedRegionHighlightBothLayersAndNoSpecOnArgumentCells() throws {
        guard FileManager.default.fileExists(atPath: "/bin/zsh") else {
            throw XCTSkip("zsh not available")
        }

        let specDir  = root.appendingPathComponent("vendor/specs/out").path
        let zshlDir  = root.appendingPathComponent("vendor/zsh-syntax-highlighting/highlighters").path
        let zshlZsh  = root.appendingPathComponent("vendor/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh").path
        let hlZsh    = root.appendingPathComponent("script/shell/termy-spec-highlighter.zsh").path

        // Headless probe: source z-s-h + highlighter, run _zsh_highlight, dump entries as
        // parseable lines. We use a heredoc script run under `zsh -c` so we have full zsh
        // with autoload/zle but no interactive tty required.
        //
        // Input: git commit -m "hello" --amend /tmp
        // Offsets (0-based half-open):
        //   git      [0,3)   → command
        //   commit   [4,10)  → subcommand
        //   -m       [11,13) → option
        //   "hello"  [14,21) → option-argument  (main: fg=yellow; termy_spec: SKIP)
        //   --amend  [22,29) → option
        //   /tmp     [30,34) → argument          (main: underline; termy_spec: SKIP)
        let probeScript = """
        export TERMY_SPEC_DIR='\(specDir)'
        ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR='\(zshlDir)'
        source '\(zshlZsh)'
        typeset -gA TERMY_SPEC_STYLES
        TERMY_SPEC_STYLES[command]='fg=#30D158'
        TERMY_SPEC_STYLES[subcommand]='fg=#5AC8FA'
        TERMY_SPEC_STYLES[option]='fg=#98989D'
        TERMY_SPEC_STYLES[error]='fg=#FF453A'
        source '\(hlZsh)'
        ZSH_HIGHLIGHT_HIGHLIGHTERS=(main termy_spec)
        BUFFER='git commit -m "hello" --amend /tmp'
        CURSOR=${#BUFFER}
        PENDING=0
        KEYS_QUEUED_COUNT=0
        region_highlight=("0 0 fg=default, memo=zsh-syntax-highlighting")
        typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER=
        _zsh_highlight
        for e in "${region_highlight[@]}"; do
          print "ENTRY:${e}"
        done
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", probeScript]
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        proc.environment = env
        let outPipe = Pipe(); proc.standardOutput = outPipe
        let errPipe = Pipe(); proc.standardError = errPipe
        try proc.run(); proc.waitUntilExit()

        let rawOut  = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let rawErr  = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        XCTAssertEqual(proc.terminationStatus, 0, "probe must exit 0; stderr: \(rawErr)")

        // Parse entries into (start, end, style) tuples.
        // Format: "ENTRY:<start> <end> <style> [, memo=...]"
        struct Entry { let start: Int; let end: Int; let style: String }
        var entries: [Entry] = []
        for line in rawOut.components(separatedBy: "\n") {
            guard line.hasPrefix("ENTRY:") else { continue }
            let body = String(line.dropFirst("ENTRY:".count))
            // Split on spaces; first two tokens are start/end.
            let parts = body.components(separatedBy: " ")
            guard parts.count >= 3,
                  let s = Int(parts[0]),
                  let e = Int(parts[1]) else { continue }
            let style = parts.dropFirst(2).joined(separator: " ")
            entries.append(Entry(start: s, end: e, style: style))
        }

        XCTAssertFalse(entries.isEmpty, "region_highlight must not be empty; raw: \(rawOut)")

        // Convenience predicates.
        let mainEntries    = entries.filter { $0.style.hasPrefix("none")
                                           || $0.style.hasPrefix("fg=")
                                           || $0.style.hasPrefix("underline")
                                           || $0.style.hasPrefix("bold") }
        let specEntries    = entries.filter { $0.style.contains("fg=#") }

        // ---- Fact 1: main emits a colour entry for "hello" at [14,21) ----
        let mainOnHello = mainEntries.filter {
            $0.start == 14 && $0.end == 21 && $0.style.contains("yellow")
        }
        XCTAssertFalse(mainOnHello.isEmpty,
                       "main must emit fg=yellow for \"hello\" at [14,21); entries: \(entries.map { "\($0.start)-\($0.end) \($0.style)" })")

        // ---- Fact 2: main emits underline for /tmp at [30,34) ----
        let mainOnTmp = mainEntries.filter {
            $0.start == 30 && $0.end == 34 && $0.style.contains("underline")
        }
        XCTAssertFalse(mainOnTmp.isEmpty,
                       "main must emit underline for /tmp at [30,34); entries: \(entries.map { "\($0.start)-\($0.end) \($0.style)" })")

        // ---- Fact 3: termy_spec emits entries for git/commit/-m/--amend ----
        let specCommand    = specEntries.filter { $0.start == 0  && $0.end == 3  }
        let specSubcommand = specEntries.filter { $0.start == 4  && $0.end == 10 }
        let specOptionM    = specEntries.filter { $0.start == 11 && $0.end == 13 }
        let specOptionAm   = specEntries.filter { $0.start == 22 && $0.end == 29 }
        XCTAssertFalse(specCommand.isEmpty,    "termy_spec must colour command git [0,3)")
        XCTAssertFalse(specSubcommand.isEmpty, "termy_spec must colour subcommand commit [4,10)")
        XCTAssertFalse(specOptionM.isEmpty,    "termy_spec must colour option -m [11,13)")
        XCTAssertFalse(specOptionAm.isEmpty,   "termy_spec must colour option --amend [22,29)")

        // ---- Fact 4: termy_spec must NOT emit any entry covering "hello" [14,21) ----
        // (option-argument role is skipped in the paint hook — Gate-3 contract)
        let specOnHello = specEntries.filter { $0.start == 14 && $0.end == 21 }
        XCTAssertTrue(specOnHello.isEmpty,
                      "termy_spec MUST NOT emit for \"hello\" option-argument [14,21); entries: \(specEntries.map { "\($0.start)-\($0.end) \($0.style)" })")

        // ---- Fact 5: termy_spec must NOT emit any entry covering /tmp [30,34) ----
        // (argument role is skipped in the paint hook — Gate-3 contract)
        let specOnTmp = specEntries.filter { $0.start == 30 && $0.end == 34 }
        XCTAssertTrue(specOnTmp.isEmpty,
                      "termy_spec MUST NOT emit for /tmp argument [30,34); entries: \(specEntries.map { "\($0.start)-\($0.end) \($0.style)" })")
    }

    // MARK: - Perf regression test

    /// Measures steady-state `termy_spec_classify` calls on a realistic line.
    /// Gate: < 5 ms/call (spike measured ~0.16 ms after the subshell-free rewrite).
    func testClassifyPerfSteadyStateUnder5ms() throws {
        guard FileManager.default.fileExists(atPath: "/bin/zsh") else {
            throw XCTSkip("zsh not available")
        }

        let specDir = root.appendingPathComponent("vendor/specs/out").path
        let hlZsh   = root.appendingPathComponent("script/shell/termy-spec-highlighter.zsh").path

        // N=1000 steady-state calls. We use zsh/datetime EPOCHREALTIME for sub-ms resolution.
        let perfScript = """
        zmodload zsh/datetime
        export TERMY_SPEC_DIR='\(specDir)'
        source '\(hlZsh)'
        local N=1000
        local LINE='git commit -m "hello" --amend /tmp'
        # Warm up (loads spec into _TS_LOADED cache).
        termy_spec_classify "$LINE"
        # Steady-state timing.
        local t0=$EPOCHREALTIME
        for (( i = 0; i < N; i++ )); do
          termy_spec_classify "$LINE"
        done
        local t1=$EPOCHREALTIME
        local ms_total=$(( (t1 - t0) * 1000 ))
        local ms_per=$(( ms_total / N ))
        printf "MS_PER_CALL:%.6f\\n" "$ms_per"
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", perfScript]
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        proc.environment = env
        let outPipe = Pipe(); proc.standardOutput = outPipe
        let errPipe = Pipe(); proc.standardError = errPipe
        try proc.run(); proc.waitUntilExit()

        let rawOut = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let rawErr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(proc.terminationStatus, 0, "perf probe must exit 0; stderr: \(rawErr)")

        // Parse "MS_PER_CALL:<value>" from output.
        var msPerCall: Double = 0
        for line in rawOut.components(separatedBy: "\n") {
            if line.hasPrefix("MS_PER_CALL:"), let val = Double(line.dropFirst("MS_PER_CALL:".count)) {
                msPerCall = val
                break
            }
        }
        XCTAssertGreaterThan(msPerCall, 0, "must extract timing; raw: \(rawOut)")
        XCTAssertLessThan(msPerCall, 5.0,
                          "steady-state classify must be < 5 ms/call; got \(String(format: "%.4f", msPerCall)) ms/call")
    }

    // MARK: - Real-zsh smoke test

    /// Launches `/bin/zsh -i` with the generated .zshrc (including both the z-s-h layer
    /// and the spec highlighter layer), then probes that:
    ///   - The z-s-h version variable is set (highlighter sourced OK).
    ///   - F-1's `termy_buffer_publish` hook is still defined (composition does not clobber it).
    ///   - The spec highlighter functions are defined after startup:
    ///       `_zsh_highlight_highlighter_termy_spec_paint`,
    ///       `_zsh_highlight_highlighter_termy_spec_predicate`,
    ///       `termy_spec_classify`.
    ///     Note: spec data (e.g. TS_GIT_SUB) is lazy-loaded only when classify is called;
    ///     the presence of the three functions proves the highlighter was sourced.
    ///   - Shell exits cleanly (fail-open contract: missing or extra resources never block start).
    ///
    /// The generated .zshrc sources `$TERMY_SPEC_DIR/termy-spec-highlighter.zsh`. At runtime
    /// the app bundles specs + highlighter together into Resources/specs/. For this test we
    /// construct a tempdir that mirrors the runtime layout: copy all vendor/specs/out/*.zsh files
    /// plus script/shell/termy-spec-highlighter.zsh into one directory and point TERMY_SPEC_DIR
    /// there (matching what TermyStore does at launch).
    func testRealZshSourcesSpecHighlighterAndKeepsBufferPublishHook() throws {
        guard FileManager.default.fileExists(atPath: "/bin/zsh") else {
            throw XCTSkip("zsh not available")
        }

        // --- Build a runtime-layout temp dir (specs + highlighter co-located) ---
        let specsRuntime = FileManager.default.temporaryDirectory
            .appendingPathComponent("spec-hl-runtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: specsRuntime, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: specsRuntime) }

        // Copy all spec_*.zsh files from vendor/specs/out/.
        let specsOutDir = root.appendingPathComponent("vendor/specs/out")
        let specFiles = try FileManager.default.contentsOfDirectory(
            at: specsOutDir, includingPropertiesForKeys: nil)
        for file in specFiles where file.pathExtension == "zsh" {
            let dst = specsRuntime.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.copyItem(at: file, to: dst)
        }

        // Copy the highlighter (at runtime it ships alongside the spec files).
        let hlSrc = root.appendingPathComponent("script/shell/termy-spec-highlighter.zsh")
        let hlDst = specsRuntime.appendingPathComponent("termy-spec-highlighter.zsh")
        try FileManager.default.copyItem(at: hlSrc, to: hlDst)

        let zdotdir = FileManager.default.temporaryDirectory
            .appendingPathComponent("spec-hl-zd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: zdotdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: zdotdir) }

        let palette = SpecHighlightPalette.default
        // Build a full .zshrc that sources both layers.
        let rc = ShellIntegrationScript.zsh(
                    highlightStyles: [],
                    specStylesBlock: palette.zshStylesBlock())
            + "\nprint -r -- \"HL_VER=$ZSH_HIGHLIGHT_VERSION\""
            + "\nprint -r -- \"HL_PUBLISH=${+functions[termy_buffer_publish]}\""
            + "\nprint -r -- \"HL_PAINT=${+functions[_zsh_highlight_highlighter_termy_spec_paint]}\""
            + "\nprint -r -- \"HL_PRED=${+functions[_zsh_highlight_highlighter_termy_spec_predicate]}\""
            + "\nprint -r -- \"HL_CLASSIFY=${+functions[termy_spec_classify]}\""
            + "\nexit\n"
        try rc.write(to: zdotdir.appendingPathComponent(".zshrc"),
                     atomically: true, encoding: .utf8)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-i"]
        var env = ProcessInfo.processInfo.environment
        env["ZDOTDIR"]              = zdotdir.path
        env["TERM"]                 = "xterm-256color"
        env["TERMY_SYNTAX_HL_DIR"]  = root.appendingPathComponent("vendor/zsh-syntax-highlighting").path
        // TERMY_SPEC_DIR points to the runtime-layout tempdir (highlighter + specs co-located).
        env["TERMY_SPEC_DIR"]       = specsRuntime.path
        proc.environment = env
        let outPipe = Pipe(); proc.standardOutput = outPipe
        let errPipe = Pipe(); proc.standardError = errPipe
        try proc.run(); proc.waitUntilExit()

        let s = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        XCTAssertTrue(s.contains("HL_VER=0.8.0"),
                      "z-s-h must source under the generated .zshrc; got: \(s)")
        XCTAssertTrue(s.contains("HL_PUBLISH=1"),
                      "F-1 termy_buffer_publish must still be defined after spec highlighter loads")
        XCTAssertTrue(s.contains("HL_PAINT=1"),
                      "termy_spec paint function must be defined (spec highlighter sourced); got: \(s)")
        XCTAssertTrue(s.contains("HL_PRED=1"),
                      "termy_spec predicate function must be defined; got: \(s)")
        XCTAssertTrue(s.contains("HL_CLASSIFY=1"),
                      "termy_spec_classify function must be defined; got: \(s)")
        XCTAssertEqual(proc.terminationStatus, 0,
                       "shell must start cleanly (fail-open contract)")
    }
}
