import XCTest
@testable import TermyCore

/// M2: proves the "track active session cwd" resolution. The Git module resolves
/// its working root by walking up from the session's cwd to the enclosing repo
/// (GitRepository.enclosingGitRoot), so a nested subdir maps to the repo root and
/// a non-repo dir resolves to nil (the app then falls back to projectRoot/home).
final class GitWorkingRootResolutionTests: XCTestCase {
    private var cleanupURLs: [URL] = []

    override func tearDown() {
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
        cleanupURLs = []
        super.tearDown()
    }

    func testNestedSubdirResolvesToRepoRoot() throws {
        let repoURL = try makeTempGitRepo()
        let nested = repoURL.appendingPathComponent("src/deep/here")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let resolved = GitRepository.enclosingGitRoot(of: nested)

        XCTAssertEqual(resolved?.standardizedFileURL.resolvingSymlinksInPath().path,
                       repoURL.standardizedFileURL.resolvingSymlinksInPath().path)
    }

    func testRepoRootResolvesToItself() throws {
        let repoURL = try makeTempGitRepo()
        let resolved = GitRepository.enclosingGitRoot(of: repoURL)
        XCTAssertEqual(resolved?.standardizedFileURL.resolvingSymlinksInPath().path,
                       repoURL.standardizedFileURL.resolvingSymlinksInPath().path)
    }

    func testNonRepoDirResolvesToNil() {
        let plain = makeTempDir()
        try? FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        XCTAssertNil(GitRepository.enclosingGitRoot(of: plain),
                     "a directory with no enclosing .git should resolve to nil (home fallback)")
    }

    // MARK: - Helpers

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("M2Root-\(UUID().uuidString)")
        cleanupURLs.append(url)
        return url
    }

    private func makeTempGitRepo() throws -> URL {
        let dir = makeTempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        runGit(["init", "-q", "-b", "main"], in: dir)
        runGit(["config", "user.email", "test@termy.test"], in: dir)
        runGit(["config", "user.name", "Termy Test"], in: dir)
        try "seed\n".write(to: dir.appendingPathComponent("seed.txt"), atomically: true, encoding: .utf8)
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
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
