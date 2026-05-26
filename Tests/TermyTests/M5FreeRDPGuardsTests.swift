import XCTest

/// M5 structural guards: the bespoke RDP engine is deleted, CTermyRDP never
/// leaks outside TermyRDP, and the FreeRDP build script is pinned and executable.
final class M5FreeRDPGuardsTests: XCTestCase {

    // MARK: - Repo-root resolution (mirrors M4SparkleGuardsTests)

    private var repoRoot: URL {
        // Tests run from the package dir; walk up to the repo root
        // (the dir containing Package.swift).
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path),
              url.path != "/" {
            url.deleteLastPathComponent()
        }
        return url
    }

    // MARK: - Comment-stripping helper
    //
    // Used by both the removal guard and the public-header lint so both share
    // the same idiom (advisor recommendation: one helper, not two).
    //
    // Implementation:
    //   Pass 1 — remove block comments `/* … */` (handles inline blocks such
    //             as `int32_t x; /* raw freerdp_get_last_error() value */` and
    //             multi-line header banners like the top-of-file doc block in
    //             ctermyrdp.h). Uses non-greedy dotMatchesLineSeparators.
    //   Pass 2 — per-line strip from `//` to end of line.
    //
    // Caveats: `/\*` or `//` inside a string literal would be mishandled, but
    // that doesn't arise for symbol-name detection in our sources.

    private func stripComments(from source: String) -> String {
        // Pass 1: block comments
        let blockPattern = try! NSRegularExpression(pattern: #"/\*.*?\*/"#,
                                                     options: .dotMatchesLineSeparators)
        let range = NSRange(source.startIndex..., in: source)
        let afterBlock = blockPattern.stringByReplacingMatches(in: source, range: range,
                                                               withTemplate: " ")
        // Pass 2: line comments
        let lines = afterBlock.components(separatedBy: "\n").map { line -> String in
            if let commentRange = line.range(of: "//") {
                return String(line[line.startIndex ..< commentRange.lowerBound])
            }
            return line
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Test 1: RDPByteTransport.swift must not exist

    func testRDPByteTransportFileDeleted() {
        let path = repoRoot
            .appendingPathComponent("Sources/TermyRDP/RDPByteTransport.swift")
            .path
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: path),
            "Sources/TermyRDP/RDPByteTransport.swift must be deleted in M5 (bespoke transport removed)"
        )
    }

    // MARK: - Test 2: No bespoke RDP symbols remain in any Sources Swift file
    //
    // Symbols searched: see the `forbidden` array below for the canonical list.
    // Matching is substring (no word boundary) so that e.g.
    // `RDPCredSSPNTLMv2CredentialResolver` is caught by the `RDPCredSSP` token.
    //
    // RDPSessionModel.swift is included (carve-out removed — the file is clean).
    //
    // Non-vacuity proof: if a live reference to any listed symbol existed in
    // any Swift file (e.g. `var resolver: RDPCredSSP`), stripComments would
    // leave it and the XCTAssertFalse would fire.  A comment reference
    // (// Migrated from RDPCredSSP) is stripped before the regex, so it passes.

    func testNoBespokeRDPSymbolsRemainInSources() throws {
        let sourcesDir = repoRoot.appendingPathComponent("Sources")
        let allPaths = try FileManager.default.subpathsOfDirectory(atPath: sourcesDir.path)
            .filter { $0.hasSuffix(".swift") }

        XCTAssertFalse(
            allPaths.isEmpty,
            "Guard scanned no Swift files in Sources — path resolution is broken, the guard would pass vacuously"
        )

        // Symbols that must be absent from non-comment source code.
        // Using substring match (not \b) so that e.g. RDPCredSSPNTLMv2CredentialResolver
        // is caught by the "RDPCredSSP" token.
        let forbidden = [
            "RDPCredSSP",
            "RDPSecurityUpgrade",
            "RDPLiveConnectionBootstrapper",
            "RDPActivatedByteTransportSession",
            "RDPDesktopUpdateStream",
            "RDPInputEventWriter",
        ]

        for relativePath in allPaths {
            let fileURL = sourcesDir.appendingPathComponent(relativePath)
            let raw = try String(contentsOf: fileURL, encoding: .utf8)
            let stripped = stripComments(from: raw)
            for symbol in forbidden {
                XCTAssertFalse(
                    stripped.contains(symbol),
                    "Sources/\(relativePath) still references bespoke RDP symbol '\(symbol)' outside comments"
                )
            }
        }
    }

    // MARK: - Test 3: CTermyRDP public header leaks no FreeRDP types
    //
    // Verifies the opaque-handle contract: only <stdint.h>, <stddef.h>,
    // <stdbool.h> are used in the public surface; FreeRDP/WinPR identifiers
    // do not appear as type declarations.
    //
    // Pattern matches: freerdp, FreeRDP, winpr, WinPR, rdpContext, rdpSettings,
    // AUDIO_FORMAT, BYTE, UINT8/16/32/64.
    //
    // Comment-stripping removes the doc banner ("Opaque-handle design: no
    // FreeRDP types cross this boundary.") and inline comments such as
    // `/* raw freerdp_get_last_error() value */` on line 120, preventing
    // false positives.
    //
    // Non-vacuity: a content-presence sentinel (`ctermyrdp_session`, the
    // opaque-handle typedef) catches path-redirect / silent-rewrite failure
    // modes that a bare isEmpty check would miss; if a
    // `#include <freerdp/client.h>` were added to the header, stripping
    // would leave it and the forbidden-pattern XCTAssertNil would fire.

    func testCTermyRDPPublicHeaderLeaksNoFreeRDPTypes() throws {
        let headerPath = repoRoot
            .appendingPathComponent("Sources/CTermyRDP/include/ctermyrdp.h")
        let raw = try String(contentsOf: headerPath, encoding: .utf8)

        // Sentinel: a public-API symbol stable across the milestone — if the header
        // is rewritten or path resolution silently lands on a different file, this fails.
        XCTAssertTrue(
            raw.contains("ctermyrdp_session"),
            "ctermyrdp.h does not contain the 'ctermyrdp_session' opaque-handle typedef — path resolution may be broken or the header was rewritten"
        )

        let stripped = stripComments(from: raw)

        // Forbidden: any FreeRDP or WinPR identifier that would represent
        // a type leaking across the boundary.
        // Includes BYTE / UINT{8,16,32,64} — WinPR's canonical uppercase
        // typedefs. The header uses lowercase uint8_t / uint32_t (C99 stdint)
        // so these patterns won't false-positive on the current contents.
        let forbiddenPattern =
            #"\b(freerdp|FreeRDP|winpr|WinPR|rdpContext|rdpSettings|AUDIO_FORMAT|BYTE|UINT8|UINT16|UINT32|UINT64)\b"#
        XCTAssertNil(
            stripped.range(of: forbiddenPattern, options: .regularExpression),
            "ctermyrdp.h public surface contains a FreeRDP/WinPR type identifier outside comments — opaque-handle boundary violated"
        )
    }

    // MARK: - Test 4: Only TermyRDP may import CTermyRDP (dependency boundary)
    //
    // The single legitimate import is FreeRDPSession.swift in Sources/TermyRDP.
    // TermyCore, TermySync, and Termy (the app target) must not import it.
    //
    // Positive sanity check: assert FreeRDPSession.swift DOES contain the
    // import, so this guard doesn't vacuously pass because TermyRDP itself
    // stopped using the shim.
    //
    // Per-target zero-files-scanned asserts prevent a path-resolution bug from
    // producing a vacuous pass (M4 precedent).

    func testOnlyTermyRDPImportsCTermyRDP() throws {
        // Positive check: the shim IS imported inside TermyRDP.
        let freeRDPSessionURL = repoRoot
            .appendingPathComponent("Sources/TermyRDP/FreeRDPSession.swift")
        let freeRDPSessionContents = try String(contentsOf: freeRDPSessionURL, encoding: .utf8)
        XCTAssertTrue(
            freeRDPSessionContents.contains("import CTermyRDP"),
            "Sources/TermyRDP/FreeRDPSession.swift should import CTermyRDP — the shim is no longer wired in"
        )

        // Boundary check: these targets must NOT import CTermyRDP (or the
        // phantom targets CFreeRDP / CWinPR that don't exist but harden the guard).
        let forbiddenImports = ["import CTermyRDP", "import CFreeRDP", "import CWinPR"]
        let boundaryTargets = ["Sources/TermyCore", "Sources/TermySync", "Sources/Termy"]

        for target in boundaryTargets {
            let dir = repoRoot.appendingPathComponent(target)
            let files = try FileManager.default.subpathsOfDirectory(atPath: dir.path)
                .filter { $0.hasSuffix(".swift") }

            XCTAssertFalse(
                files.isEmpty,
                "Guard scanned no Swift files in \(target) — path resolution is broken, the guard would pass vacuously"
            )

            for file in files {
                let contents = try String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8)
                for imp in forbiddenImports {
                    XCTAssertFalse(
                        contents.contains(imp),
                        "\(target)/\(file) must not contain '\(imp)' (CTermyRDP dependency boundary violated)"
                    )
                }
            }
        }
    }

    // MARK: - Test 5: Build script is pinned, executable, and contains SHA verification

    func testBuildScriptPinnedAndExecutable() throws {
        let scriptURL = repoRoot.appendingPathComponent("script/build_freerdp.sh")
        let pinsURL = repoRoot.appendingPathComponent("vendor/freerdp/PINS")

        // File existence
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: scriptURL.path),
            "script/build_freerdp.sh must exist"
        )
        // Content is verified via the script's '3.26.0' + 'rev-parse' literal checks above;
        // PINS existence here just confirms the vendor directory was initialized.
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: pinsURL.path),
            "vendor/freerdp/PINS must exist"
        )

        // Executable bit (persisted in git; checked via posixPermissions mask)
        let attrs = try FileManager.default.attributesOfItem(atPath: scriptURL.path)
        if let perms = attrs[.posixPermissions] as? Int {
            XCTAssertNotEqual(
                perms & 0o111, 0,
                "script/build_freerdp.sh must have at least one executable bit set"
            )
        } else {
            XCTFail("Could not read posixPermissions for script/build_freerdp.sh")
        }

        // Required content: version pin, safety flags, SHA verification step
        let contents = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(
            contents.contains("3.26.0"),
            "script/build_freerdp.sh must contain the literal '3.26.0' (FreeRDP version pin)"
        )
        XCTAssertTrue(
            contents.contains("set -euo pipefail"),
            "script/build_freerdp.sh must contain 'set -euo pipefail' (strict shell error handling)"
        )
        XCTAssertTrue(
            contents.contains("rev-parse"),
            "script/build_freerdp.sh must contain 'rev-parse' (SHA verification step from Task 2)"
        )
    }
}
