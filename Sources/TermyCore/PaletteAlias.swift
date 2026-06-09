import Foundation

/// CK-S8: a user-defined **strict-prefix alias** for the ⌘K command palette.
///
/// An alias maps a short literal `prefix` (e.g. `gs`, `d`) to a freeform
/// `expansion` (e.g. `git status`, `Connect SSH`). Unlike the fuzzy matcher the
/// palette uses for everything else, an alias resolves on an **exact** literal
/// match of the (trimmed, sigil-stripped) query against `prefix` — so typing the
/// alias jumps straight to its target, ahead of fuzzy ranking. The store layers
/// the target→item mapping (action / profile / shell command) on top of this
/// pure resolution; this type carries no app or sync knowledge.
///
/// Shape mirrors `UserPromptSnippet` exactly (id + two freeform string fields) so
/// it rides the existing private-sync planner with no new transport. **Privacy
/// (P1):** aliases are local config; the only place they travel is the user's own
/// CloudKit private DB via the existing planner.
public struct PaletteAlias: Equatable, Identifiable, Sendable {
    public let id: String
    /// The literal prefix the user types (matched exactly, never fuzzily).
    public let prefix: String
    /// The freeform target — an action title/id, a connection profile name, or a
    /// shell command. The store decides which at resolution time.
    public let expansion: String

    public init(id: String, prefix: String, expansion: String) {
        self.id = id
        self.prefix = prefix
        self.expansion = expansion
    }
}

public struct PaletteAliasTable: Equatable, Sendable {
    public let aliases: [PaletteAlias]

    public init(aliases: [PaletteAlias]) {
        self.aliases = aliases
    }

    /// Aliases with both fields non-blank. `public` so the sync layer can map
    /// them across the `TermySync` boundary without `PaletteAliasTable` carrying
    /// sync-DTO knowledge (symmetric with `UserPromptSnippetLibrary`).
    public func activeAliases() -> [PaletteAlias] {
        aliases.filter {
            !$0.prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.expansion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// The alias whose `prefix` **exactly equals** the query (both trimmed,
    /// case-insensitive), or nil. Strict by design: `gs` matches only `gs`, never
    /// `gst`/`gstatus` — so a user can always type *past* an alias. Blank
    /// aliases never resolve. When two aliases share a prefix (shouldn't happen —
    /// the editor de-dupes), the first active one wins for stability.
    public func resolve(query: String) -> PaletteAlias? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return activeAliases().first {
            $0.prefix.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }
}
