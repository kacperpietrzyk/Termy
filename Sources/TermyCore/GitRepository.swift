import Foundation

public enum GitRepositoryError: Error, Equatable {
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case emptyCommitMessage
}

public struct GitStatus: Equatable, Sendable {
    public let entries: [GitStatusEntry]

    public init(entries: [GitStatusEntry]) {
        self.entries = entries
    }
}

public struct GitStatusEntry: Equatable, Sendable {
    public let code: String
    public let path: String

    public init(code: String, path: String) {
        self.code = code
        self.path = path
    }
}

public struct GitCommitResult: Equatable, Sendable {
    public let summary: String
}

public struct GitCommandResult: Equatable, Sendable {
    public let output: String
}

/// One commit in the history list (drives the Git module's graph rail).
public struct GitLogEntry: Equatable, Sendable, Identifiable {
    public let hash: String
    public let shortHash: String
    public let parents: [String]
    public let refNames: [String]   // decoded `%D`: "HEAD -> main", "origin/main", "tag: v1"
    public let author: String
    public let relativeDate: String
    public let subject: String

    public var id: String { hash }
    public var isMerge: Bool { parents.count > 1 }

    public init(hash: String, shortHash: String, parents: [String], refNames: [String],
                author: String, relativeDate: String, subject: String) {
        self.hash = hash; self.shortHash = shortHash; self.parents = parents
        self.refNames = refNames; self.author = author
        self.relativeDate = relativeDate; self.subject = subject
    }
}

/// A working-tree change with its raw porcelain XY code preserved, so the UI can
/// split staged (index, X) from unstaged (worktree, Y).
public struct GitChange: Equatable, Sendable, Identifiable {
    public let x: Character   // index / staged column
    public let y: Character   // worktree / unstaged column
    public let path: String

    public var id: String { path }
    public var isStaged: Bool { x != " " && x != "?" }
    public var isUnstaged: Bool { y != " " }
    public var isUntracked: Bool { x == "?" && y == "?" }
    public var isConflicted: Bool { x == "U" || y == "U" || (x == "A" && y == "A") || (x == "D" && y == "D") }

    public init(x: Character, y: Character, path: String) {
        self.x = x; self.y = y; self.path = path
    }
}

public struct GitDivergence: Equatable, Sendable {
    public let ahead: Int
    public let behind: Int

    public init(ahead: Int, behind: Int) {
        self.ahead = ahead
        self.behind = behind
    }
}

