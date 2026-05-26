import XCTest

final class F4DataLayerRegressionTests: XCTestCase {
    private static var repoRoot: URL {
        // #file is Tests/TermyTests/F4DataLayerRegressionTests.swift
        // walk up: file → TermyTests → Tests → repoRoot
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func test_terminalCompletionCommandNames_constant_isGone() throws {
        let url = Self.repoRoot.appendingPathComponent("Sources/Termy/Stores/TermyStore.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            src.contains("terminalCompletionCommandNames"),
            "terminalCompletionCommandNames must be deleted (F-4 Task 10)"
        )
    }

    func test_terminalCompletionCommandFlags_constant_isGone() throws {
        let url = Self.repoRoot.appendingPathComponent("Sources/Termy/Stores/TermyStore.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            src.contains("terminalCompletionCommandFlags"),
            "terminalCompletionCommandFlags must be deleted (F-4 Task 10)"
        )
    }

    func test_CwdAwareFilePaths_file_isGone() {
        let url = Self.repoRoot.appendingPathComponent("Sources/TermyCore/CwdAwareFilePaths.swift")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: url.path),
            "CwdAwareFilePaths.swift must be deleted (F-4 Task 10) — sidecar supersedes"
        )
    }

    func test_CompletionEngine_stillConstructedForCommandLineSSH() throws {
        let url = Self.repoRoot.appendingPathComponent("Sources/Termy/Stores/TermyStore.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            src.contains("CompletionEngine("),
            "SSH .commandLine path must still construct a CompletionEngine"
        )
    }
}
