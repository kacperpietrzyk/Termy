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
                        Image(systemName: "command")
                            .foregroundStyle(TermyDesign.accent)
                            .font(Typography.ui(18, weight: .semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Command Center")
                                .font(Typography.ui(15, weight: .semibold))
                            Text("Actions, sessions, panels, and settings")
                                .font(Typography.ui(12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Esc")
                            .font(Typography.mono(12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                    }

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
                    .padding(12)
                    .background(TermyDesign.surface, in: RoundedRectangle(cornerRadius: TermyDesign.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: TermyDesign.cornerRadius)
                            .stroke(TermyDesign.border, lineWidth: 1)
                    )
                }
                .padding(16)

                Divider()

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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TermyDesign.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 34, y: 18)

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
        if case .agentSession(let vitals) = item {
            return TermyDesign.agentActivityColor(vitals.state)
        }
        return TermyDesign.areaColor(item.area)
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
            TermyPill(title: item.area.rawValue.uppercased(), tint: TermyDesign.areaColor(item.area))
            if let shortcut = item.shortcut {
                Text(shortcut.displayValue)
                    .font(Typography.mono(12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
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
