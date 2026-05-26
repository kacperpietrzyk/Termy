import XCTest
@testable import TermyCore

final class GitVitalsTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    func testCleanRepoReportsBranchAndZeroDirty() throws {
        let repo = try makeTempGitRepo()
        let vitals = gitVitals(forCwd: repo.path)
        XCTAssertEqual(vitals.branch, "main")
        XCTAssertEqual(vitals.dirtyCount, 0)
    }

    func testModifiedAndUntrackedCountTowardDirty() throws {
        let repo = try makeTempGitRepo()
        try "changed".write(to: repo.appendingPathComponent("seed.txt"), atomically: true, encoding: .utf8)
        try "new".write(to: repo.appendingPathComponent("scratch.txt"), atomically: true, encoding: .utf8)
        XCTAssertEqual(gitVitals(forCwd: repo.path).dirtyCount, 2)
    }

    func testNonRepoIsUnknown() {
        let plain = makeTempDir()
        try? FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        let vitals = gitVitals(forCwd: plain.path)
        XCTAssertNil(vitals.branch)
        XCTAssertEqual(vitals.dirtyCount, 0)
        XCTAssertEqual(vitals, .unknown)
    }

    // MARK: - Helpers
    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FB34GV-\(UUID().uuidString)")
        cleanupURLs.append(url)
        return url
    }
    private func makeTempGitRepo() throws -> URL {
        let dir = makeTempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        runGit(["init", "-q", "-b", "main"], in: dir)
        runGit(["config", "user.email", "test@termy.test"], in: dir)
        runGit(["config", "user.name", "Termy Test"], in: dir)
        try "seed".write(to: dir.appendingPathComponent("seed.txt"), atomically: true, encoding: .utf8)
        runGit(["add", "."], in: dir)
        runGit(["commit", "-q", "-m", "seed"], in: dir)
        return dir
    }
    @discardableResult
    private func runGit(_ args: [String], in dir: URL) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        process.standardOutput = Pipe(); process.standardError = Pipe()
        try? process.run(); process.waitUntilExit()
        return process.terminationStatus
    }
}
