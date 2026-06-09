import Foundation

/// Fully-offline classifier that flags shell commands which destroy data or
/// state — `rm -rf`, `git reset --hard`, `git push --force`, `dd`, `mkfs`,
/// `truncate`, a truncating `>` redirect into a real file, recursive
/// `chmod`/`chown`, etc. — returning a **risk level** and a specific,
/// human-readable **reason**.
///
/// Its sole purpose is to gate the proactive auto-fix / auto-insert path under
/// principle **B4** (the AI is proactive in *offering*, never in *taking
/// over*): a destructive suggestion must never be run or inserted without a
/// conscious user confirmation. The verdict feeds the confirmation copy a later
/// slice (S9) renders.
///
/// Like ``NLCommandClassifier`` this is a pure, synchronous, table-driven enum
/// with no network call and no `LocalAIClient` held anywhere — the decision is
/// made entirely from the command string, so the privacy invariant (P1: zero
/// bytes leave the host) holds by construction. Wiring of the gate into
/// `TermyStore` / the AI panel is a separate slice.
///
/// **Inverted bias (vs ``NLCommandClassifier``).** The NL classifier biases
/// *against* interrupting the user (a missed offer is cheap). This classifier
/// is the opposite: a false negative — missing an `rm -rf` and auto-inserting
/// it — is a B4 violation, while a false positive is mild friction. So it
/// biases toward *flagging*. It does **not**, however, collapse everything to
/// the top level: alarm fatigue would also defeat B4, which is the job of the
/// ``RiskLevel`` gradient. Destructiveness is judged as *verb × target*:
/// `rm -rf /` is catastrophic, `rm -rf ./build` is merely high.
public enum DestructiveCommandHeuristic {

    /// How dangerous a command is, ascending. The proactive path may auto-act
    /// only at ``RiskLevel/none``; anything above requires explicit
    /// confirmation copy scaled to the level.
    public enum RiskLevel: Int, Comparable, Equatable, Sendable {
        /// No destructive signal detected.
        case none = 0
        /// Destructive-shaped but bounded / recoverable (e.g. removing a local
        /// build dir, a single truncating redirect to a project file).
        case low = 1
        /// Clearly destructive and not trivially recoverable (recursive force
        /// delete of a path, `git reset --hard`, `truncate`).
        case moderate = 2
        /// Irreversible or wide-blast-radius (force-push rewriting history,
        /// `dd`, recursive chmod, `git clean -fdx`).
        case high = 3
        /// Catastrophic: targets a root / home / device (`rm -rf /`,
        /// `dd of=/dev/disk0`, `mkfs` on a device, `chmod -R 777 /`).
        case critical = 4

        public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// What *kind* of destruction was detected, so callers (S9) can compose
    /// confirmation copy without string-matching the human reason.
    public enum Category: String, Equatable, Sendable {
        case recursiveDelete       // rm -rf, rm -r
        case forcePush             // git push --force
        case hardReset             // git reset --hard
        case gitCleanForce         // git clean -fd(x)
        case diskWrite             // dd
        case makeFilesystem        // mkfs
        case truncate              // truncate -s, > redirect
        case redirectTruncate      // > real file
        case recursivePermission   // chmod/chown -R
    }

    /// A single destructive finding within a command.
    public struct Finding: Equatable, Sendable {
        public let category: Category
        public let level: RiskLevel
        /// Specific, human-readable explanation — load-bearing for the B4
        /// confirmation copy (e.g. "deletes files recursively without
        /// prompting", not "destructive").
        public let reason: String

        public init(category: Category, level: RiskLevel, reason: String) {
            self.category = category
            self.level = level
            self.reason = reason
        }
    }

    /// The verdict for a whole command line.
    public struct Verdict: Equatable, Sendable {
        /// The highest risk found across all segments (or ``RiskLevel/none``).
        public let level: RiskLevel
        /// Every distinct destructive finding, in detection order.
        public let findings: [Finding]

        public init(level: RiskLevel, findings: [Finding]) {
            self.level = level
            self.findings = findings
        }

        /// True when the command is destructive enough to require explicit
        /// confirmation before the proactive path may run or insert it.
        public var requiresConfirmation: Bool { level > .none }

        /// The single most severe reason, for compact UI; `nil` when safe.
        public var primaryReason: String? {
            findings.max(by: { $0.level < $1.level })?.reason
        }

        static let safe = Verdict(level: .none, findings: [])
    }

    // MARK: - Public API

