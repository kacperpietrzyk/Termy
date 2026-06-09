import Foundation

public struct CommandRegistry: Sendable {
    public let actions: [CommandAction]

    public init(actions: [CommandAction]) {
        self.actions = actions
    }

    public func search(_ query: String) -> [CommandAction] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return actions }

        return actions
            .compactMap { action -> (CommandAction, Double)? in
                // Best-field-wins, per-field subsequence (never the joined blob,
                // which would let one query character match across unrelated
                // fields and produce meaningless ranges). The display field
                // (title) is weighted highest so on-screen matches rank above
                // keyword-only ones.
                let fields = [action.id, action.title, action.subtitle] + action.keywords
                guard let score = FuzzyMatcher.score(query: normalizedQuery,
                                                      againstAnyOf: fields,
                                                      preferredFieldIndex: 1) else {
                    return nil
                }
                return (action, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.title < rhs.0.title
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }
}

extension FuzzyMatcher {
    /// Multi-token, multi-field scorer shared by ⌘K item kinds (command
    /// actions, connection profiles, agent sessions). The query is split on
    /// whitespace; every token must match (subsequence) at least one field, so
    /// "ai error" still finds an action whose keywords hold both. The returned
    /// score is the sum of each token's best-field score, with a small bonus
    /// for tokens that land on the preferred (display) field.
    ///
    /// Returns `nil` when any token matches no field (the candidate is filtered
    /// out), or when the trimmed query is empty (callers treat empty as "all").
    public static func score(
        query: String,
        againstAnyOf fields: [String],
        preferredFieldIndex: Int = 0
    ) -> Double? {
        let tokens = query.split(whereSeparator: { $0 == " " }).map(String.init)
        guard !tokens.isEmpty else { return nil }

        var total = 0.0
        for token in tokens {
            var best: Double? = nil
            for (fieldIndex, field) in fields.enumerated() {
                guard let match = match(token, in: field) else { continue }
                let weighted = fieldIndex == preferredFieldIndex
                    ? match.score + preferredFieldBonus
                    : match.score
                if best == nil || weighted > best! {
                    best = weighted
                }
            }
            guard let best else { return nil }
            total += best
        }
        return total
    }

    /// Bonus added when a token's best match lands on the caller's display
    /// field, so an on-screen title hit outranks an invisible keyword hit.
    private static var preferredFieldBonus: Double { 8.0 }
}
