import XCTest
import Foundation
@testable import TermyRDP

final class TermyRDPTargetTests: XCTestCase {
    func testTermyRDPTargetLinks() {
        XCTAssertTrue(true)
    }

    func testTermyCoreHasNoRDPBackEdge() throws {
        // Structural guard: TermyCore must not reference RDP symbols.
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()      // Tests/TermyRDPTests
            .deletingLastPathComponent()                 // Tests
            .deletingLastPathComponent()                 // repo root
        let coreDir = root.appendingPathComponent("Sources/TermyCore")
        let files = try FileManager.default
            .contentsOfDirectory(at: coreDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(
            files.isEmpty,
            "Guard scanned no Swift files in \(coreDir.path) — path resolution is broken, the guard would pass vacuously"
        )
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(
                text.range(of: #"\bRDP[A-Z]"#, options: .regularExpression) != nil,
                "TermyCore back-edge into RDP found in \(file.lastPathComponent)"
            )
        }
    }
}
