import Foundation

/// CK-S4 — the ⌘K **Action Panel** data model + a PURE resolver.
///
/// Raycast's Action Panel (⌘K/→ on a result → contextual *secondary* actions
/// with inline hotkeys and sub-menus) is the mechanism that elevates the palette
/// to a true "primary interface" (P2) — and on Termy's *live, local* cockpit
/// objects (an SSH/RDP profile, a running CLI agent) it is the one differentiator
/// no generic launcher can copy. This slice is the data layer only: the value
/// types plus the resolver that, given a palette item and the live context that
/// already rides on its payload, yields the contextual secondary set. No UI, no
/// store, no SwiftUI — so it unit-tests purely.
///
/// **Wiring contract (handler ids).** A `SecondaryAction` carries a stable
/// `handlerID` string, not a closure. The S5 dispatch site (which holds the
/// originating item and so its UUID/profile) maps the id to an existing
/// `TermyStore` method — `openConnection`, `openSFTPSession`, `openLocalTunnel`,
/// `selectConnectionProfileForEditing`, `focusAgentSession`, `interruptAgent`,
/// `restartAgent`, `sendSteeringInstruction`, the `close-session` command, etc.
/// Every id emitted here has a real destination today; `set-alias` is the one
/// forward-pointing seam (S8 wires iCloud-synced aliases) and is emitted only
/// because that slice will consume it.
///
/// **B4 (no headless auto-execute).** B4 forbids *headless* execution, not an
/// explicit user choice. Selecting an Action Panel row is a foreground user
/// action, so `agent.steer` legitimately maps to the steering store method
/// (`sendSteeringInstruction`) — which is itself already B4-safe (it only sends
/// on an explicit call and honestly no-ops, keeping the comments, when nothing
/// composes). `agent.review` is the distinct sibling that opens the diff-review
/// surface (focus + the review card) for composing comments. The Action Panel
/// offers both; it never auto-runs a turn on its own.

// MARK: - Value types

/// One secondary action in the ⌘K Action Panel.
public struct SecondaryAction: Sendable, Equatable, Identifiable {
    /// Stable id the dispatch site maps to a store method. Also the `Identifiable`
    /// id, so SwiftUI `ForEach`/keyboard selection has a stable key.
    public let handlerID: String
    /// Human-facing label shown in the panel row.
    public let title: String
    /// Optional inline hotkey hint (e.g. `⌘↵`, `⌃X`) rendered on the trailing
    /// edge of the row. Purely descriptive — actual key handling lives in the UI.
    public let inlineHotkey: String?
    /// Optional sub-menu. A non-empty `children` array makes this row a submenu
    /// parent (Raycast pattern: ⌘K on it expands the nested set) rather than a
    /// leaf that performs `handlerID`.
    public let children: [SecondaryAction]
    /// True when this action is destructive (close / delete) so the UI can style
    /// it (and, at the dispatch site, confirm) accordingly.
    public let isDestructive: Bool

    public var id: String { handlerID }

    public init(
        handlerID: String,
        title: String,
        inlineHotkey: String? = nil,
        children: [SecondaryAction] = [],
        isDestructive: Bool = false
    ) {
        self.handlerID = handlerID
        self.title = title
        self.inlineHotkey = inlineHotkey
        self.children = children
        self.isDestructive = isDestructive
    }
}

/// The palette object an Action Panel is resolved for. Mirrors the app target's
/// `CommandCenterItem` cases, but holds only the TermyCore payload types so the
/// resolver lives — and tests — in TermyCore. The app maps `CommandCenterItem`
/// onto this in the S5 dispatch site.
public enum ActionPanelTarget: Sendable, Equatable {
    case action(CommandAction)
    case profile(ConnectionProfile)
    case agentSession(AgentSessionVitals)
}

// MARK: - Resolver

/// Pure, context-scaled resolver. The "live store context" the slice calls for
/// already rides on each payload — `profile.kind` decides Connect/SFTP/Tunnel/
/// Edit; `vitals.state` decides which agent lifecycle actions are live — so no
/// separate context struct is needed (it would be dead fields against the lean
/// constraint). The first element is always the *primary* action (what ↵ does);
/// the rest are the contextual secondaries (what ⌘K/→ reveals).
public enum ActionPanelResolver {
    public static func resolve(_ target: ActionPanelTarget) -> [SecondaryAction] {
        switch target {
        case .action(let action):
            return resolveAction(action)
        case .profile(let profile):
            return resolveProfile(profile)
        case .agentSession(let vitals):
            return resolveAgent(vitals)
        }
    }

