import Foundation

/// AD-8 — the narrow `gh`-specific surface of the PR finalizer: build the
/// `gh pr create` argument vector, run it through an injected runner, and parse
/// its result into a typed outcome. Git itself (stage / commit / push) is NOT
/// reimplemented here — that stays in `GitRepository` (`commit`/`pushCurrentBranch`),
/// matching the blueprint's "happy-path finalizer, not a full git client".
///
/// Privacy/auth (P1): `gh` uses the USER's own GitHub auth (`gh auth`); Termy
/// neither stores nor relays any token. The runner is injected so this type is
/// unit-tested with a stub — a test NEVER spawns `gh` or creates a real PR.
///
/// B4 (offer, never take over): this type only *constructs and runs* the create
/// command. The decision to run it — and the title/body it carries — is owned by
/// the caller (the store), gated on an explicit user action with a reviewed,
/// editable description. Nothing here auto-pushes or auto-submits.
public struct GhPullRequest: Sendable {
    /// The result of running a `gh` command: its exit status and combined output.
    /// Mirrors the shape `ShellCommandRunner` already produces so the store can
    /// adapt its runner with a thin closure.
    public struct RunResult: Equatable, Sendable {
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String

        public init(exitCode: Int32, stdout: String, stderr: String) {
            self.exitCode = exitCode
            self.stdout = stdout
            self.stderr = stderr
        }
    }

    /// Runs an argv (e.g. `["gh", "pr", "create", …]`) and returns its result.
    /// The store wires this to `ShellCommandRunner`; tests wire a stub. Throwing
    /// surfaces a transport-level failure (e.g. `gh` binary not found).
    public typealias Runner = @Sendable ([String]) throws -> RunResult

    private let runner: Runner

    public init(runner: @escaping Runner) {
        self.runner = runner
    }

    // MARK: - Argument construction (pure — the primary unit-tested surface)

