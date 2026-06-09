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

    // CK-S7 inline-argument state. `argCompletions` are the path/branch
    // suggestions for the active argument; `argCompletionIndex` is the keyboard
    // highlight. Recomputed whenever the query changes while in arg mode.
    @State private var argCompletions: [String] = []
    @State private var argCompletionIndex = 0
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
                        TextField("Search, or type ssh / grep / cd / branch / agent-prompt …", text: $store.commandQuery)
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

                    // CK-S7: inline-argument affordance — shows the active verb,
                    // its argument, the running/disabled state, and (for path/
                    // branch args) keyboard-navigable completions.
                    if let parsed = store.inlineArgCommand {
                        InlineArgEntryView(
                            parsed: parsed,
                            completions: argCompletions,
                            completionIndex: argCompletionIndex)
                    }
                }
                .padding(16)

                if store.inlineArgCommand != nil {
                    // In arg mode the result list collapses; the affordance above
                    // is the surface, and Enter runs the parsed command.
                    EmptyView()
                } else if feed.items.isEmpty {
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
                refreshArgCompletions()
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
            refreshArgCompletions()
        }
        .onDisappear { removeKeyMonitor() }
    }

    // MARK: - CK-S7 inline-argument helpers

    /// Recompute the active argument's path/branch completions (free-text args
    /// yield none). Clamps the highlight so a shrinking list never strands it.
    private func refreshArgCompletions() {
        guard let parsed = store.inlineArgCommand, parsed.completion != .none else {
            argCompletions = []
            argCompletionIndex = 0
            return
        }
        argCompletions = store.inlineArgCompletions(for: parsed)
        argCompletionIndex = min(argCompletionIndex, max(0, argCompletions.count - 1))
    }

    /// ↑/↓ over the completion list while in arg mode.
    private func moveArgCompletion(_ delta: Int) {
        guard !argCompletions.isEmpty else { return }
        argCompletionIndex = max(0, min(argCompletionIndex + delta, argCompletions.count - 1))
    }

    /// → / Tab accepts the highlighted completion: rewrite the query to
    /// `<verb> <completion>` so the user can keep editing or press Enter to run.
    private func acceptArgCompletion() {
        guard let parsed = store.inlineArgCommand,
              let verb = parsed.action.verb,
              argCompletions.indices.contains(argCompletionIndex) else { return }
        store.commandQuery = "\(verb) \(argCompletions[argCompletionIndex])"
    }

    /// Run the inline-arg command (Enter) when complete; a missing required arg
    /// is a no-op so Enter never fires an empty grep/cd/branch.
    private func runInlineArgCommand() {
        guard let parsed = store.inlineArgCommand, parsed.isComplete else { return }
        store.performInlineArgCommand(parsed)
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

        // CK-S7: while an inline-argument command is recognized, the palette is in
        // arg-entry mode — ↑/↓ navigate completions, →/Tab accept one, Return runs
        // the parsed command. (The Action Panel is closed in this mode because any
        // query edit closes it.) Plain typing still falls through to the field.
        let argMode = store.inlineArgCommand != nil
        if argMode {
            switch Int(event.keyCode) {
            case 53: // Esc
                store.isCommandCenterPresented = false
                return true
            case 125: // ↓
                moveArgCompletion(1); return true
            case 126: // ↑
                moveArgCompletion(-1); return true
            case 124, 48: // → / Tab
                if !argCompletions.isEmpty { acceptArgCompletion(); return true }
                return false // no completions: let → move the caret
            case 36, 76: // Return
                runInlineArgCommand(); return true
            default:
                return false
            }
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

/// CK-S7: the inline-argument entry affordance shown under the search field when
/// the query recognizes an arg-bearing verb. Renders the verb pill, the argument
/// name + current value, a run/needs-input hint, and (for path/branch args) a
/// keyboard-navigable completion list. All chrome — keystrokes are owned by the
/// CommandCenterView key monitor.
private struct InlineArgEntryView: View {
    let parsed: ParsedInlineCommand
    let completions: [String]
    let completionIndex: Int

    private var argName: String { parsed.primaryArgument?.name ?? "argument" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let verb = parsed.action.verb {
                    Text(verb)
                        .font(Typography.mono(12, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(DesignTokens.Glass.fillChip,
                                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                }
                if parsed.rest.isEmpty {
                    Text(parsed.isComplete ? parsed.effectiveValue : "<\(argName)>")
                        .font(Typography.ui(13))
                        .foregroundStyle(.secondary)
                } else {
                    Text(parsed.rest)
                        .font(Typography.ui(13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Text(parsed.isComplete ? "↵ run" : "needs \(argName)")
                    .font(Typography.ui(11))
                    .foregroundStyle(parsed.isComplete ? Color(DesignTokens.primary) : .secondary)
            }

            if !completions.isEmpty {
                VStack(spacing: 1) {
                    ForEach(Array(completions.enumerated()), id: \.offset) { index, candidate in
                        HStack(spacing: 8) {
                            Image(systemName: parsed.completion == .branch
                                  ? "arrow.triangle.branch" : "folder")
                                .foregroundStyle(.secondary)
                                .frame(width: 14)
                            Text(candidate)
                                .font(Typography.mono(12))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            if index == completionIndex {
                                Text("→")
                                    .font(Typography.ui(11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(index == completionIndex
                                    ? DesignTokens.Glass.fillSelection : Color.clear,
                                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Glass.fillControl,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .stroke(DesignTokens.Glass.hairline, lineWidth: 1))
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
