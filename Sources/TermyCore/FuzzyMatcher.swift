import Foundation

/// A single subsequence match of a query against a candidate string.
///
/// `ranges` are half-open `Character`-offset ranges into the *candidate*
/// (not UTF-16 / not `String.Index`), merged and sorted ascending, suitable
/// for driving highlight runs in a later UI slice. Character offsets are
/// trivially testable and convert cleanly to `NSRange` when AppKit needs them.
public struct FuzzyMatch: Equatable, Sendable {
    /// Higher is a better match. `Double` so a later slice can blend this with
    /// exp-decay frecency without re-typing.
    public let score: Double
    /// Matched character offsets into the candidate, merged and sorted.
    public let ranges: [Range<Int>]

    public init(score: Double, ranges: [Range<Int>]) {
        self.score = score
        self.ranges = ranges
    }
}

/// Dependency-free subsequence fuzzy matcher shared by ⌘K (command actions,
/// connection profiles, agent sessions) and — later — the editor ⌘P quick-open.
///
/// The matcher is a stateless primitive over a single `(query, candidate)`
/// pair: callers adapt their own fields to strings and pick the best field.
/// It never takes app types, so it stays general and `Sendable`.
///
/// Scoring favours, in order: an exact match, a full prefix, contiguous runs,
/// matches on a word/camelCase boundary, and a leading-character match;
/// gaps between matched characters are penalised. Matching is
/// case-insensitive; ranges are reported against the original candidate.
public enum FuzzyMatcher {
    // Tuned to satisfy the named behavioural tests (msg→Messages,
    // contiguous beats scattered, prefix beats mid-word). Keep these as the
    // only scoring dimensions — frecency/context blending lives elsewhere.
    private static let matchBonus = 16.0
    private static let contiguousBonus = 18.0
    private static let boundaryBonus = 12.0
    private static let leadingBonus = 10.0
    private static let prefixBonus = 24.0
    private static let exactBonus = 60.0
    private static let gapPenalty = 3.0
    private static let leadingGapPenalty = 1.0

    /// Returns a match if every character of `query` appears in `candidate` in
    /// order (a subsequence), else `nil`. An empty query matches with score `0`
    /// and no ranges.
    public static func match(_ query: String, in candidate: String) -> FuzzyMatch? {
        let q = Array(query.lowercased())
        guard !q.isEmpty else { return FuzzyMatch(score: 0, ranges: []) }

        let originalChars = Array(candidate)
        let lowerChars = originalChars.map { Character($0.lowercased()) }
        guard !lowerChars.isEmpty else { return nil }

        // Greedy left-to-right subsequence walk. For each query character take
        // the earliest candidate position at or after the previous match. This
        // is the standard fuzzy-finder heuristic; it favours earlier (more
        // prefix-like, more contiguous) matches.
        var matchedIndices: [Int] = []
        matchedIndices.reserveCapacity(q.count)
        var cursor = 0
        for qChar in q {
            var found = false
            while cursor < lowerChars.count {
                if lowerChars[cursor] == qChar {
                    matchedIndices.append(cursor)
                    cursor += 1
                    found = true
                    break
                }
                cursor += 1
            }
            if !found { return nil }
        }

        let score = score(
            query: q,
            matchedIndices: matchedIndices,
            originalChars: originalChars,
            lowerChars: lowerChars
        )
        return FuzzyMatch(score: score, ranges: mergedRanges(matchedIndices))
    }

    private static func score(
        query: [Character],
        matchedIndices: [Int],
        originalChars: [Character],
        lowerChars: [Character]
    ) -> Double {
        var total = 0.0
        var previous: Int? = nil

        for index in matchedIndices {
            total += matchBonus

            if let previous {
                let gap = index - previous - 1
                if gap == 0 {
                    total += contiguousBonus
                } else {
                    // Penalise distance; never let a gap push a real match
                    // below zero contribution for that character.
                    total -= min(Double(gap) * gapPenalty, matchBonus)
                }
            } else {
                // Leading gap before the first matched character — a smaller
                // penalty so "mid-word" matches still rank below prefixes.
                total -= Double(index) * leadingGapPenalty
            }

            if index == 0 {
                total += leadingBonus
            }
            if isBoundary(at: index, original: originalChars, lower: lowerChars) {
                total += boundaryBonus
            }

            previous = index
        }

        // Whole-candidate exact match (case-insensitive).
        if query.count == lowerChars.count {
            total += exactBonus
        } else if matchedIndices.first == 0,
                  matchedIndices == Array(0..<query.count) {
            // Contiguous run anchored at the start → a true prefix.
            total += prefixBonus
        }

        return total
    }

    /// A candidate position is a word/camelCase boundary when it is the first
    /// character, follows a separator (space/`-`/`_`/`.`/`/`), or is an
    /// uppercase letter following a lowercase one (camelCase hump).
    private static func isBoundary(at index: Int, original: [Character], lower: [Character]) -> Bool {
        guard index > 0 else { return true }
        let prev = original[index - 1]
        if prev == " " || prev == "-" || prev == "_" || prev == "." || prev == "/" {
            return true
        }
        let current = original[index]
        if current.isUppercase, prev.isLowercase {
            return true
        }
        return false
    }

    /// Collapse adjacent matched indices into half-open ranges, sorted ascending.
    private static func mergedRanges(_ indices: [Int]) -> [Range<Int>] {
        guard let first = indices.first else { return [] }
        var ranges: [Range<Int>] = []
        var start = first
        var end = first + 1
        for index in indices.dropFirst() {
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
