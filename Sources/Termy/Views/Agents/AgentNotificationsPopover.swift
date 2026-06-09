import SwiftUI
import TermyCore

/// AD-2 — the in-app notifications surface that complements the macOS banner.
/// Anchored to the sidebar Agents ring/badge, it lists every agent that needs
/// attention (waiting → finished → failed, waiting-first), each tagged by kind
/// with a per-type icon/color, and a click (or ↩ on the highlighted row) focuses
/// that agent via the same `focusAgentSession` deep-link the macOS banner click
/// uses. Keyboard-first (P2): the list takes focus on open, ↑/↓ move the
/// highlight, ↩ focuses the selected agent.
struct AgentNotificationsPopover: View {
    @ObservedObject var store: TermyStore
    /// Closes the popover after a focus action.
    let onFocus: () -> Void

    /// AD-2 keyboard nav: index of the highlighted row (P2 — popover is operable
    /// by ↑/↓ + ↩, not hover-only).
    @State private var selection: Int = 0
    @FocusState private var listFocused: Bool

    private var items: [AgentAttentionItem] { store.agentAttention }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(DesignTokens.Glass.hairline)
            if items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: 340)
        .background(Color(DesignTokens.bg2))
        .focusable(!items.isEmpty)
        .focusEffectDisabled()
        .focused($listFocused)
        .onAppear {
            selection = 0
            listFocused = true
        }
        .onMoveCommand { direction in
            guard !items.isEmpty else { return }
            switch direction {
            case .up:   selection = max(0, selection - 1)
            case .down: selection = min(items.count - 1, selection + 1)
            default:    break
            }
        }
        .onKeyPress(.return) {
            guard items.indices.contains(selection) else { return .ignored }
            focus(items[selection])
            return .handled
        }
    }

    private func focus(_ item: AgentAttentionItem) {
        store.focusAgentSession(item.id)
        onFocus()
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.badge")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(DesignTokens.agent.base))
            Text("Agents needing attention")
                .font(Typography.ui(12, weight: .semibold))
                .foregroundStyle(Color(DesignTokens.fg1))
            Spacer()
            if !items.isEmpty {
                Text("\(items.count)")
                    .font(Typography.mono(11, weight: .medium))
                    .foregroundStyle(Color(DesignTokens.fg4))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Color(DesignTokens.sync.base))
            Text("No agents are waiting.")
                .font(Typography.ui(12))
                .foregroundStyle(Color(DesignTokens.fg3))
        }
        .padding(.horizontal, 14).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    AgentNotificationRow(item: item, selected: index == selection) {
                        focus(item)
                    }
                }
            }
            .padding(6)
        }
        .frame(maxHeight: 320)
        .onChange(of: items.count) { _, newCount in
            selection = min(selection, max(0, newCount - 1))
        }
    }
}

/// One attention row: per-type icon/color · name · type · branch + kind label.
private struct AgentNotificationRow: View {
    let item: AgentAttentionItem
    let selected: Bool
    let onFocus: () -> Void
    @State private var hovering = false

    private var tint: Color {
        switch item.kind {
        case .waitingForInput: return Color(DesignTokens.agent.base)
        case .exited:          return Color(DesignTokens.fg3)
        case .error:           return Color(DesignTokens.error.base)
        }
    }

    private var icon: String {
        switch item.kind {
        case .waitingForInput: return "hand.raised"
        case .exited:          return "checkmark.circle"
        case .error:           return "exclamationmark.triangle"
        }
    }

    private var kindLabel: String {
        switch item.kind {
        case .waitingForInput: return "waiting for input"
        case .exited:          return "finished"
        case .error:           return "failed"
        }
    }

    var body: some View {
        Button(action: onFocus) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(item.vitals.name)
                            .font(Typography.ui(13, weight: .medium))
                            .foregroundStyle(Color(DesignTokens.fg1))
                            .lineLimit(1)
                        Text(item.vitals.agentType.displayName.lowercased())
                            .font(Typography.mono(10))
                            .foregroundStyle(Color(DesignTokens.fg4))
                    }
                    Text(kindLabel)
                        .font(Typography.mono(11))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let branch = item.vitals.branch, !branch.isEmpty {
                    Text(branch)
                        .font(Typography.mono(10))
                        .foregroundStyle(Color(DesignTokens.git.base))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: 100, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(selected || hovering ? DesignTokens.Glass.fillSelection : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(item.vitals.name), \(kindLabel). Press to focus.")
    }
}
