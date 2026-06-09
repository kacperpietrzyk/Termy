import AppKit
import SwiftUI
import TermyCore

struct CommandCenterView: View {
    @ObservedObject var store: TermyStore
    @FocusState private var focused: Bool
    @State private var selectedIndex = 0

    // CK-S5 Action Panel state. `actionPanelItem` is the palette row the panel
    // was opened from (nil = closed). `panelStack` is the submenu navigation
    // stack — its last element is the visible level; pushing a submenu appends,
    // ← pops. `panelIndex` is the highlighted secondary in the visible level.
    @State private var actionPanelItem: CommandCenterItem?
    @State private var panelStack: [[SecondaryAction]] = []
    @State private var panelIndex = 0
    /// CK-S5: local keyDown monitor that owns palette + panel navigation (a
    /// focused TextField eats ←/→/Return before SwiftUI `.onKeyPress`).
    @State private var keyMonitor: Any?

    private var actionPanelPresented: Bool { actionPanelItem != nil }
    private var panelLevel: [SecondaryAction] { panelStack.last ?? [] }

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
                            // CK-S5: Return is routed through the local key monitor
                            // (installed in .onAppear) so it can target the Action
                            // Panel's selected secondary, not just the palette row.
                            // No .onSubmit — it would double-fire with the monitor.
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
            .onChange(of: store.commandQuery) { _, _ in
                selectedIndex = 0
                closeActionPanel()
            }
            .overlay(alignment: .topTrailing) {
                if let item = actionPanelItem {
                    ActionPanelView(
                        sourceTitle: item.title,
                        actions: panelLevel,
                        selectedIndex: panelIndex,
                        isNested: panelStack.count > 1)
                    .padding(.top, 78)
                    .padding(.trailing, -160)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.18))
        .onAppear {
            focused = true
            installKeyMonitor()
        }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - CK-S5 key monitor

    /// A focused single-line `TextField` consumes ←/→ (caret) and Return (submit)
    /// before SwiftUI `.onKeyPress` on the container ever sees them — the original
    /// view only bound ↑/↓ for exactly this reason. The Action Panel needs →/←/↵
    /// deterministically (P2: keyboard-COMPLETE), so we install an `NSEvent` local
    /// keyDown monitor while the palette is up: it sees keys before the field, so
    /// we own navigation and let plain typing fall through (return the event).
    /// In-pattern with `QuickLookHost`'s NSEvent use. (⌘K-to-open is still owned
    /// by the global CommandMenu shortcut; `→` is the guaranteed opener.)
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        keyMonitor = nil
    }

    /// Returns true when the key was consumed (swallow it), false to let it fall
    /// through to the text field for normal typing/caret movement.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        // ⌘K toggles the panel on the highlighted row (Raycast parity). The global
        // CommandMenu ⌘K usually wins; this is a best-effort second path.
        if mods.contains(.command), key == "k" {
            if actionPanelPresented { closeActionPanel() } else { openActionPanel() }
            return true
        }

        switch Int(event.keyCode) {
        case 53: // Esc
            if actionPanelPresented { closeActionPanel() } else { store.isCommandCenterPresented = false }
            return true
        case 125: // ↓
            if actionPanelPresented { movePanel(1) } else { moveSelection(1) }
            return true
        case 126: // ↑
            if actionPanelPresented { movePanel(-1) } else { moveSelection(-1) }
            return true
        case 124: // →
            if actionPanelPresented { enterPanelSubmenu() } else { openActionPanel() }
            return true
        case 123: // ←
            guard actionPanelPresented else { return false } // let the caret move
            popPanelOrClose()
            return true
        case 36, 76: // Return / keypad Enter
            if actionPanelPresented { runSelectedSecondary() } else { runSelected() }
            return true
        default:
            break
        }

        // Inline hotkeys fire directly while the panel is open (today: ⌃C = Interrupt).
        if actionPanelPresented, mods == .control, key == "c" {
            fireInlineHotkey("⌃C")
            return true
        }

        return false
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

    // MARK: - CK-S5 Action Panel routing

    /// The palette row the panel acts on (the highlighted item).
    private func highlightedItem() -> CommandCenterItem? {
        let items = store.filteredCommandCenterItems
        return items.indices.contains(selectedIndex) ? items[selectedIndex] : items.first
    }

    /// ⌘K/→ on a row → open the secondary-actions panel for that object. The
    /// resolver always yields at least the primary, so an empty set is impossible;
    /// guard anyway so we never open an empty panel.
    private func openActionPanel() {
        guard let item = highlightedItem() else { return }
        let actions = store.secondaryActions(for: item)
        guard !actions.isEmpty else { return }
        withAnimation(DesignTokens.Motion.easeOut) {
            actionPanelItem = item
            panelStack = [actions]
            panelIndex = 0
        }
    }

    private func closeActionPanel() {
        guard actionPanelPresented else { return }
        withAnimation(DesignTokens.Motion.easeOut) {
            actionPanelItem = nil
            panelStack = []
            panelIndex = 0
        }
    }

    /// ↑/↓ within the panel, clamped to the current level.
    private func movePanel(_ delta: Int) {
        let count = panelLevel.count
        guard count > 0 else { return }
        panelIndex = max(0, min(panelIndex + delta, count - 1))
    }

    /// → on a submenu parent pushes its children; on a leaf it is a no-op (the
    /// leaf is run with ↵). Today the S4 resolver emits no children, so this is
    /// the mechanism (unit-tested via the model) awaiting a submenu-producing
    /// object — never a fabricated submenu.
    private func enterPanelSubmenu() {
        guard panelLevel.indices.contains(panelIndex) else { return }
        let action = panelLevel[panelIndex]
        guard !action.children.isEmpty else { return }
        withAnimation(DesignTokens.Motion.easeOut) {
            panelStack.append(action.children)
            panelIndex = 0
        }
    }

    /// ← pops a submenu level; at the root level it closes the panel back to the
    /// palette.
    private func popPanelOrClose() {
        if panelStack.count > 1 {
            withAnimation(DesignTokens.Motion.easeOut) {
                panelStack.removeLast()
                panelIndex = 0
            }
        } else {
            closeActionPanel()
        }
    }

    /// ↵ on the highlighted secondary: a submenu parent expands; a leaf runs and
    /// closes the palette.
    private func runSelectedSecondary() {
        guard let item = actionPanelItem,
              panelLevel.indices.contains(panelIndex) else { return }
        let action = panelLevel[panelIndex]
        if !action.children.isEmpty {
            enterPanelSubmenu()
            return
        }
        store.performSecondaryAction(action, originatingItem: item)
        // The store closes the palette; clear local panel state too.
        actionPanelItem = nil
        panelStack = []
        panelIndex = 0
    }

    /// Fire the panel action whose inline hotkey matches (e.g. ⌃C → Interrupt),
    /// regardless of which row is highlighted. Searches the visible level.
    private func fireInlineHotkey(_ hotkey: String) {
        guard let item = actionPanelItem,
              let action = panelLevel.first(where: { $0.inlineHotkey == hotkey }),
              action.children.isEmpty else { return }
        store.performSecondaryAction(action, originatingItem: item)
        actionPanelItem = nil
        panelStack = []
        panelIndex = 0
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
