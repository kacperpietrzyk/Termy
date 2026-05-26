import XCTest

final class SpecHighlightPackagingTests: XCTestCase {
    private var repoRoot: URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path),
              url.path != "/" {
            url.deleteLastPathComponent()
        }
        return url
    }

    func testBothScriptsStageSpecsAndHighlighter() throws {
        for script in ["script/build_and_run.sh", "script/package_dmg.sh"] {
            let t = try String(contentsOfFile: repoRoot.appendingPathComponent(script).path, encoding: .utf8)
            XCTAssertTrue(t.contains(#"cp -R "$ROOT_DIR/vendor/specs/out" "$APP_RESOURCES/specs""#), script)
            XCTAssertTrue(t.contains(#"cp "$ROOT_DIR/script/shell/termy-spec-highlighter.zsh" "$APP_RESOURCES/specs/""#), script)
        }
        let dmg = try String(contentsOfFile: repoRoot.appendingPathComponent("script/package_dmg.sh").path, encoding: .utf8)
        XCTAssertTrue(dmg.contains("specsAudited"))
    }
}