    /// Evaluate `command` for destructive behaviour. Pure, synchronous,
    /// offline. Chained commands (`;`, `&&`, `||`, `|`) are split and the
    /// findings merged; the verdict's `level` is the maximum across segments.
    public static func evaluate(_ command: String) -> Verdict {
        let segments = splitSegments(command)
        var findings: [Finding] = []
        for segment in segments {
            findings.append(contentsOf: evaluateSegment(segment))
        }
        let level = findings.map(\.level).max() ?? .none
        return Verdict(level: level, findings: findings)
    }

    // MARK: - Segment evaluation

    private static func evaluateSegment(_ segment: String) -> [Finding] {
        let rawTokens = tokenize(segment)
        guard !rawTokens.isEmpty else { return [] }

        var findings: [Finding] = []

        // A truncating redirect can appear anywhere in the segment and is
        // independent of the binary, so scan for it first.
        if let redirect = redirectFinding(in: rawTokens) {
            findings.append(redirect)
        }

        // Strip leading `sudo`/`doas`, env-assignment prefixes, and `xargs`
        // (which executes a wrapped command — `… | xargs rm -rf`) to find the
        // real binary; `sudo` raises severity by one rung.
        var tokens = rawTokens
        var elevated = false
        while let first = tokens.first {
            if first == "sudo" || first == "doas" {
                elevated = true
                tokens.removeFirst()
            } else if isEnvAssignment(first) {
                tokens.removeFirst()
            } else if lastPathComponent(first) == "xargs" {
                // Drop `xargs` and any of its own flags so the wrapped command
                // (the real actor) is evaluated.
                tokens.removeFirst()
                while let f = tokens.first, f.hasPrefix("-") {
                    tokens.removeFirst()
                    // `-I {}` / `-n 1` take an argument token.
                    if (f == "-I" || f == "-n" || f == "-L" || f == "-P" || f == "-s"),
                       tokens.first != nil {
                        tokens.removeFirst()
                    }
                }
            } else {
                break
            }
        }

        guard let binary = tokens.first else {
            return findings
        }
        let args = Array(tokens.dropFirst())
        let bin = lastPathComponent(binary)

        if let finding = binaryFinding(bin: bin, args: args, elevated: elevated) {
            findings.append(elevated ? raisingForSudo(finding) : finding)
        }

        return findings
    }

    /// Dispatch on the (path-stripped) binary name.
    private static func binaryFinding(bin: String, args: [String], elevated: Bool) -> Finding? {
        switch bin {
        case "rm":            return rmFinding(args: args)
        case "git":           return gitFinding(args: args)
        case "dd":            return ddFinding(args: args)
        case "truncate":      return truncateFinding(args: args)
        case "chmod", "chown": return permissionFinding(bin: bin, args: args)
        default:
            if bin.hasPrefix("mkfs") {
                return mkfsFinding(bin: bin, args: args)
            }
            return nil
        }
    }

    // MARK: - rm

    private static func rmFinding(args: [String]) -> Finding? {
        let flags = collectFlags(args)
        let recursive = flags.contains("r") || flags.contains("R")
        let force = flags.contains("f")
        let operands = nonFlagOperands(args)

        guard recursive || force else {
            // A plain `rm file` is destructive-ish but conventionally expected;
            // only escalate when force/recursive removes the safety net.
            return operands.isEmpty ? nil : nil
        }

        if let target = operands.first(where: { isRootOrHomeTarget($0) }) {
            return Finding(
                category: .recursiveDelete,
                level: .critical,
                reason: "recursively force-deletes \(describe(target)) — irreversible, catastrophic blast radius"
            )
        }

        if recursive && force {
            return Finding(
                category: .recursiveDelete,
                level: .high,
                reason: "recursively force-deletes files without any prompt or recoverable trash"
            )
        }
        if recursive {
            return Finding(
                category: .recursiveDelete,
                level: .moderate,
                reason: "recursively deletes a directory tree"
            )
        }
        // force only
        return Finding(
            category: .recursiveDelete,
            level: .low,
            reason: "force-deletes files without prompting"
        )
    }

    // MARK: - git

