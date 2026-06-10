import AppKit
import SwiftUI
import TermyCore

/// ED-3: the editor's ⌘P fuzzy file/buffer switcher. A focused glass overlay that
/// mirrors the ⌘K command center's visual idiom (magnifying-glass field, matched-
/// glyph highlighting, keyboard-navigable rows) but is intentionally lean — no
/// action panel, no inline args. Ranking comes from the SHARED
/// `EditorQuickOpen`/`FuzzyMatcher` so ⌘P stays consistent with ⌘K (open buffers
/// first, then bounded project files, deduped).
///
/// Keyboard (P2 keyboard-COMPLETE): ↑/↓ move, Return opens, Esc dismisses. A
/// local `NSEvent` keyDown monitor owns navigation because a focused single-line
/// `TextField` would otherwise swallow Return/arrows (same rationale as
/// `CommandCenterView`).
struct EditorQuickOpenView: View {
    @ObservedObject var store: TermyStore
    @FocusState private var focused: Bool
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any?

    var body: some View {
        let items = store.editorQuickOpenItems(query: store.editorQuickOpenQuery)
        return VStack {
            Spacer(minLength: 64)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Go to file or open buffer…", text: $store.editorQuickOpenQuery)
                        .textFieldStyle(.plain)
                        .font(Typography.ui(16, weight: .semibold))
                        .focused($focused)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(DesignTokens.Glass.fillControl, in: Capsule())
                .overlay(Capsule().stroke(DesignTokens.Glass.hairline, lineWidth: 1))
                .padding(16)

                if items.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Try a file name or open-buffer name.")
                    )
                    .frame(height: 320)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    Button {
                                        store.openEditorQuickOpenItem(item)
                                    } label: {
                                        EditorQuickOpenRow(item: item, isSelected: index == selectedIndex)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                    .onHover { if $0 { selectedIndex = index } }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        }
                        .frame(height: 320)
                        .onChange(of: selectedIndex) { _, i in
                            withAnimation(DesignTokens.Motion.easeOut) { proxy.scrollTo(i, anchor: .center) }
                        }
                    }
                }
            }
            .frame(width: 640)
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
            .onChange(of: store.editorQuickOpenQuery) { _, _ in selectedIndex = 0 }

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

    // MARK: - Key monitor (mirrors CommandCenterView's rationale)

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

    /// True when the key was consumed; false to let it fall through to the field.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let items = store.editorQuickOpenItems(query: store.editorQuickOpenQuery)
        switch Int(event.keyCode) {
        case 53: // Esc
            store.dismissEditorQuickOpen()
            return true
        case 125: // ↓
            guard !items.isEmpty else { return true }
            selectedIndex = min(selectedIndex + 1, items.count - 1)
            return true
        case 126: // ↑
            guard !items.isEmpty else { return true }
            selectedIndex = max(selectedIndex - 1, 0)
            return true
        case 36, 76: // Return / Enter
            guard items.indices.contains(selectedIndex) else { return true }
            store.openEditorQuickOpenItem(items[selectedIndex])
            return true
        default:
            return false // plain typing falls through to the field
        }
    }
}

/// One ⌘P result row, styled to match `CommandCenterItemRow`: leading icon,
/// matched-glyph-highlighted title (same `Array(title)` char-offset run pattern),
/// directory subtitle, and a trailing "Buffer" tag for already-open files.
private struct EditorQuickOpenRow: View {
    let item: EditorQuickOpenItem
    var isSelected = false

    private var isBuffer: Bool {
        if case .buffer = item.kind { return true }
        return false
    }

    private var iconName: String {
        isBuffer ? "doc.on.doc" : LocalFileTypeIcon.iconName(
            for: LocalFileItem(name: item.title, relativePath: item.path ?? item.title, isDirectory: false))
    }

    /// Title with matched glyph runs emphasized (accent tint + semibold) — the
    /// exact char-offset pattern `CommandCenterItemRow.highlightedTitle` uses, so
    /// ⌘P highlighting reads identically to ⌘K.
    private var highlightedTitle: Text {
        let chars = Array(item.title)
        guard !item.titleRanges.isEmpty else { return Text(item.title) }
        let matched = Set(item.titleRanges.flatMap { Array($0) })
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
            Image(systemName: iconName)
                .foregroundStyle(Color(DesignTokens.fg2))
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
            if isBuffer {
                Text("Buffer")
                    .font(Typography.mono(11))
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
        .contentShape(Rectangle())
    }
}
