import SwiftUI
import TermyCore

enum TermyDesign {
    static let cornerRadius: CGFloat = DesignTokens.Radius.md
    static let controlRadius: CGFloat = DesignTokens.Radius.sm

    static var appBackground: Color { Color(DesignTokens.bg0) }
    static var stageBackground: Color { Color(DesignTokens.bg0) }
    static var surface: Color { Color(DesignTokens.bg1) }
    static var elevatedSurface: Color { Color(DesignTokens.bg2) }
    static var border: Color { Color(DesignTokens.hair2) }
    static var subtleBorder: Color { Color(DesignTokens.hair) }
    static var accent: Color { Color(DesignTokens.primary) }

    /// Product area → status hue (OKLCH). DESIGN.md §3.2 / §6.
    static func areaToken(_ area: ProductArea) -> OKLCH {
        switch area {
        case .terminal:      return DesignTokens.neutral.base
        case .commandCenter: return DesignTokens.primary
        case .ai:            return DesignTokens.ai.base
        case .files:         return DesignTokens.neutral.base
        case .git:           return DesignTokens.git.base
        case .editor:        return DesignTokens.ai.base
        case .ssh:           return DesignTokens.host.base
        case .rdp:           return DesignTokens.host.base
        case .sync:          return DesignTokens.sync.base
        }
    }

    static func areaColor(_ area: ProductArea) -> Color { Color(areaToken(area)) }

    /// Agent activity → live-chip hue (OKLCH). DESIGN.md §5.6.
    static func activityToken(_ state: AgentActivityState) -> OKLCH {
        switch state {
        case .working:         return DesignTokens.sync.base
        case .idle:            return DesignTokens.fg3
        case .waitingForInput: return DesignTokens.agent.base
        case .exited:          return DesignTokens.fg5
        }
    }

    static func agentActivityColor(_ state: AgentActivityState) -> Color { Color(activityToken(state)) }
}

struct TermyIconButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(emphasized ? Color.white : Color(DesignTokens.fg2))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(emphasized ? Color(DesignTokens.primary) : Color(DesignTokens.bg2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(emphasized ? Color.clear : Color(DesignTokens.hair2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct TermyCommandButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.ui(13, weight: .medium))
            .foregroundStyle(emphasized ? Color.white : Color(DesignTokens.fg1))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(emphasized
                          ? LinearGradient(colors: [Color(DesignTokens.primary), Color(DesignTokens.primary2)],
                                           startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color(DesignTokens.bg2)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(emphasized ? Color.clear : Color(DesignTokens.hair2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DesignTokens.Motion.easeOut, value: configuration.isPressed)
    }
}

/// Chip / pill (DESIGN.md §5.4): bg3 + hair2, mono 11, optional hue tint.
struct TermyPill: View {
    let title: String
    var systemImage: String?
    var tint: Color = Color(DesignTokens.fg2)

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            }
            Text(title).lineLimit(1)
        }
        .font(Typography.mono(11))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(DesignTokens.bg3), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(Color(DesignTokens.hair2), lineWidth: 1)
        )
    }
}

/// Keyboard-hint chip (`styles.css` `.btn kbd` / `.sub-rail-search kbd`): dark
/// bg0 fill, fg3 glyph, hair border, radius 4. Same on emphasized buttons —
/// the handoff uses one kbd treatment everywhere.
struct TermyKbd: View {
    let key: String
    var size: CGFloat = 11
    init(_ key: String, size: CGFloat = 11) { self.key = key; self.size = size }

    var body: some View {
        Text(key)
            .font(Typography.ui(size, weight: .medium))
            .foregroundStyle(Color(DesignTokens.fg3))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color(DesignTokens.bg0), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(DesignTokens.hair), lineWidth: 1))
    }
}

struct TermySectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 15)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.ui(11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color(DesignTokens.fg4))
                    .tracking(0.5)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.mono(11))
                        .foregroundStyle(Color(DesignTokens.fg3))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }
}

