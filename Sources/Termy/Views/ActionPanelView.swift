import SwiftUI
import TermyCore

/// CK-S5 — the ⌘K **Action Panel**: a secondary-actions overlay anchored to the
/// command palette. This is the mechanism that elevates ⌘K to a true "primary
/// interface" (P2) — ⌘K/→ on the highlighted row reveals contextual secondary
/// actions on a *live* cockpit object (a connection profile, a running CLI
/// agent), the one differentiator a generic launcher cannot copy.
///
/// **Pure rendering.** All key routing lives in `CommandCenterView`, which owns
/// the palette's focus and so can guarantee deterministic handling (a native
/// `.popover` is prone to dropping key events / stealing first-responder, which
/// would break the live keyboard gate). This view only draws the current
/// secondary level and its selection; the parent drives ↑/↓, inline hotkeys,
/// →-into-submenu, and ←/Esc dismiss.
struct ActionPanelView: View {
    /// Title of the palette row the panel was opened from (the object's name).
    let sourceTitle: String
    /// The secondary actions at the current navigation level (top of the stack).
    let actions: [SecondaryAction]
    /// Selected row in the current level.
    let selectedIndex: Int
    /// True when this level is nested under a parent (shows the ← hint).
    let isNested: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: which object these actions belong to.
            HStack(spacing: 6) {
                if isNested {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Actions")
                    .font(Typography.ui(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(sourceTitle)
                    .font(Typography.ui(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().overlay(DesignTokens.Glass.hairline)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                            ActionPanelRow(action: action, isSelected: index == selectedIndex)
                                .id(index)
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 260)
                .onChange(of: selectedIndex) { _, i in
                    withAnimation(DesignTokens.Motion.easeOut) { proxy.scrollTo(i, anchor: .center) }
                }
            }
        }
        .frame(width: 320)
        .background {
            GlassMaterial(material: .hudWindow)
                .overlay(DesignTokens.Glass.base.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .stroke(DesignTokens.Glass.hairlineStrong, lineWidth: 1)
        )
        .shadow(color: DesignTokens.Shadow.popColor,
                radius: DesignTokens.Shadow.popRadius * 0.6, y: 12)
    }
}

private struct ActionPanelRow: View {
    let action: SecondaryAction
    let isSelected: Bool

    private var isSubmenu: Bool { !action.children.isEmpty }

    private var tint: Color {
        action.isDestructive ? DesignTokens.Glass.brandRed : .primary
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(action.title)
                .font(Typography.ui(13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(tint)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let hotkey = action.inlineHotkey {
                Text(hotkey)
                    .font(Typography.mono(11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Glass.fillChip,
                                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            }
            if isSubmenu {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(isSelected ? DesignTokens.Glass.fillSelection : Color.clear,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }
}
