import Foundation

/// Fully-offline classifier deciding whether a line typed into the prompt is a
/// shell **command** or a **natural-language** request (the Warp pattern, done
/// privately: nothing leaves the host).
///
/// The decision is a pure, synchronous heuristic over the input string —
/// known-binary / path / shell-operator detection, a leading English verb, and
/// sentence punctuation. There is no network call on the default path and no
/// `LocalAIClient` held anywhere; the privacy invariant (P1: zero bytes leave
/// the host) holds by construction. An *optional* small-local-model tie-break
/// is a separate injectable async layer (``classify(_:tieBreak:)``) that fires
/// only when the deterministic verdict lands in an ambiguous band.
///
/// Mirrors ``LocalAIClient/isFIMCapable(_:)``: pure, static, table-driven,
/// case-insensitive. UI / ⌘K wiring of the offer is a later slice.
public enum NLCommandClassifier {

    /// What the input most likely is.
    public enum Kind: String, Equatable, Sendable {
        case command
        case naturalLanguage
        /// No usable signal (e.g. empty input).
        case unknown
    }

    /// The action the caller should take.
    public enum SuggestedAction: String, Equatable, Sendable {
        /// Run the typed text as a shell command (the conventional terminal
        /// pass-through). This is the low-friction default whenever the read is
        /// not a confident natural-language one.
        case runAsCommand
        /// Offer to translate the natural-language request into a command — a
        /// conscious, user-accepted step (B4: offer, never take over).
        case offerNLToCommand
    }

    /// The classifier verdict.
    public struct NLClassification: Equatable, Sendable {
        public let kind: Kind
        /// Confidence in `kind`, in `0...1`.
        public let confidence: Double
        public let suggestedAction: SuggestedAction

        public init(kind: Kind, confidence: Double, suggestedAction: SuggestedAction) {
            self.kind = kind
            self.confidence = confidence
            self.suggestedAction = suggestedAction
        }

        /// True when confidence falls in the middle band — the only case where
        /// the optional local-model tie-break is worth consulting.
        public var isAmbiguous: Bool {
            confidence < NLCommandClassifier.decisiveConfidence && kind != .unknown
        }
    }

    /// At or above this confidence the heuristic verdict is treated as decisive
    /// and the optional tie-break is skipped. Tests assert against the *band*,
    /// not exact decimals.
    public static let decisiveConfidence: Double = 0.8

    /// Below this, an NL read is too weak to interrupt the user with an offer —
    /// such inputs pass through as commands (false offer = high friction;
    /// missed offer = cheap).
    public static let nlOfferThreshold: Double = 0.6

    // MARK: - Public API

    /// Classify `input` using heuristics only. Pure, synchronous, offline.
    public static func classify(_ input: String) -> NLClassification {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return NLClassification(kind: .unknown, confidence: 0, suggestedAction: .runAsCommand)
        }

        let commandScore = commandScore(for: trimmed)
        let nlScore = naturalLanguageScore(for: trimmed)

        // Net signal in -1...+1 (positive = command, negative = NL).
        let net = (commandScore - nlScore).clamped(to: -1...1)

