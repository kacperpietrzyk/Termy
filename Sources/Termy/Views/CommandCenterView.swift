import SwiftUI
import TermyCore

struct CommandCenterView: View {
    @ObservedObject var store: TermyStore
    @FocusState private var focused: Bool
    @State private var selectedIndex = 0

    var body: some View {
        // Snapshot the ranking once per body eval; reuse for the empty check,
        // the rows, and the highlight ranges so the ranker runs once per render.
        let feed = store.rankedCommandCenterFeed
        return VStack {
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
                            .onSubmit { runSelected() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(DesignTokens.Glass.fillControl, in: Capsule())
                    .overlay(Capsule().stroke(DesignTokens.Glass.hairline, lineWidth: 1))
                }
                .padding(16)

                if feed.items.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "command",
                        description: Text("Try a session name, product area, or action.")
                    )
                    .frame(height: 360)
                } else {
                    let titleRanges = feed.ranges
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(feed.items.enumerated()),
                                        id: \.element.id) { index, item in
                                    Button {
                                        store.performCommandCenterItem(item)
                                    } label: {
                                        CommandCenterItemRow(
                                            item: item,
                                            titleRanges: titleRanges[item.id] ?? [],
                                            isSelected: index == selectedIndex)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                    .onHover { if $0 { selectedIndex = index } }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        }
                        .frame(height: 360)
                        .onChange(of: selectedIndex) { _, i in
                            withAnimation(DesignTokens.Motion.easeOut) { proxy.scrollTo(i, anchor: .center) }
                        }
                    }
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
            .onKeyPress(.downArrow) { moveSelection(1); return .handled }
            .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
            .onChange(of: store.commandQuery) { _, _ in selectedIndex = 0 }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.18))
        .onAppear { focused = true }
        .onExitCommand {
            store.isCommandCenterPresented = false
        }
    }

    /// Move the keyboard highlight, clamped to the current result range.
    private func moveSelection(_ delta: Int) {
        let count = store.filteredCommandCenterItems.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(selectedIndex + delta, count - 1))
    }

    /// Run the highlighted item (falls back to the first if the index drifted).
    private func runSelected() {
        let items = store.filteredCommandCenterItems
        guard let item = items.indices.contains(selectedIndex) ? items[selectedIndex] : items.first
        else { return }
        store.performCommandCenterItem(item)
    }
}

private struct CommandCenterItemRow: View {
    let item: CommandCenterItem
    /// CK-S3: matched Character-offset ranges into `item.title` to highlight.
    var titleRanges: [Range<Int>] = []
    var isSelected = false

    private var leadingTint: Color {
        // Raycast-style restraint: chrome stays monochrome, color comes only from
        // real status. Keep the agent activity hue (waiting/running/idle is a true
        // signal); neutralize the per-area tint that made every row carry a colour.
        if case .agentSession(let vitals) = item {
            return TermyDesign.agentActivityColor(vitals.state)
        }
        return Color(DesignTokens.fg2)
    }

    /// CK-S3: the title with matched glyph runs emphasized (accent tint +
    /// semibold). Builds one `Text` by concatenating per-character runs over the
    /// merged Character-offset ranges — the matcher reports Character offsets, so
    /// indexing `Array(title)` (not UTF-16) keeps the highlight aligned for
    /// multi-byte glyphs.
    private var highlightedTitle: Text {
        let chars = Array(item.title)
        guard !titleRanges.isEmpty else { return Text(item.title) }
        let matched = Set(titleRanges.flatMap { Array($0) })
        var result = Text("")
        for (index, char) in chars.enumerated() {
            let run = Text(String(char))
            if matched.contains(index) {
                result = result + run
                    .foregroundColor(Color(DesignTokens.primary))
                    .fontWeight(.semibold)
            } else {
                result = result + run
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .foregroundStyle(leadingTint)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                highlightedTitle
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
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(isSelected ? DesignTokens.Glass.fillSelection : Color.clear,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
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
