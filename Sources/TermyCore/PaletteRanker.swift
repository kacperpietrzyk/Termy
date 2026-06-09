import Foundation

/// CK-S3: the pure ranking core for the ⌘K command palette.
///
/// Blends three on-device signals into one ordered feed:
///   1. **Fuzzy** — `FuzzyMatcher` subsequence score (CK-S1), best-field-wins.
///   2. **Frecency** — per-item exp-decay usage (CK-S2), additively weighted so a
///      frequently-accepted item floats above a never-used one at equal fuzzy.
///   3. **Context boosts** — small additive nudges from the live app state
///      (git root present, a terminal block selected, live agents, the cwd):
///      they re-order *near-ties*, but a strong title match always wins over a
///      context boost on a weak one (typing dominates; context only nudges).
///
/// Stays a pure `Sendable` value type over plain inputs (candidate fields +
/// a frecency map + a small `PaletteContext`) so it unit-tests in isolation,
/// off the `@MainActor` store. **Privacy (P1):** every signal is local — no
/// input here ever reaches a network payload.
public enum PaletteRanker {
    /// One candidate to rank. `fields` is the best-field-wins set fed to the
    /// fuzzy matcher (`[id, title, subtitle] + keywords`, title at
    /// `preferredFieldIndex`); `title` is highlighted separately so the row only
    /// ever underlines visible glyphs. `kind` and `area`/`isBlockAction` carry
    /// just enough structure for the context boosts and the zero-signal
    /// tie-break — the ranker never imports app types.
    public struct Candidate: Sendable {
        public let id: String
        public let title: String
        public let fields: [String]
        public let preferredFieldIndex: Int
        public let kind: Kind
        /// Product area as a lowercase string ("git", "terminal", "ai", …) for
        /// the context boosts; empty for profiles/agents.
        public let area: String
        /// True for `.terminal` actions whose id/keywords name a command *block*
        /// (the only honest "block action" selector — there is no block group).
        public let isBlockAction: Bool

        public init(
            id: String,
            title: String,
            fields: [String],
            preferredFieldIndex: Int = 1,
            kind: Kind,
            area: String = "",
            isBlockAction: Bool = false
        ) {
            self.id = id
            self.title = title
            self.fields = fields
            self.preferredFieldIndex = preferredFieldIndex
            self.kind = kind
            self.area = area
            self.isBlockAction = isBlockAction
        }
    }

    /// Item family, used only for the zero-signal tie-break that preserves the
    /// pre-CK feel (agents → actions → profiles) when nothing else discriminates.
    public enum Kind: Int, Sendable {
        case agentSession = 0
        case action = 1
        case profile = 2
    }

    /// Live app state that nudges ordering. All `false` when unknown so a cold
    /// launch with no history simply ranks by the (empty) frecency map and the
    /// stable tie-break. Each flag maps to one additive `contextBoostUnit`.
    public struct PaletteContext: Sendable {
        /// The active session sits inside a git repo → float `.git` actions.
        public let gitRootPresent: Bool
        /// A terminal command block is selected → float block actions.
        public let blockSelected: Bool
        /// At least one agent session is live → float agent items + `.ai` actions.
        public let hasLiveAgents: Bool

        public init(
            gitRootPresent: Bool = false,
            blockSelected: Bool = false,
            hasLiveAgents: Bool = false
        ) {
            self.gitRootPresent = gitRootPresent
            self.blockSelected = blockSelected
            self.hasLiveAgents = hasLiveAgents
        }
    }

    /// A ranked candidate: its `id`, plus title match-ranges (Character offsets
    /// into `title`, merged & sorted) for the row's highlighted glyph runs.
    public struct Ranked: Equatable, Sendable {
        public let id: String
        public let titleRanges: [Range<Int>]

        public init(id: String, titleRanges: [Range<Int>]) {
            self.id = id
            self.titleRanges = titleRanges
        }
    }

    // MARK: - Tuning

    /// Frecency weight. FuzzyMatcher scores land in the tens-to-~120 range;
    /// frecency is `count × decay` (~1–10). `6` makes a few real acceptances
    /// matter (≈ one boundary/contiguity bonus) without ever overpowering a
    /// prefix/exact title match.
    static let frecencyWeight = 6.0

    /// One context boost. Deliberately small (≈ a single matched character) so
    /// it re-orders near-ties but never lifts a weak match over a strong one.
    static let contextBoostUnit = 5.0

