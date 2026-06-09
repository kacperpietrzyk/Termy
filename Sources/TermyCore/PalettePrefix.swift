import Foundation

/// CK-S6: pure parser for the ⌘K palette's leading-sigil "prefix modes".
///
/// A single leading sigil scopes the result feed to one kind of object; the
/// remainder of the query is what the ranker fuzzy-matches *and* what seeds the
/// empty-state fallbacks (e.g. "SSH to <remainder>"). The parse is intentionally
/// dependency-free and side-effect-free so it can be exhaustively unit-tested:
/// the store layers scope-filtering + fallback building on top of this result.
///
/// Sigils (must be the first non-space character):
///   `>` commands/actions     `@` sessions + profiles + agents
///   `:` settings             `?` help / shortcut cheat-sheet
///
/// Anything else (including a sigil that appears mid-query) is treated as plain
/// text with no scope — there is no "unknown scope" state, so a stray `#` never
/// silently hides every result.
public struct PalettePrefix: Equatable, Sendable {
    public enum Scope: Equatable, Sendable {
        /// No sigil — every kind participates (the default, pre-CK behavior).
        case all
        /// `>` — command actions only.
        case commands
        /// `@` — sessions, connection profiles, and agents.
        case sessions
        /// `:` — settings / configuration actions.
        case settings
        /// `?` — help: the keyboard cheat-sheet (actions that carry a shortcut).
        case help

        /// The sigil character that selects this scope (nil for `.all`).
        public var sigil: Character? {
            switch self {
            case .all: return nil
            case .commands: return ">"
            case .sessions: return "@"
            case .settings: return ":"
            case .help: return "?"
            }
        }
    }

    /// The scope selected by the leading sigil (`.all` when none present).
    public let scope: Scope

    /// The query with the sigil stripped and re-trimmed — what callers fuzzy
    /// match and seed fallbacks from. Empty when only a bare sigil was typed.
    public let remainder: String

    public init(scope: Scope, remainder: String) {
        self.scope = scope
        self.remainder = remainder
    }

    /// Parse a raw palette query into a scope + remainder. Leading/trailing
    /// whitespace is ignored when locating the sigil; a bare sigil yields the
    /// scope with an empty remainder (callers show "all in scope", never the
    /// fallbacks). A non-sigil first character (or a sigil that is not first)
    /// parses as `.all` with the original trimmed query as remainder.
    public static func parse(_ rawQuery: String) -> PalettePrefix {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return PalettePrefix(scope: .all, remainder: "")
        }

        let scope: Scope
        switch first {
        case ">": scope = .commands
        case "@": scope = .sessions
        case ":": scope = .settings
        case "?": scope = .help
        default:
            return PalettePrefix(scope: .all, remainder: trimmed)
        }

        let rest = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        return PalettePrefix(scope: scope, remainder: rest)
    }

    /// True when only a bare sigil was typed (scope is set but nothing to match):
    /// callers show every in-scope item rather than the empty-state fallbacks.
    public var isBareSigil: Bool {
        scope != .all && remainder.isEmpty
    }

    // MARK: - Scope membership (pure, real-backed)

    /// Whether a candidate of the given `PaletteRanker.Kind` belongs in this
    /// scope. The `actionArea` / `actionID` are consulted only for action
    /// candidates, so the `:` settings scope can key off the action's real
    /// product area + id rather than a fabricated "setting" object.
    public func admits(
        kind: PaletteRanker.Kind,
        actionArea: String? = nil,
        actionID: String? = nil
    ) -> Bool {
        switch scope {
        case .all:
            return true
        case .commands:
            return kind == .action
        case .sessions:
            return kind == .agentSession || kind == .profile
        case .settings:
            guard kind == .action else { return false }
            return Self.isSettingsAction(area: actionArea, id: actionID)
        case .help:
            // `?` resolves in the store from the shortcut cheat-sheet set (only
            // actions that carry a shortcut); the store gates that directly, so
            // here we simply restrict to actions.
            return kind == .action
        }
    }

    /// The honest backing for the `:` settings scope: configuration-changing
    /// actions. These are the actions that persist or mutate app/appearance/
    /// layout state — keyed by real product area (`.sync` workspace/layout,
    /// `.commandCenter` pane/tile config) plus the terminal output-mode toggles.
    /// No fabricated "settings" rows are ever synthesized.
    public static func isSettingsAction(area: String?, id: String?) -> Bool {
        if let id, settingsActionIDs.contains(id) { return true }
        guard let area else { return false }
        return settingsAreas.contains(area)
    }

    /// Product areas whose actions are configuration/layout settings.
    static let settingsAreas: Set<String> = [
        ProductArea.sync.rawValue,
        ProductArea.commandCenter.rawValue
    ]

    /// Individual config-mutating actions outside the settings areas (terminal
    /// rendering preferences that are persisted + synced).
    static let settingsActionIDs: Set<String> = [
        "set-terminal-output-stream",
        "set-terminal-output-blocks"
    ]
}