    private static func gitFinding(args: [String]) -> Finding? {
        guard let sub = args.first(where: { !$0.hasPrefix("-") }) else { return nil }
        let rest = Array(args.drop(while: { $0 != sub }).dropFirst())

        switch sub {
        case "push":
            if rest.contains(where: { $0 == "--force" || $0 == "-f" }) {
                return Finding(
                    category: .forcePush,
                    level: .high,
                    reason: "force-pushes — overwrites remote history and can destroy others' commits"
                )
            }
            if rest.contains("--force-with-lease") || rest.contains(where: { $0.hasPrefix("--force-with-lease") }) {
                return Finding(
                    category: .forcePush,
                    level: .moderate,
                    reason: "force-pushes with lease — rewrites remote history (lease-guarded)"
                )
            }
            return nil
        case "reset":
            if rest.contains("--hard") {
                return Finding(
                    category: .hardReset,
                    level: .moderate,
                    reason: "hard-resets — discards all uncommitted changes in the working tree"
                )
            }
            return nil
        case "clean":
            let flags = collectFlags(rest)
            if flags.contains("f") && (flags.contains("d") || flags.contains("x") || flags.contains("X")) {
                return Finding(
                    category: .gitCleanForce,
                    level: .high,
                    reason: "force-cleans untracked files and directories — including ignored files, unrecoverable"
                )
            }
            if flags.contains("f") {
                return Finding(
                    category: .gitCleanForce,
                    level: .moderate,
                    reason: "force-cleans untracked files — unrecoverable"
                )
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - dd

    private static func ddFinding(args: [String]) -> Finding? {
        let writesToDevice = args.contains { arg in
            guard arg.hasPrefix("of=") else { return false }
            let target = String(arg.dropFirst(3))
            return target.hasPrefix("/dev/")
        }
        if writesToDevice {
            return Finding(
                category: .diskWrite,
                level: .critical,
                reason: "writes raw bytes directly to a device — can wipe an entire disk"
            )
        }
        return Finding(
            category: .diskWrite,
            level: .high,
            reason: "performs a raw block-level write that overwrites the output target"
        )
    }

    // MARK: - mkfs

    private static func mkfsFinding(bin: String, args: [String]) -> Finding? {
        let onDevice = args.contains { $0.hasPrefix("/dev/") }
        return Finding(
            category: .makeFilesystem,
            level: onDevice ? .critical : .high,
            reason: "creates a new filesystem — erases all existing data on the target"
        )
    }

    // MARK: - truncate

    private static func truncateFinding(args: [String]) -> Finding? {
        // truncate is destructive only with a size operand (-s / --size).
        let hasSize = args.contains { $0 == "-s" || $0 == "--size" || $0.hasPrefix("-s") || $0.hasPrefix("--size=") }
        guard hasSize else { return nil }
        return Finding(
            category: .truncate,
            level: .moderate,
            reason: "truncates a file to a fixed size — discards its existing contents"
        )
    }

    // MARK: - chmod / chown

    private static func permissionFinding(bin: String, args: [String]) -> Finding? {
        let flags = collectFlags(args)
        let recursive = flags.contains("R") || args.contains("--recursive")
        guard recursive else { return nil }
        let operands = nonFlagOperands(args)
        if let target = operands.first(where: { isRootOrHomeTarget($0) }) {
            return Finding(
                category: .recursivePermission,
                level: .critical,
                reason: "recursively changes permissions/ownership on \(describe(target)) — can break the whole system"
            )
        }
        return Finding(
            category: .recursivePermission,
            level: .high,
            reason: "recursively changes permissions/ownership across an entire directory tree"
        )
    }

    // MARK: - Redirects

    /// Detect a truncating output redirect (`>`, `1>`, `2>`, `&>`, `>|`) into a
    /// real file. Appends (`>>`) and known-safe sinks (`/dev/null`,
    /// `/dev/stdout`, `/dev/stderr`) are not flagged.
    private static func redirectFinding(in tokens: [String]) -> Finding? {
        for (index, token) in tokens.enumerated() {
            guard let target = redirectTarget(token: token, nextIndex: index + 1, tokens: tokens) else {
                continue
            }
            if isSafeRedirectSink(target) { continue }
            let level: RiskLevel = isRootOrHomeTarget(target) ? .high : .low
            return Finding(
                category: .redirectTruncate,
                level: level,
                reason: "truncates \(describe(target)) — overwrites its existing contents (use >> to append)"
            )
        }
        return nil
    }

    /// Returns the redirect target if `token` is a truncating-redirect operator,
    /// else `nil`. Handles both glued (`>file`) and detached (`> file`) forms.
    private static func redirectTarget(token: String, nextIndex: Int, tokens: [String]) -> String? {
        // Append redirects are safe — never flag.
        if token.contains(">>") { return nil }

        // Normalise the leading fd/operator. Recognised truncating forms:
        // ">", "1>", "2>", "&>", ">|" (and fd variants like "2>|").
        let truncatingPrefixes = [">|", ">", "1>", "2>", "&>", "1>|", "2>|"]
        // Find the longest matching operator prefix.
        let matched = truncatingPrefixes
            .filter { token.hasPrefix($0) }
            .max(by: { $0.count < $1.count })
        guard let op = matched else { return nil }

        let remainder = String(token.dropFirst(op.count))
        if !remainder.isEmpty {
            return remainder    // glued form: >file, 2>file
        }
        // Detached form: operator is its own token, target is the next token.
        guard nextIndex < tokens.count else { return nil }
        let next = tokens[nextIndex]
        // Guard against a redirect immediately followed by another operator.
        if next.hasPrefix(">") || next.hasPrefix("<") { return nil }
        return next
    }

    private static func isSafeRedirectSink(_ target: String) -> Bool {
        let safe: Set<String> = ["/dev/null", "/dev/stdout", "/dev/stderr"]
        return safe.contains(target)
    }

    // MARK: - sudo escalation

    /// Raise a finding by one rung when run under `sudo`/`doas` (wider blast
    /// radius), capped at ``RiskLevel/critical``.
    private static func raisingForSudo(_ finding: Finding) -> Finding {
        let raised = RiskLevel(rawValue: min(finding.level.rawValue + 1, RiskLevel.critical.rawValue)) ?? finding.level
        guard raised != finding.level else { return finding }
        return Finding(
            category: finding.category,
            level: raised,
            reason: finding.reason + " (run as root via sudo)"
        )
    }

    // MARK: - Token / flag helpers

    /// Split a command line into segments on shell separators that begin a new
    /// simple command (`;`, `&&`, `||`, `|`). This is intentionally NOT a real
    /// shell parser — it is a cheap split that lets each segment be scanned for
    /// a destructive binary; quoting edge cases bias toward over-flagging.
    static func splitSegments(_ command: String) -> [String] {
        var segments: [String] = []
        var current = ""
        let chars = Array(command)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next = i + 1 < chars.count ? chars[i + 1] : nil
            if c == ";" {
                segments.append(current); current = ""; i += 1
            } else if (c == "&" && next == "&") || (c == "|" && next == "|") {
                segments.append(current); current = ""; i += 2
            } else if c == "|" {
                segments.append(current); current = ""; i += 1
            } else {
                current.append(c); i += 1
            }
        }
        segments.append(current)
        return segments.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Whitespace tokenizer. Strips surrounding single/double quotes from each
    /// token so quoted operands compare cleanly; keeps redirect operators
    /// intact.
    static func tokenize(_ segment: String) -> [String] {
        segment
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map { stripQuotes(String($0)) }
            .filter { !$0.isEmpty }
    }

    private static func stripQuotes(_ token: String) -> String {
        guard token.count >= 2 else { return token }
        let first = token.first!
        let last = token.last!
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(token.dropFirst().dropLast())
        }
        return token
    }

    /// Collect short-flag letters across all `-x` / `-xy` / `--long` tokens,
    /// e.g. `["-rf", "-i"]` → `{"r", "f", "i"}`. Long flags contribute nothing
    /// to the letter set (callers test them explicitly).
    private static func collectFlags(_ args: [String]) -> Set<Character> {
        var set: Set<Character> = []
        for arg in args where arg.hasPrefix("-") && !arg.hasPrefix("--") && arg != "-" {
            for ch in arg.dropFirst() { set.insert(ch) }
        }
        // Map common long flags onto their short equivalents.
        if args.contains("--recursive") { set.insert("R"); set.insert("r") }
        if args.contains("--force") { set.insert("f") }
        return set
    }

    private static func nonFlagOperands(_ args: [String]) -> [String] {
        args.filter { !$0.hasPrefix("-") }
    }

    private static func isEnvAssignment(_ token: String) -> Bool {
        guard let eq = token.firstIndex(of: "="), eq != token.startIndex else { return false }
        let name = token[token.startIndex..<eq]
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
            && (name.first?.isLetter == true || name.first == "_")
    }

    private static func lastPathComponent(_ binary: String) -> String {
        String(binary.split(separator: "/").last ?? Substring(binary))
    }

    /// True when an operand targets a root, home, or device path — the
    /// catastrophic blast-radius tier.
    private static func isRootOrHomeTarget(_ operand: String) -> Bool {
        let t = operand
        if t == "/" || t == "/*" { return true }
        if t == "~" || t == "~/" || t == "$HOME" || t == "${HOME}" { return true }
        if t.hasPrefix("/dev/") { return true }
        // Top-level system directories.
        let systemRoots = ["/usr", "/etc", "/var", "/bin", "/sbin", "/lib",
                           "/System", "/Library", "/Applications", "/private",
                           "/boot", "/opt"]
        if systemRoots.contains(t) || systemRoots.contains(where: { t == $0 + "/" }) {
            return true
        }
        return false
    }

    private static func describe(_ target: String) -> String {
        switch target {
        case "/", "/*": return "the filesystem root (/)"
        case "~", "~/", "$HOME", "${HOME}": return "your entire home directory"
        default:
            if target.hasPrefix("/dev/") { return "a device (\(target))" }
            return "a system path (\(target))"
        }
    }
}
