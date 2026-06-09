import Foundation

/// CK-S6: the actionable fallbacks shown in the ⌘K palette when the scoped feed
/// is empty — replacing the dead `ContentUnavailableView`. Each case is a *real*
/// handler the store dispatches; the associated `input` is the parsed prefix
/// remainder (what the user typed minus any sigil).
///
/// B4 (AI offers, never takes over): `askLocalAI` opens an interactive surface
/// seeded with the input for conscious acceptance — it never auto-executes a
/// model request. `runInSession` runs the user's *own* typed command (their
/// explicit intent, not AI), so it submits directly. `sshTo` seeds the
/// Connections draft (the live launch is S7 territory), and `searchScrollback`
/// opens the find toolbar pre-filled.
public enum PaletteFallback: Equatable, Identifiable, Sendable {
    case runInSession(String)
    case askLocalAI(String)
    case sshTo(String)
    case searchScrollback(String)

    public var id: String {
        switch self {
        case .runInSession: return "fallback-run"
        case .askLocalAI: return "fallback-ai"
        case .sshTo: return "fallback-ssh"
        case .searchScrollback: return "fallback-search"
        }
    }

    /// The user-typed input this fallback acts on (empty allowed for the AI/SSH
    /// "open the surface" cases).
    public var input: String {
        switch self {
        case .runInSession(let s), .askLocalAI(let s),
             .sshTo(let s), .searchScrollback(let s):
            return s
        }
    }

    public var title: String {
        switch self {
        case .runInSession(let s):
            return s.isEmpty ? "Run in session" : "Run \"\(s)\" in session"
        case .askLocalAI(let s):
            return s.isEmpty ? "Ask local AI" : "Ask local AI: \(s)"
        case .sshTo(let s):
            return s.isEmpty ? "SSH to a host" : "SSH to \(s)"
        case .searchScrollback(let s):
            return s.isEmpty ? "Search scrollback" : "Search scrollback for \"\(s)\""
        }
    }

    public var subtitle: String {
        switch self {
        case .runInSession:
            return "Submit this command to the active terminal"
        case .askLocalAI:
            return "Open the offline assistant seeded with your text"
        case .sshTo:
            return "Start a new SSH connection in Connections"
        case .searchScrollback:
            return "Find this text in the terminal scrollback"
        }
    }

    public var systemImage: String {
        switch self {
        case .runInSession: return "terminal"
        case .askLocalAI: return "cpu"
        case .sshTo: return "network"
        case .searchScrollback: return "magnifyingglass"
        }
    }

    /// Build the ordered fallback list for a parsed prefix. The remainder seeds
    /// each row; ordering puts the most-likely intent first:
    ///   - In `.commands`/`.all` scope, a non-empty remainder leads with
    ///     "Run …" (a typed command) then AI/SSH/search.
    ///   - In `.sessions` scope, "SSH to <host>" leads.
    ///   - In `.settings`/`.help` scope, no command/SSH fallbacks make sense, so
    ///     only "Ask local AI" + "Search scrollback" are offered.
    ///   - A bare-sigil prefix never reaches here (callers show in-scope items).
    public static func suggestions(
        for prefix: PalettePrefix
    ) -> [PaletteFallback] {
        let input = prefix.remainder
        switch prefix.scope {
        case .all, .commands:
            return [
                .runInSession(input),
                .askLocalAI(input),
                .sshTo(input),
                .searchScrollback(input)
            ]
        case .sessions:
            return [
                .sshTo(input),
                .runInSession(input),
                .searchScrollback(input)
            ]
        case .settings, .help:
            return [
                .askLocalAI(input),
                .searchScrollback(input)
            ]
        }
    }
}