public struct GitRepository: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func statusShort() throws -> GitStatus {
        let result = try runGit(["status", "--short"])
        let entries = result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap(parseStatusLine)
        return GitStatus(entries: entries)
    }

    public func stageAll() throws {
        _ = try runGit(["add", "--all"])
    }

    /// Working-tree changes with raw XY porcelain codes preserved (staged vs unstaged).
    public func changes() throws -> [GitChange] {
        let out = try runGit(["status", "--porcelain"]).stdout
        return out.split(whereSeparator: \.isNewline).compactMap { line in
            let chars = Array(String(line))
            guard chars.count >= 4 else { return nil }
            let path = String(chars[3...])
            guard !path.isEmpty else { return nil }
            return GitChange(x: chars[0], y: chars[1], path: path)
        }
    }

    /// Recent commits for the history/graph view. Fields are unit-separated (US,
    /// 0x1f) and records newline-separated; `%D` ref decoration is split on commas.
    public func recentCommits(limit: Int = 60) throws -> [GitLogEntry] {
        let unit = "\u{1f}"
        let fields = ["%H", "%h", "%P", "%D", "%an", "%ar", "%s"].joined(separator: unit)
        let out = try runGit(["log", "--pretty=format:\(fields)", "-n", "\(limit)"]).stdout
        return out.split(whereSeparator: \.isNewline).compactMap { line in
            let f = String(line).components(separatedBy: unit)
            guard f.count == 7 else { return nil }
            let parents = f[2].split(separator: " ").map(String.init)
            let refs = f[3].split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return GitLogEntry(hash: f[0], shortHash: f[1], parents: parents,
                               refNames: refs, author: f[4], relativeDate: f[5], subject: f[6])
        }
    }

    public func localBranches() throws -> [String] {
        let result = try runGit(["branch", "--format", "%(refname:short)"])
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    public func currentBranch() throws -> String {
        let result = try runGit(["branch", "--show-current"])
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func createBranch(named name: String, checkout: Bool) throws {
        if checkout {
            _ = try runGit(["checkout", "-b", name])
        } else {
            _ = try runGit(["branch", name])
        }
    }

    public func checkoutBranch(_ name: String) throws {
        _ = try runGit(["checkout", name])
    }

    public func diff() throws -> String {
        try runGit(["diff"]).stdout
    }

    public func conflictHunks() throws -> [GitConflictHunk] {
        let conflictedPaths = try statusShort().entries
            .filter { $0.code.contains("U") || $0.code == "AA" || $0.code == "DD" }
            .map(\.path)

        let parser = GitConflictParser()
        return try conflictedPaths.flatMap { path in
            let fileURL = root.appendingPathComponent(path)
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            return parser.parse(contents, path: path)
        }
    }

    public func aheadBehind() throws -> GitDivergence {
        let result = try runGit(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"])
        let parts = result.stdout.split(whereSeparator: \.isWhitespace)
        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            return GitDivergence(ahead: 0, behind: 0)
        }
        return GitDivergence(ahead: ahead, behind: behind)
    }

    public func pushCurrentBranch(setUpstream: Bool = false) throws -> GitCommandResult {
        let branch = try currentBranch()
        var arguments = ["push"]
        if setUpstream {
            arguments.append("--set-upstream")
        }
        arguments.append(contentsOf: ["origin", branch])
        let result = try runGit(arguments)
        return GitCommandResult(output: result.stdout + result.stderr)
    }

    public func pullCurrentBranch() throws -> GitCommandResult {
        let result = try runGit(["pull", "--ff-only"])
        return GitCommandResult(output: result.stdout + result.stderr)
    }

    public func commit(message: String) throws -> GitCommitResult {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GitRepositoryError.emptyCommitMessage
        }

        let result = try runGit(["commit", "-m", trimmed])
        return GitCommitResult(summary: result.stdout + result.stderr)
    }

    public func resolveHEAD() throws -> String {
        try runGit(["rev-parse", "HEAD"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func isRepository() -> Bool {
        (try? runGit(["rev-parse", "--is-inside-work-tree"])) != nil
    }

    public func addWorktree(branch: String, base: String, path: URL) throws {
        _ = try runGit(["worktree", "add", "-b", branch, path.path, base])
    }

    public func removeWorktree(path: URL) throws {
        _ = try runGit(["worktree", "remove", path.path])
    }

    public func deleteBranch(_ name: String) throws {
        _ = try runGit(["branch", "-d", name])
    }

    public func commitCount(since baseSHA: String) throws -> Int {
        let output = try runGit(["rev-list", "--count", "\(baseSHA)..HEAD"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(output) ?? 0
    }

    /// A worktree is disposable when its working tree is clean (no modified,
    /// staged, or untracked files) AND it has no commits beyond `baseSHA`.
    /// Uncommitted agent output is therefore never auto-deleted.
    public func isDisposable(baseSHA: String) throws -> Bool {
        let clean = try statusShort().entries.isEmpty
        guard clean else { return false }
        return try commitCount(since: baseSHA) == 0
    }

    /// The main worktree root for this repo (works when `root` is a linked
    /// worktree). `git worktree list --porcelain` lists the main worktree first.
    public func mainWorktreeRoot() throws -> URL {
        let output = try runGit(["worktree", "list", "--porcelain"]).stdout
        for line in output.split(whereSeparator: \.isNewline) where line.hasPrefix("worktree ") {
            return URL(fileURLWithPath: String(line.dropFirst("worktree ".count)))
        }
        return root
    }

    /// Safety net for app-quit-while-agent-running: removes any **clean** git
    /// worktree directly under `parent` (its branch is left intact, so no
    /// committed work is lost); dirty worktrees and non-worktree directories
    /// are kept. Branch SHAs aren't persisted across launches, so this uses the
    /// conservative clean-tree test only.
    public static func sweepCleanAgentWorktrees(in parent: URL) {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: parent, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for directory in entries {
            let isDirectory = (try? directory.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDirectory else { continue }
            let worktree = GitRepository(root: directory)
            guard let status = try? worktree.statusShort(), status.entries.isEmpty else { continue }
            guard let mainRoot = try? worktree.mainWorktreeRoot() else { continue }
            try? GitRepository(root: mainRoot).removeWorktree(path: directory)
        }
    }

    private func parseStatusLine(_ line: Substring) -> GitStatusEntry? {
        let text = String(line)
        guard text.count >= 4 else { return nil }
        let code = String(text.prefix(2)).trimmingCharacters(in: .whitespaces)
        let pathStart = text.index(text.startIndex, offsetBy: 3)
        return GitStatusEntry(code: code, path: String(text[pathStart...]))
    }

    private func runGit(_ arguments: [String]) throws -> ShellCommandResult {
        let command = shellCommand(for: arguments)
        let result = try ShellCommandRunner(workingDirectory: root).run(command)
        guard result.exitCode == 0 else {
            throw GitRepositoryError.commandFailed(
                command: command,
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return result
    }

    private func shellCommand(for arguments: [String]) -> String {
        (["git"] + arguments)
            .map(shellQuote)
            .joined(separator: " ")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