/// Card (DESIGN.md §5.2/§5.3): bg1 + hair + radius 14, top sheen, hue edge on hover.
struct TermyCard<Content: View>: View {
    var hue: OKLCH = DesignTokens.neutral.edge
    @ViewBuilder var content: () -> Content
    @State private var hovering = false

    var body: some View {
        content()
            .padding(16)
            .background(Color(DesignTokens.bg1), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(hovering ? Color(hue).opacity(0.6) : Color(DesignTokens.hair), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                LinearGradient(colors: [Color(DesignTokens.fg1).opacity(0.06), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            }
            .shadow(color: hovering ? Color(hue).opacity(0.18) : DesignTokens.Shadow.cardColor,
                    radius: DesignTokens.Shadow.cardRadius, y: DesignTokens.Shadow.cardY)
            .onHover { hovering = $0 }
            .animation(DesignTokens.Motion.easeOutSnappy, value: hovering)
    }
}

/// Detail card (DESIGN.md §5.3): bg1 + hair + radius 10, uppercase header with
/// optional trailing mono meta, arbitrary content. Shared across modules.
struct TermyDetailCard<Content: View>: View {
    let title: String
    var trailing: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 11)).foregroundStyle(Color(DesignTokens.fg4))
                }
                Text(title.uppercased()).font(Typography.ui(10.5, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(Color(DesignTokens.fg4))
                Spacer()
                if let trailing {
                    Text(trailing).font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg3))
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(DesignTokens.bg1), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .stroke(Color(DesignTokens.hair), lineWidth: 1))
    }
}

/// Status dot (DESIGN.md §4.2): 7×7 hue dot with glow.
struct TermyStatusDot: View {
    var hue: OKLCH
    var pulsing = false
    @State private var on = false

    private var pulseAnimation: Animation {
        .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    }

    var body: some View {
        Circle()
            .fill(Color(hue))
            .frame(width: 7, height: 7)
            .shadow(color: Color(hue).opacity(0.8), radius: 4)
            .opacity(on ? 0.4 : 1)
            .onAppear { updatePulse(pulsing) }
            .onChange(of: pulsing) { _, newValue in updatePulse(newValue) }
    }

    /// Start the infinite pulse when active; settle back to full opacity when not.
    private func updatePulse(_ active: Bool) {
        if active {
            withAnimation(pulseAnimation) { on = true }
        } else {
            withAnimation(.default) { on = false }
        }
    }
}

/// Live chip in an h2 header (DESIGN.md §5.6): hue dot + label, waiting pulses.
struct TermyLiveChip: View {
    enum State { case waiting, running, idle
        var pulses: Bool { self == .waiting }
        var label: String {
            switch self { case .waiting: return "waiting"; case .running: return "running"; case .idle: return "idle" }
        }
    }
    let state: State

    static func hue(for state: State) -> OKLCH {
        switch state {
        case .waiting: return DesignTokens.agent.base
        case .running: return DesignTokens.sync.base
        case .idle:    return DesignTokens.fg3
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            TermyStatusDot(hue: Self.hue(for: state), pulsing: state.pulses)
            Text(state.label).font(Typography.mono(12, weight: .medium))
        }
        .foregroundStyle(Color(Self.hue(for: state)))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }
}

extension OverlayPanel {
    var subtitle: String {
        switch self {
        case .ai:
            return "Local models and external CLI agents"
        case .files:
            return "Local files and SFTP transfers"
        case .git:
            return "Status, diffs, branches, and commits"
        case .editor:
            return "Lightweight code edits beside the terminal"
        case .connections:
            return "SSH, tunnels, keys, and RDP profiles"
        }
    }
}

extension CommandCenterItem {
    var area: ProductArea {
        switch self {
        case .action(let action):
            return action.area
        case .profile(let profile):
            switch profile.kind {
            case .local:
                return .terminal
            case .ssh:
                return .ssh
            case .rdp:
                return .rdp
            }
        case .agentSession:
            return .ai
        }
    }
}