        if net >= 0 {
            let confidence = 0.5 + net / 2  // 0.5...1.0
            return NLClassification(
                kind: .command,
                confidence: confidence,
                suggestedAction: .runAsCommand
            )
        } else {
            let confidence = 0.5 + (-net) / 2  // 0.5...1.0
            // Bias toward pass-through: only interrupt with an offer when the
            // NL read is reasonably confident.
            let action: SuggestedAction = confidence >= nlOfferThreshold ? .offerNLToCommand : .runAsCommand
            return NLClassification(
                kind: .naturalLanguage,
                confidence: confidence,
                suggestedAction: action
            )
        }
    }

    /// Classify `input`, consulting an optional small-local-model tie-break
    /// **only** when the deterministic verdict is ambiguous.
    ///
    /// `tieBreak` is injected by the caller and is the single seam through which
    /// a loopback-only local model may refine the decision; the classifier
    /// itself never constructs a client or touches the network. A `nil` return
    /// (model unavailable / undecided) preserves the heuristic verdict.
    public static func classify(
        _ input: String,
        tieBreak: (String) async -> Kind?
    ) async -> NLClassification {
        let heuristic = classify(input)
        guard heuristic.isAmbiguous else { return heuristic }

        guard let refinedKind = await tieBreak(input), refinedKind != heuristic.kind else {
            return heuristic
        }

        // The model resolved the ambiguity — promote to a decisive verdict in
        // the refined direction.
        switch refinedKind {
        case .command:
            return NLClassification(kind: .command, confidence: decisiveConfidence, suggestedAction: .runAsCommand)
        case .naturalLanguage:
            return NLClassification(kind: .naturalLanguage, confidence: decisiveConfidence, suggestedAction: .offerNLToCommand)
        case .unknown:
            return heuristic
        }
    }

    // MARK: - Heuristic scoring (0...1 each)

    /// Strength of the "this is a shell command" signal.
    private static func commandScore(for input: String) -> Double {
        var score = 0.0

        // Decisive shell shapes — any one of these is near-certain.
        if containsShellOperator(input) { score += 0.9 }
        if hasPathLead(input) { score += 0.9 }
        if hasEnvAssignmentLead(input) { score += 0.9 }
        if hasFlagToken(input) { score += 0.4 }

        // First token is a known binary/builtin.
        let first = firstToken(input)
        if knownBinaries.contains(first.lowercased()) {
            score += 0.6
        }

        return min(score, 1)
    }

    /// Strength of the "this is natural language" signal.
    private static func naturalLanguageScore(for input: String) -> Double {
        var score = 0.0
        let lower = input.lowercased()
        let words = lower.split(whereSeparator: { $0 == " " }).map(String.init)

        // Sentence punctuation — a trailing question mark is a near-certain NL
        // tell (a real shell command never ends in a bare '?'), strong enough
        // to override an otherwise command-shaped lead like "git status?".
        if input.hasSuffix("?") { score += 0.9 }
        if input.contains(",") || input.contains("'") && lower.hasPrefix("i ") { score += 0.1 }

        // Leading English imperative/interrogative verb or question word.
        if let lead = words.first, leadingNLWords.contains(lead) { score += 0.45 }

        // Stop-words are a hallmark of prose, not shell syntax.
        let stopWordHits = words.filter { stopWords.contains($0) }.count
        if stopWordHits >= 2 { score += 0.5 }
        else if stopWordHits == 1 { score += 0.25 }

        // Long multi-word phrases tend to be prose.
        if words.count >= 6 { score += 0.2 }

        return min(score, 1)
    }

    // MARK: - Token helpers

    private static func firstToken(_ input: String) -> String {
        String(input.split(whereSeparator: { $0 == " " }).first ?? "")
    }

    private static func containsShellOperator(_ input: String) -> Bool {
        // Pipe, redirection, chaining, subshell, glob, command-substitution.
        let operators = ["|", ">", "<", "&&", "||", ";", "$(", "`"]
        return operators.contains { input.contains($0) }
    }

    private static func hasPathLead(_ input: String) -> Bool {
        let first = firstToken(input)
        return first.hasPrefix("/") || first.hasPrefix("./") || first.hasPrefix("../") || first.hasPrefix("~/")
    }

    private static func hasEnvAssignmentLead(_ input: String) -> Bool {
        // VAR=value as the first token (optionally followed by a command).
        let first = firstToken(input)
        guard let eq = first.firstIndex(of: "="), eq != first.startIndex else { return false }
        let name = first[first.startIndex..<eq]
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
            && (name.first?.isLetter == true || name.first == "_")
    }

    private static func hasFlagToken(_ input: String) -> Bool {
        // A "-x" / "--long" token that is not a lone minus (and not negative
        // prose like a dashed clause, which would need a space — handled by the
        // token split).
        input.split(whereSeparator: { $0 == " " }).dropFirst().contains { token in
            (token.hasPrefix("-") && token.count > 1 && token != "--")
        }
    }

    // MARK: - Tables (pure, offline, case-insensitive)

    /// A curated set of common shell binaries and builtins. Several entries
    /// (`find`, `open`, `make`, `test`, `grep`, `touch`, `kill`) are also
    /// English verbs — the collision the scorer resolves by weighing the rest
    /// of the line (operators, flags, paths, prose structure).
    static let knownBinaries: Set<String> = [
        // Navigation / files
        "cd", "ls", "pwd", "cat", "less", "more", "head", "tail", "cp", "mv",
        "rm", "mkdir", "rmdir", "touch", "ln", "find", "open", "tree", "stat",
        "du", "df", "chmod", "chown", "ditto",
        // Text / search
        "grep", "egrep", "rg", "ripgrep", "ag", "sed", "awk", "sort", "uniq",
        "wc", "cut", "tr", "tee", "xargs", "echo", "printf", "diff", "patch",
        // Shell builtins / process
        "export", "alias", "unalias", "source", "set", "unset", "which", "type",
        "kill", "ps", "top", "jobs", "bg", "fg", "wait", "sleep", "exec", "env",
        "history", "clear", "exit",
        // VCS
        "git", "gh", "svn", "hg",
        // Build / package managers
        "make", "cmake", "swift", "xcodebuild", "npm", "npx", "pnpm", "yarn",
        "pip", "pip3", "python", "python3", "node", "deno", "bun", "cargo",
        "rustc", "go", "gradle", "mvn", "ruby", "gem", "bundle", "brew", "apt",
        "apt-get", "dnf", "pacman", "nix",
        // Containers / cloud / infra
        "docker", "podman", "kubectl", "helm", "terraform", "vagrant", "aws",
        "gcloud", "az",
        // Network / transfer
        "curl", "wget", "ssh", "scp", "sftp", "rsync", "ping", "dig", "nc",
        "telnet", "ftp",
        // Editors / misc
        "vim", "nvim", "nano", "emacs", "code", "test", "true", "false", "man",
        "tar", "zip", "unzip", "gzip", "gunzip", "sudo", "doas"
    ]

    /// Words that strongly signal a natural-language request when they LEAD the
    /// input — interrogatives and polite/imperative framings the shell never
    /// uses as a first token.
    static let leadingNLWords: Set<String> = [
        "how", "what", "why", "when", "where", "who", "which", "whats", "whose",
        "can", "could", "would", "should", "is", "are", "do", "does", "did",
        "please", "help", "show", "tell", "explain", "give", "let", "i",
        "create", "delete", "remove", "rename", "list", "display", "want",
        "need", "fix", "undo", "revert", "generate", "write", "add"
    ]

    /// Common English stop-words — frequent in prose, absent from shell syntax.
    static let stopWords: Set<String> = [
        "the", "a", "an", "to", "of", "in", "on", "for", "with", "and", "or",
        "but", "all", "every", "this", "that", "these", "those", "my", "me",
        "it", "its", "from", "into", "about", "using", "via", "so", "then",
        "than", "as", "by", "at", "do", "you", "your", "command", "files",
        "folders", "directory", "directories"
    ]
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