    /// Tie-break nudge keeping agents as the top resume targets (the pre-CK
    /// `agentItems + …` concat, re-expressed as a signal so it survives the move
    /// to one feed). Smaller than a context boost: it only breaks true ties.
    static let agentResumeBoost = 1.0

    // MARK: - Ranking

    /// Rank `candidates` for `query` under `context`, using `frecency` (id →
    /// decayed score, e.g. `PaletteFrecencyStore.scores(now:)`).
    ///
    /// When `query` is non-empty the feed is **filtered** to candidates whose
    /// every whitespace token matches at least one field (today's behavior),
    /// then ordered by the blended score. When `query` is empty nothing is
    /// filtered and order is frecency + context only, with the stable
    /// kind/title tie-break.
    public static func rank(
        candidates: [Candidate],
        query: String,
        frecency: [String: Double],
        context: PaletteContext
    ) -> [Ranked] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = trimmed.split(whereSeparator: { $0 == " " }).map(String.init)

        var scored: [(candidate: Candidate, total: Double, titleRanges: [Range<Int>])] = []
        scored.reserveCapacity(candidates.count)

        for candidate in candidates {
            var fuzzy = 0.0
            if !tokens.isEmpty {
                // Filter: every token must match some field (best-field-wins),
                // exactly as the prior per-kind rankers did.
                guard let score = FuzzyMatcher.score(
                    query: trimmed,
                    againstAnyOf: candidate.fields,
                    preferredFieldIndex: candidate.preferredFieldIndex
                ) else { continue }
                fuzzy = score
            }

            let freq = (frecency[candidate.id] ?? 0) * frecencyWeight
            let boost = contextBoost(for: candidate, context: context)
                + (candidate.kind == .agentSession ? agentResumeBoost : 0)
            let total = fuzzy + freq + boost

            scored.append((candidate, total, titleRanges(for: candidate, tokens: tokens)))
        }

        return scored.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.total != rhs.element.total { return lhs.element.total > rhs.element.total }
                // Stable zero-signal tie-break: preserve the pre-CK family order
                // (agents → actions → profiles) …
                if lhs.element.candidate.kind.rawValue != rhs.element.candidate.kind.rawValue {
                    return lhs.element.candidate.kind.rawValue < rhs.element.candidate.kind.rawValue
                }
                // … then the caller's supplied order within a kind, so the
                // waiting-first agent order and the catalog action order survive
                // the move to one feed (input index is a stable, faithful key).
                return lhs.offset < rhs.offset
            }
            .map { Ranked(id: $0.element.candidate.id, titleRanges: $0.element.titleRanges) }
    }

    /// Sum of context nudges applicable to one candidate. Each boost is additive
    /// and small; an item can earn more than one (e.g. a git action whose cwd
    /// also matches).
    static func contextBoost(for candidate: Candidate, context: PaletteContext) -> Double {
        var boost = 0.0
        if context.gitRootPresent, candidate.area == "git" {
            boost += contextBoostUnit
        }
        if context.blockSelected, candidate.isBlockAction {
            boost += contextBoostUnit
        }
        if context.hasLiveAgents, candidate.kind == .agentSession || candidate.area == "ai" {
            boost += contextBoostUnit
        }
        return boost
    }

    /// Union of per-token subsequence matches against the **title only**
    /// (`score(againstAnyOf:)` is best-field-wins, so a token may have matched a
    /// keyword, not the visible title — for highlighting we only ever underline
    /// the title). Returns merged, sorted Character-offset ranges; empty when no
    /// token lands on the title (the match was keyword-only).
    static func titleRanges(for candidate: Candidate, tokens: [String]) -> [Range<Int>] {
        guard !tokens.isEmpty else { return [] }
        var indices = Set<Int>()
        for token in tokens {
            guard let match = FuzzyMatcher.match(token, in: candidate.title) else { continue }
            for range in match.ranges {
                for i in range { indices.insert(i) }
            }
        }
        return mergeIndices(indices.sorted())
    }

    /// Collapse sorted, unique indices into half-open ranges.
    private static func mergeIndices(_ sorted: [Int]) -> [Range<Int>] {
        guard let first = sorted.first else { return [] }
        var ranges: [Range<Int>] = []
        var start = first
        var end = first + 1
        for index in sorted.dropFirst() {
            if index == end {
                end += 1
            } else {
                ranges.append(start..<end)
                start = index
                end = index + 1
            }
        }
        ranges.append(start..<end)
        return ranges
    }
}