    // MARK: action

    /// A plain command: primary = run it; secondaries = copy its id (handy for
    /// scripting/aliasing) + set a strict-prefix alias (S8 seam).
    private static func resolveAction(_ action: CommandAction) -> [SecondaryAction] {
        [
            SecondaryAction(
                handlerID: "action.perform:\(action.id)",
                title: action.title,
                inlineHotkey: "↵"
            ),
            SecondaryAction(
                handlerID: "action.copy-id:\(action.id)",
                title: "Copy Command ID"
            ),
            SecondaryAction(
                handlerID: "action.set-alias:\(action.id)",
                title: "Set Alias…"
            )
        ]
    }

    // MARK: profile

    /// A saved connection. Connect + Edit apply to every kind; SFTP and Tunnel
    /// are SSH-only (no SFTP/port-forward surface for RDP or a local shell).
    /// Mirrors the store seams `openConnection` / `openSFTPSession` /
    /// `openLocalTunnel` / `selectConnectionProfileForEditing`.
    private static func resolveProfile(_ profile: ConnectionProfile) -> [SecondaryAction] {
        let id = profile.id.uuidString
        var actions: [SecondaryAction] = [
            SecondaryAction(
                handlerID: "profile.connect:\(id)",
                title: "Connect",
                inlineHotkey: "↵"
            )
        ]
        if profile.kind == .ssh {
            actions.append(SecondaryAction(
                handlerID: "profile.sftp:\(id)",
                title: "Open SFTP"
            ))
            actions.append(SecondaryAction(
                handlerID: "profile.tunnel:\(id)",
                title: "Open Tunnel"
            ))
        }
        // A local shell profile is not an editable connection record; only saved
        // SSH/RDP profiles route to the Connections editor.
        if profile.kind == .ssh || profile.kind == .rdp {
            actions.append(SecondaryAction(
                handlerID: "profile.edit:\(id)",
                title: "Edit Profile…"
            ))
        }
        return actions
    }

    // MARK: agentSession

    /// A live (or recently-exited) CLI agent — the moat. Focus + Close always
    /// apply. Interrupt / Restart / Steer require a live process (the store's
    /// `interruptAgent` / `restartAgent` / `sendSteeringInstruction` and
    /// `selectedSessionIsLiveAgent` all gate on `state != .exited`), so an exited
    /// agent resolves to Focus + Close only — never an action that would no-op.
    ///
    /// AD-5: `steer` lands here as a secondary action and is the deferred
    /// steer-from-⌘K seam — its handler maps to the steering store method
    /// (`sendSteeringInstruction`), which is explicit-send + honest-no-op, so it
    /// is B4-safe. `review` is the distinct sibling that opens the diff-review
    /// surface (focus + review card) where the user composes the comments a steer
    /// sends. (How S5 lets the user supply an instruction from the palette —
    /// inline input vs. focus-then-compose — is an S5/UX call, not S4's.)
    private static func resolveAgent(_ vitals: AgentSessionVitals) -> [SecondaryAction] {
        let id = vitals.id.uuidString
        var actions: [SecondaryAction] = [
            SecondaryAction(
                handlerID: "agent.focus:\(id)",
                title: "Focus Agent",
                inlineHotkey: "↵"
            )
        ]
        let isLive = vitals.state != .exited
        if isLive {
            actions.append(SecondaryAction(
                handlerID: "agent.interrupt:\(id)",
                title: "Interrupt",
                inlineHotkey: "⌃C"
            ))
            actions.append(SecondaryAction(
                handlerID: "agent.restart:\(id)",
                title: "Restart"
            ))
            actions.append(SecondaryAction(
                handlerID: "agent.review:\(id)",
                title: "Review Diff…"
            ))
            actions.append(SecondaryAction(
                handlerID: "agent.steer:\(id)",
                title: "Steer…"
            ))
        }
        actions.append(SecondaryAction(
            handlerID: "agent.close:\(id)",
            title: "Close Session",
            isDestructive: true
        ))
        return actions
    }
}
