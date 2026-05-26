import XCTest

/// M4 structural guards: the bespoke update surface is gone, and
/// Sparkle never leaks into the dependency-clean targets.
final class M4SparkleGuardsTests: XCTestCase {
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

    func testBespokeUpdateSourcesDeleted() {
        for relative in ["Sources/TermyCore/UpdateManifest.swift",
                         "Sources/Termy/Models/UpdateModel.swift"] {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(relative).path),
                "\(relative) must be deleted in M4"
            )
        }
    }

    func testDependencyCleanTargetsDoNotImportSparkle() throws {
        for target in ["Sources/TermyCore", "Sources/TermyRDP", "Sources/TermySync"] {
            let dir = repoRoot.appendingPathComponent(target)
            let files = try FileManager.default.subpathsOfDirectory(atPath: dir.path)
                .filter { $0.hasSuffix(".swift") }
            XCTAssertFalse(
                files.isEmpty,
                "Guard scanned no Swift files in \(target) — path resolution is broken, the guard would pass vacuously"
            )
            for file in files {
                let contents = try String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8)
                XCTAssertFalse(
                    contents.contains("import Sparkle"),
                    "\(target)/\(file) must not import Sparkle (dependency boundary)"
                )
            }
        }
    }

    func testNoBespokeUpdateSymbolsRemainInSources() throws {
        let dir = repoRoot.appendingPathComponent("Sources")
        let files = try FileManager.default.subpathsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") }
        XCTAssertFalse(
            files.isEmpty,
            "Guard scanned no Swift files in Sources — path resolution is broken, the guard would pass vacuously"
        )
        for file in files {
            let contents = try String(contentsOf: dir.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(
                contents.range(of: #"\b(UpdateChecker|AutoUpdateSchedule|UpdateArtifactVerifier|UpdateManifest)\b"#, options: .regularExpression) != nil,
                "\(file) still references a deleted bespoke-update symbol (UpdateChecker / AutoUpdateSchedule / UpdateArtifactVerifier / UpdateManifest)"
            )
        }
    }
}
