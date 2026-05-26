import XCTest

final class AppIconPackagingTests: XCTestCase {
    private var repoRoot: URL {
        var url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path),
              url.path != "/" {
            url.deleteLastPathComponent()
        }
        return url
    }

    func testAppIconAssetExists() {
        let icon = repoRoot.appendingPathComponent("Resources/AppIcon.icns")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: icon.path),
            "Resources/AppIcon.icns must exist so packaged builds do not fall back to the default blank icon"
        )
    }

    func testBundleScriptsStageAppIconAndDeclareItInInfoPlist() throws {
        for relative in ["script/build_and_run.sh", "script/package_dmg.sh"] {
            let script = try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
            XCTAssertTrue(
                script.contains("Resources/AppIcon.icns"),
                "\(relative) must copy the app icon into Contents/Resources"
            )
            XCTAssertTrue(
                script.contains("CFBundleIconFile"),
                "\(relative) must declare CFBundleIconFile in Info.plist"
            )
            XCTAssertTrue(
                script.contains("AppIcon"),
                "\(relative) must use the AppIcon resource name"
            )
        }
    }
}
