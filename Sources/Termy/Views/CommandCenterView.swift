import SwiftUI
import TermyCore

struct CommandCenterView: View {
    @ObservedObject var store: TermyStore
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            Spacer(minLength: 64)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search commands, sessions, and settings", text: $store.commandQuery)
                            .textFieldStyle(.plain)
                            .font(Typography.ui(16, weight: .semibold))
                            .focused($focused)
                            .onSubmit {
                                if let item = store.filteredCommandCenterItems.first {
                                    store.performCommandCenterItem(item)
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(DesignTokens.Glass.fillControl, in: Capsule())
                    .overlay(Capsule().stroke(DesignTokens.Glass.hairline, lineWidth: 1))
                }
                .padding(16)

                if store.filteredCommandCenterItems.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "command",
                        description: Text("Try a session name, product area, or action.")
                    )
                    .frame(height: 360)
                } else {
                    List(store.filteredCommandCenterItems) { item in
                        Button {
                            store.performCommandCenterItem(item)
                        } label: {
                            CommandCenterItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .frame(height: 360)
                }
            }
            .frame(width: 700)
            .background {
                GlassMaterial(material: .hudWindow)
                    .overlay(DesignTokens.Glass.base.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.panel))
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.panel)
                    .stroke(DesignTokens.Glass.hairline, lineWidth: 1)
            )
            .shadow(color: DesignTokens.Shadow.popColor, radius: DesignTokens.Shadow.popRadius, y: DesignTokens.Shadow.popY)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.18))
        .onAppear { focused = true }
        .onExitCommand {
            store.isCommandCenterPresented = false
        }
    }
}

private struct CommandCenterItemRow: View {
    let item: CommandCenterItem

    private var leadingTint: Color {
        // Raycast-style restraint: chrome stays monochrome, color comes only from
        // real status. Keep the agent activity hue (waiting/running/idle is a true
        // signal); neutralize the per-area tint that made every row carry a colour.
        if case .agentSession(let vitals) = item {
            return TermyDesign.agentActivityColor(vitals.state)
        }
        return Color(DesignTokens.fg2)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .foregroundStyle(leadingTint)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(Typography.ui(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let shortcut = item.shortcut {
                Text(shortcut.displayValue)
                    .font(Typography.mono(12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DesignTokens.Glass.fillChip, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 2)
    }
}

private extension ShortcutDescriptor {
    var displayValue: String {
        switch self {
        case .command(let key): "⌘\(key.uppercased())"
        case .commandShift(let key): "⇧⌘\(key.uppercased())"
        case .commandOption(let key): "⌥⌘\(key.uppercased())"
        case .controlCommand(let key): "⌃⌘\(key.uppercased())"
        }
    }
}
