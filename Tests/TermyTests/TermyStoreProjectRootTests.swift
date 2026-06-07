import XCTest
@testable import Termy

final class TermyStoreProjectRootTests: XCTestCase {
    /// Regression: launching via `open -n` sets cwd to `/`, so the default
    /// `projectRoot` (cwd) was `/` — pointing Files/Git/SFTP at the whole
    /// filesystem (the "No files" symptom + a launch-time walk). A `/` root must
    /// fall back to the user's home directory.
    func testSanitizedProjectRootFallsBackToHomeForFilesystemRoot() {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        XCTAssertEqual(TermyStore.sanitizedProjectRoot(URL(fileURLWithPath: "/")), home)
    }

    /// A real directory is preserved (standardized) — only `/` is special-cased.
    func testSanitizedProjectRootKeepsRealDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        XCTAssertEqual(TermyStore.sanitizedProjectRoot(home), home)
    }
}