    /// Build the `gh pr create` argv for `request`. `--fill` is deliberately NOT
    /// used: AD-8 supplies a reviewed, local-model-drafted title+body, so we pass
    /// them explicitly. Empty/whitespace fields are dropped rather than sent as
    /// empty flags. Returns the full argv including the leading `gh`.
    public static func createArguments(_ request: CreateRequest) -> [String] {
        var args = ["gh", "pr", "create"]
        args += ["--base", request.base]
        args += ["--head", request.head]
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            args += ["--title", title]
        }
        // Always pass --body (possibly empty string) so gh does not drop into its
        // interactive editor on a missing body — the finalizer is non-interactive.
        args += ["--body", request.body]
        if request.draft {
            args.append("--draft")
        }
        if let repo = request.repo?.trimmingCharacters(in: .whitespacesAndNewlines),
           !repo.isEmpty {
            args += ["--repo", repo]
        }
        return args
    }

    /// Build the `gh auth status` argv (used to surface an honest
    /// "not authenticated" state before attempting a create).
    public static func authStatusArguments() -> [String] {
        ["gh", "auth", "status"]
    }

    // MARK: - Running

    /// Check that `gh` is present and the user is authenticated. Honest: a missing
    /// binary (runner throws) or a non-zero `gh auth status` both map to
    /// `.notAuthenticated` with the captured detail — never faked as ready.
    public func checkAuth() -> AuthState {
        let result: RunResult
        do {
            result = try runner(Self.authStatusArguments())
        } catch {
            return .ghMissing
        }
        if result.exitCode == 0 {
            return .authenticated
        }
        return .notAuthenticated(detail: Self.firstMeaningfulLine(of: result))
    }

    /// Run `gh pr create` for `request` and parse the outcome. Never throws on a
    /// `gh`-level failure — a non-zero exit becomes `.failed` with the honest
    /// reason; only a transport failure (binary truly absent) maps to `.ghMissing`.
    public func create(_ request: CreateRequest) -> CreateOutcome {
        let result: RunResult
        do {
            result = try runner(Self.createArguments(request))
        } catch {
            return .ghMissing
        }
        return Self.parseCreate(result)
    }

    // MARK: - Output / error parsing (pure — unit-tested)

    /// Parse a `gh pr create` result. On success `gh` prints the new PR's URL on
    /// its own line; we extract it (and the trailing number) so the UI can deep
    /// link. On failure we surface an honest, classified reason.
    public static func parseCreate(_ result: RunResult) -> CreateOutcome {
        if result.exitCode == 0 {
            let combined = result.stdout + "\n" + result.stderr
            if let url = firstPullRequestURL(in: combined) {
                return .created(url: url, number: pullRequestNumber(in: url))
            }
            // Exit 0 but no URL found — treat as success without a parseable link
            // rather than inventing one (never-fabricate).
            return .created(url: nil, number: nil)
        }

        let detail = firstMeaningfulLine(of: result)
        let lower = detail.lowercased()
        if lower.contains("already exists") || lower.contains("a pull request for branch") {
            return .alreadyExists(detail: detail)
        }
        if lower.contains("authentication") || lower.contains("not logged") || lower.contains("gh auth login") {
            return .failed(reason: .notAuthenticated, detail: detail)
        }
        if lower.contains("no commits between") || lower.contains("no commits") {
            return .failed(reason: .noCommits, detail: detail)
        }
        return .failed(reason: .other, detail: detail)
    }

    /// The first https GitHub PR URL in `text`, if any. Matches the canonical
    /// `…/pull/<n>` form `gh` prints; tolerant of surrounding text.
    public static func firstPullRequestURL(in text: String) -> String? {
        for rawLine in text.split(whereSeparator: \.isNewline) {
            for token in rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                let candidate = String(token).trimmingCharacters(in: .whitespaces)
                if candidate.hasPrefix("https://") && candidate.contains("/pull/") {
                    return candidate
                }
            }
        }
        return nil
    }

    /// The PR number from a `…/pull/<n>` URL, if the trailing path component is
    /// numeric. nil otherwise (never guess).
    public static func pullRequestNumber(in url: String) -> Int? {
        guard let range = url.range(of: "/pull/") else { return nil }
        let tail = url[range.upperBound...]
        let digits = tail.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// The first non-empty trimmed line of a result's output, preferring stderr
    /// (where `gh` writes errors). Used as the human-readable detail. Empty string
    /// when there is nothing to show.
    static func firstMeaningfulLine(of result: RunResult) -> String {
        for stream in [result.stderr, result.stdout] {
            for line in stream.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }
}

public extension GhPullRequest {
    /// The reviewed, explicit inputs to `gh pr create`. The title/body come from
    /// the local model draft AFTER the user has had a chance to edit them (B4).
    struct CreateRequest: Equatable, Sendable {
        public let base: String   // target branch, e.g. "main"
        public let head: String   // source branch (the agent's worktree branch)
        public let title: String
        public let body: String
        public let draft: Bool
        public let repo: String?  // optional OWNER/REPO override; nil = current repo

        public init(
            base: String,
            head: String,
            title: String,
            body: String,
            draft: Bool = false,
            repo: String? = nil
        ) {
            self.base = base
            self.head = head
            self.title = title
            self.body = body
            self.draft = draft
            self.repo = repo
        }
    }

    /// Whether `gh` is ready to finalize.
    enum AuthState: Equatable, Sendable {
        case authenticated
        case notAuthenticated(detail: String)
        case ghMissing
    }

    /// The classified failure reason for a `gh pr create` that exited non-zero.
    enum CreateFailureReason: Equatable, Sendable {
        case notAuthenticated
        case noCommits
        case other
    }

    /// The outcome of attempting to create a PR. Honest: success carries the
    /// parsed URL/number (or nil when unparseable); failures carry the reason and
    /// the verbatim `gh` detail — success is never faked.
    enum CreateOutcome: Equatable, Sendable {
        case created(url: String?, number: Int?)
        case alreadyExists(detail: String)
        case failed(reason: CreateFailureReason, detail: String)
        case ghMissing
    }
}
