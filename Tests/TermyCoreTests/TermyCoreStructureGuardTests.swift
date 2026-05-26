import XCTest
import Foundation
@testable import TermyCore

final class TermyCoreStructureGuardTests: XCTestCase {
    /// `TermyCore` must not depend on the `TermySync` target, so `TermySync`
    /// (and `TermyRDP`) keep a clean one-way dependency on `TermyCore`.
    ///
    /// The robust invariant is module-membership: no `TermyCore` source may
    /// `import TermySync`. A name-based denylist is kept as defense-in-depth
    /// — it catches a stray sync-type reference even before an import is
    /// added (the M2a regex only matched `PrivateSync<Cap>` and silently
    /// missed `SyncSnippet`/`SyncWorkspace`; M2b widened it and removed the
    /// old `PrivateSync.swift`/`CloudKitPrivateSync.swift` exclusion list
    /// now that those files live in the `TermySync` target).
    func testTermyCoreHasNoSyncBackEdge() throws {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()  // Tests/TermyCoreTests
            .deletingLastPathComponent()             // Tests
            .deletingLastPathComponent()             // repo root
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
                text.range(of: #"(?m)^\s*import\s+TermySync\b"#, options: .regularExpression) != nil,
                "TermyCore source \(file.lastPathComponent) imports TermySync — back-edge into the sync target"
            )
            XCTAssertFalse(
                text.range(of: #"\b(PrivateSync[A-Z]|CloudKitPrivateSync\b|Sync(Snippet|Workspace)\b)"#, options: .regularExpression) != nil,
                "TermyCore shared-model back-edge into the sync layer found in \(file.lastPathComponent)"
            )
        }
    }
}
