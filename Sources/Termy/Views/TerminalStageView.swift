import AppKit
import CoreText
import SwiftUI
import TermyCore
import TermyRDP

// SwiftUI `Font` for the legacy/non-rawPTY render branches. Derives from the
// single `NSFont`-resolution core below so the two cannot drift apart.
private func terminalFont(_ preferences: TerminalFontPreferences) -> Font {
    Font(terminalNSFont(preferences))
}

// Single source of truth for terminal font resolution (family/size/ligature).
// `SwiftTermTerminalView.font` needs the un-wrapped `NSFont`; `terminalFont`
// wraps this in `Font(...)` for the SwiftUI branches.
func terminalNSFont(_ preferences: TerminalFontPreferences) -> NSFont {
    let baseFont: NSFont
    if let family = preferences.family,
       let customFont = NSFont(name: family, size: preferences.size) {
        baseFont = customFont
    } else {
        baseFont = .monospacedSystemFont(ofSize: preferences.size, weight: .regular)
    }

    guard !preferences.usesLigatures else {
        return baseFont
    }

    let descriptor = baseFont.fontDescriptor.addingAttributes([
        .featureSettings: [
            [
                NSFontDescriptor.FeatureKey.typeIdentifier: kLigaturesType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kCommonLigaturesOffSelector
            ]
        ]
    ])
    return NSFont(descriptor: descriptor, size: preferences.size) ?? baseFont
}

struct TerminalStageView: View {
    @ObservedObject var store: TermyStore
    var showsHeader: Bool = true
    @State private var command = ""

    var body: some View {
        VStack(spacing: 0) {
            if let session = store.selectedSession, session.agentType != nil {
                AgentRedirectNote(store: store)
            } else if let session = store.selectedSession {
                if showsHeader {
                    Header(
                        session: session,
                        sidecarDisabled: store.sidecarDisabledSessions.contains(session.id)
                    )
                }
                // v3 Shell §6.1: the find/output toolbar is on-demand. The handoff
                // term-window has no permanent strip — Find (breadcrumb / ⌘F) reveals it.
                if store.terminalSearchVisible {
                    TerminalSearchBar(store: store)
                }

                let descriptor = store.terminalLaunchDescriptor(for: session.id)
                let mode = store.selectedTerminalOutputModeValue

                if session.interactionMode == .rawPTY, let descriptor {
                    LiveTerminalSurface(store: store, session: session, descriptor: descriptor)
                } else if mode == .blocks {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(store.renderedTerminalCommandBlocks()) { block in
                                    TerminalCommandBlockCardView(
                                        block: block,
                                        theme: store.terminalTheme,
                                        fontPreferences: store.terminalFontPreferences,
                                        selectBlock: {
                                            store.selectTerminalBlock(startLine: block.startLine)
                                        },
                                        toggleFold: {
                                            store.toggleTerminalBlockFolded(startLine: block.startLine)
                                        }
                                    )
                                    .id(block.startLine)
                                }
                            }
                            .padding(14)
                        }
                        .background(Color(hex: store.terminalTheme.backgroundHex))
                        .onChange(of: store.terminalScrollTargetLineID) {
                            if let lineID = store.terminalScrollTargetLineID,
                               let block = store.renderedTerminalCommandBlocks().first(where: { card in
                                   store.selectedSession?.lines.indices.contains(card.startLine) == true &&
                                   store.selectedSession?.lines[card.startLine].id == lineID
                               }) {
                                proxy.scrollTo(block.startLine, anchor: .center)
                            }
                        }
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(store.renderedTerminalLines()) { renderedLine in
                                    TerminalRenderedLineView(
                                        renderedLine: renderedLine,
                                        theme: store.terminalTheme,
                                        fontPreferences: store.terminalFontPreferences,
                                        toggleFold: {
                                            store.toggleTerminalBlockFolded(startLine: renderedLine.index)
                                        }
                                    )
                                        .id(renderedLine.id)
                                }
                            }
                            .padding(14)
                        }
                        .background(Color(hex: store.terminalTheme.backgroundHex))
                        .onChange(of: session.lines.count) {
                            if let last = session.lines.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: store.terminalScrollTargetLineID) {
                            if let lineID = store.terminalScrollTargetLineID {
                                proxy.scrollTo(lineID, anchor: .center)
                            }
                        }
                    }
                }

                if session.profile.kind == .rdp {
                    RemoteSessionPlaceholder(
                        session: session,
                        rdpFrame: store.currentRDPFrame(for: session.id),
                        handleRDPInput: { events in
                            store.handleLocalRDPInputEvents(events, for: session.id)
                        }
                    )
                } else if session.interactionMode == .rawPTY {
                    EmptyView()
                } else {
                    CommandInput(
                        command: $command,
                        suggestions: store.completionSuggestions(for: command),
                        inlineSuggestion: store.inlineAutosuggestion(for: command),
                        theme: store.terminalTheme,
                        fontPreferences: store.terminalFontPreferences,
                        acceptSuggestion: { suggestion in
                            command = suggestion.replacement
                        },
                        acceptInlineSuggestion: { suggestion in
                            command = suggestion.replacement
                        }
                    ) {
                        let submitted = command
                        command = ""
                        store.runCommand(submitted)
                    }
                }
            } else {
                ContentUnavailableView("No Session", systemImage: "terminal", description: Text("Create a local terminal or connect to SSH/RDP from Command Center."))
            }
        }
        .background(Color(hex: store.terminalTheme.backgroundHex))
    }
}

/// The live rawPTY surface: the SwiftTerm view + the F-1 ghost-text overlay +
/// the F-3 completion-menu overlay, keyed by session+generation. Extracted from
/// `TerminalStageView` so the Agents TUI pane (§5.10) can embed the same live
/// PTY with identical callback wiring (state/exit detection intact). Callers
/// supply the resolved rawPTY descriptor.
struct LiveTerminalSurface: View {
    @ObservedObject var store: TermyStore
    let session: TermySession
    let descriptor: TerminalLaunchDescriptor

    var body: some View {
        let terminalFontResolved = terminalNSFont(store.terminalFontPreferences)
        ZStack(alignment: .topLeading) {
            SwiftTermTerminalView(
                descriptor: descriptor,
                sessionID: session.id,
                font: terminalFontResolved,
                foreground: NSColor(Color(hex: store.terminalTheme.foregroundHex)),
                background: NSColor(Color(hex: store.terminalTheme.backgroundHex)),
                onEvents: { events in store.ingestShellIntegrationEvents(events, for: session.id) },
                onTitle: { title in store.setSessionTerminalTitle(title, for: session.id) },
                onDirectory: { dir in store.setSessionWorkingDirectory(dir, for: session.id) },
                onExit: { [generation = store.terminalLaunchGeneration(for: session.id)] code in
                    store.noteSessionProcessExited(
                        exitCode: code, for: session.id, generation: generation)
                },
                onScreenText: { provider in store.registerTerminalScreenTextProvider(provider, for: session.id) },
                storeRef: store,
                onCaretOrigin: { provider in store.registerTerminalCaretOriginProvider(provider, for: session.id) },
                onSendInput: { sink in store.registerTerminalInputSink(sink, for: session.id) },
                initialTranscriptReplay: store.initialTerminalTranscriptReplay(for: session.id),
                onInitialTranscriptReplayed: { store.clearInitialTerminalTranscriptReplay(for: session.id) }
            )
            if let suffix = store.terminalInlineSuggestionSuffix(for: session.id),
               let origin = store.terminalCaretOrigin(for: session.id) {
                Text(suffix)
                    .font(.init(terminalFontResolved))
                    .foregroundStyle(Color(hex: store.terminalTheme.foregroundHex).opacity(0.35))
                    .allowsHitTesting(false)
                    .offset(x: origin.x, y: origin.y)
            }
            GeometryReader { geo in
                if let menuSnapshot = store.terminalMenuSnapshot(for: session.id),
                   let origin = store.terminalCaretOrigin(for: session.id) {
                    CompletionMenuOverlay(
                        snapshot: menuSnapshot,
                        anchor: CGPoint(x: origin.x, y: origin.y),
                        viewportSize: geo.size,
                        font: terminalFontResolved
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .id("\(session.id.uuidString)#\(store.terminalLaunchGeneration(for: session.id))")
    }
}

/// Slice 3: agents render only in the Agents tab (their sole terminal home, so
/// the §7 cross-fade can't double-mount a PTY). When an agent session is the
/// global selection, the Shell pane-tree shows this redirect instead of a
/// second live surface.
private struct AgentRedirectNote: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "cpu").font(.system(size: 24))
                .foregroundStyle(Color(DesignTokens.ai.base))
            Text("Agent session").font(Typography.ui(15, weight: .semibold))
                .foregroundStyle(Color(DesignTokens.fg1))
            Text("CLI agents live in the Agents module, with their plan, signals, and live PTY.")
                .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg3))
                .multilineTextAlignment(.center)
            Button("Open in Agents") { store.openModuleTab(.agents) }
                .buttonStyle(TermyCommandButtonStyle(emphasized: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color(hex: store.terminalTheme.backgroundHex))
    }
}

private struct TerminalSearchBar: View {
    @ObservedObject var store: TermyStore
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search output", text: $store.terminalSearchQuery)
                        .textFieldStyle(.plain)
                        .frame(width: 190)
                        .focused($searchFieldFocused)
                        .onSubmit {
                            store.refreshTerminalIndex()
                        }
                        .onChange(of: store.terminalSearchQuery) {
                            store.refreshTerminalIndex()
                        }
                        .onChange(of: store.terminalSearchFocusToken) {
                            searchFieldFocused = true
                        }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: TermyDesign.controlRadius))

                TermyPill(title: "\(store.terminalSearchResults.count) matches", systemImage: "text.magnifyingglass", tint: Color(DesignTokens.git.base))
                TermyPill(title: "\(store.terminalCommandBlocks().count) blocks", systemImage: "square.stack.3d.up", tint: Color(DesignTokens.host.base))

                if !store.terminalLinks.isEmpty {
                    Divider()
                        .frame(height: 18)
                    ForEach(store.terminalLinks.prefix(3), id: \.urlString) { link in
                        Button {
                            store.openTerminalLink(link)
                        } label: {
                            Label(link.urlString, systemImage: "link")
                                .lineLimit(1)
                        }
                        .buttonStyle(TermyCommandButtonStyle())
                        .frame(maxWidth: 180)
                    }
                }

                Divider()
                    .frame(height: 18)

                Button {
                    store.selectPreviousTerminalBlock()
                } label: {
                    Label("Previous Block", systemImage: "chevron.up")
                }
                .buttonStyle(TermyIconButtonStyle())
                .help("Previous command block")
                .disabled(store.terminalCommandBlocks().isEmpty)

                Button {
                    store.selectNextTerminalBlock()
                } label: {
                    Label("Next Block", systemImage: "chevron.down")
                }
                .buttonStyle(TermyIconButtonStyle())
                .help("Next command block")
                .disabled(store.terminalCommandBlocks().isEmpty)

                Button {
                    store.toggleSelectedTerminalBlockFolded()
                } label: {
                    Label("Fold Block", systemImage: "rectangle.compress.vertical")
                }
                .buttonStyle(TermyIconButtonStyle())
                .help("Fold or expand selected command block")
                .disabled(store.terminalCommandBlocks().isEmpty)

                Button {
                    store.copyLastCommandOutput()
                } label: {
                    Label("Copy Last", systemImage: "doc.on.doc")
                }
                .buttonStyle(TermyCommandButtonStyle())
                .disabled(store.terminalCommandBlocks().isEmpty)

                Button {
                    store.copySelectedCommandOutput()
                } label: {
                    Label("Copy Block", systemImage: "selection.pin.in.out")
                }
                .buttonStyle(TermyCommandButtonStyle())
                .disabled(store.selectedTerminalBlockStartLine == nil)

                Divider()
                    .frame(height: 18)

                Button {
                    store.dismissTerminalSearch()
                } label: {
                    Label("Close find", systemImage: "xmark")
                }
                .buttonStyle(TermyIconButtonStyle())
                .help("Close find (Esc)")
            }
        }
        .font(Typography.ui(12))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onAppear { searchFieldFocused = true }
        .onExitCommand { store.dismissTerminalSearch() }
    }
}

private struct Header: View {
    let session: TermySession
    let sidecarDisabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(TermyDesign.accent)
                .frame(width: 22, height: 22)
                .background(TermyDesign.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(Typography.ui(15, weight: .semibold))
                    .lineLimit(1)
                Text(session.currentWorkingDirectory ?? session.profile.host)
                    .font(Typography.ui(12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            CompletionSidecarStatusIndicator(disabled: sidecarDisabled)

            Spacer()

            TermyPill(title: session.profile.kind.rawValue.uppercased(), systemImage: iconName, tint: sessionTint)
            TermyPill(title: "PTY", systemImage: "arrow.left.and.right", tint: Color(DesignTokens.host.base))
            TermyPill(title: "Offline AI", systemImage: "cpu", tint: Color(DesignTokens.ai.base))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.bar)
    }

    private var iconName: String {
        switch session.profile.kind {
        case .local: "terminal"
        case .ssh: "network"
        case .rdp: "display"
        }
    }

    private var sessionTint: Color {
        switch session.profile.kind {
        case .local: TermyDesign.areaColor(.terminal)
        case .ssh: TermyDesign.areaColor(.ssh)
        case .rdp: TermyDesign.areaColor(.rdp)
        }
    }
}

private struct TerminalRenderedLineView: View {
    let renderedLine: TerminalRenderedLine
    let theme: TerminalTheme
    let fontPreferences: TerminalFontPreferences
    let toggleFold: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if renderedLine.isBlockStart {
                Button(action: toggleFold) {
                    Image(systemName: renderedLine.isFoldedBlock ? "chevron.right" : "chevron.down")
                        .font(Typography.ui(12))
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
                .help(renderedLine.isFoldedBlock ? "Expand command block" : "Fold command block")
            } else {
                Color.clear
                    .frame(width: 12, height: 1)
            }

            TerminalLineView(
                line: renderedLine.line,
                theme: theme,
                fontPreferences: fontPreferences
            )
        }
        .padding(.vertical, renderedLine.isBlockStart ? 2 : 0)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(renderedLine.isSelectedBlock ? Color(hex: theme.mutedHex).opacity(0.18) : .clear)
        )
    }
}

private struct TerminalCommandBlockCardView: View {
    let block: TerminalRenderedCommandBlock
    let theme: TerminalTheme
    let fontPreferences: TerminalFontPreferences
    let selectBlock: () -> Void
    let toggleFold: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: toggleFold) {
                    Image(systemName: block.isFolded ? "chevron.right" : "chevron.down")
                        .font(Typography.ui(12))
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
                .help(block.isFolded ? "Expand command block" : "Fold command block")

                Text("$ \(block.command)")
                    .font(terminalFont(fontPreferences))
                    .foregroundStyle(Color(hex: theme.promptHex))
                    .textSelection(.enabled)

                Spacer()

                if let exitCode = block.exitCode {
                    Text("Exit \(exitCode)")
                        .font(.caption.monospaced())
                        .foregroundStyle(exitCode == 0 ? Color(hex: theme.mutedHex) : Color(hex: theme.errorHex))
                } else {
                    Text("Running")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color(hex: theme.mutedHex))
                }
            }

            if !block.isFolded {
                if block.outputLines.isEmpty {
                    Text("No output")
                        .font(terminalFont(fontPreferences))
                        .foregroundStyle(Color(hex: theme.mutedHex))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(block.outputLines) { line in
                            TerminalLineView(
                                line: line,
                                theme: theme,
                                fontPreferences: fontPreferences
                            )
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: theme.foregroundHex).opacity(block.isSelected ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: block.isSelected ? theme.promptHex : theme.mutedHex).opacity(block.isSelected ? 0.7 : 0.25), lineWidth: 1)
        )
        .onTapGesture(perform: selectBlock)
    }
}

private struct TerminalLineView: View {
    let line: TerminalLine
    let theme: TerminalTheme
    let fontPreferences: TerminalFontPreferences

    var body: some View {
        Text(attributedText)
            .font(terminalFont(fontPreferences))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attributedText: AttributedString {
        let runs = TerminalANSIParser().parse(line.text)
        return runs.reduce(into: AttributedString()) { result, run in
            var part = AttributedString(run.text)
            applyAttributes(to: &part, style: run.style)
            result += part
        }
    }

    private func applyAttributes(to part: inout AttributedString, style: TerminalANSIStyle) {
        if style.isInverted {
            let foreground = style.background.flatMap(color(for:)) ?? Color(hex: theme.backgroundHex)
            let background = style.foreground.flatMap(color(for:)) ?? defaultColor
            part.foregroundColor = renderedForegroundColor(
                style.isConcealed ? background : foreground,
                style: style
            )
            part.backgroundColor = background
        } else {
            let background = style.background.flatMap(color(for:)) ?? Color(hex: theme.backgroundHex)
            part.foregroundColor = renderedForegroundColor(
                style.isConcealed ? background : color(for: style),
                style: style
            )
            if let background = style.background,
               let color = color(for: background) {
                part.backgroundColor = color
            }
        }
        if style.isBold || style.isItalic {
            var font = terminalFont(fontPreferences)
            if style.isBold {
                font = font.bold()
            }
            if style.isItalic {
                font = font.italic()
            }
            part.font = font
        }
        if style.isUnderlined {
            part.underlineStyle = .single
        }
        if style.isStrikethrough {
            part.strikethroughStyle = .single
        }
    }

    private func color(for style: TerminalANSIStyle) -> Color {
        guard let foreground = style.foreground else {
            return defaultColor
        }
        return color(for: foreground) ?? defaultColor
    }

    private func renderedForegroundColor(_ color: Color, style: TerminalANSIStyle) -> Color {
        if style.isDim {
            return color.opacity(0.62)
        }
        if style.isBlinking {
            return color.opacity(0.82)
        }
        return color
    }

    private func color(for ansiColor: TerminalANSIColor) -> Color? {
        switch ansiColor {
        case .standardColor(let code):
            return standardColor(code)
        case .trueColor(let red, let green, let blue):
            return Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
        }
    }

    private var defaultColor: Color {
        switch line.role {
        case .prompt: Color(hex: theme.promptHex)
        case .stdout: Color(hex: theme.foregroundHex)
        case .stderr: Color(hex: theme.errorHex)
        case .system: Color(hex: theme.mutedHex)
        }
    }

    private func standardColor(_ code: Int) -> Color? {
        switch code {
        case 30: .black
        case 31: .red
        case 32: .green
        case 33: .yellow
        case 34: .blue
        case 35: .purple
        case 36: .cyan
        case 37: .white
        case 40: .black
        case 41: .red
        case 42: .green
        case 43: .yellow
        case 44: .blue
        case 45: .purple
        case 46: .cyan
        case 47: .white
        case 90: .gray
        case 91: .red
        case 92: .green
        case 93: .yellow
        case 94: .blue
        case 95: .purple
        case 96: .cyan
        case 97: .white
        case 100: .gray
        case 101: .red
        case 102: .green
        case 103: .yellow
        case 104: .blue
        case 105: .purple
        case 106: .cyan
        case 107: .white
        default: nil
        }
    }
}

/// A single row inside the completion menu, extracted to help type-checking.
private struct CompletionMenuRow: View {
    let item: CompletionCandidate
    let isSelected: Bool
    let font: NSFont
    let rowHeight: CGFloat
    let descriptionRowHeight: CGFloat
    let horizontalInset: CGFloat
    let kindIcon: (CompletionKind) -> String

    private var hasDesc: Bool { item.description?.isEmpty == false }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 8) {
                Text(kindIcon(item.kind))
                    .font(Typography.mono(11))
                    .foregroundColor(Color(DesignTokens.fg3))
                    .frame(width: 14, alignment: .leading)
                Text(item.title)
                    .font(Font(font))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            if let desc = item.description, !desc.isEmpty {
                Text(desc)
                    .font(Typography.ui(11))
                    .foregroundColor(Color(DesignTokens.fg3))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 22)
            }
        }
        .padding(.horizontal, horizontalInset)
        .frame(height: hasDesc ? descriptionRowHeight : rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
    }
}

/// F-3: keyboard-navigable Tab completion menu, composited above the
/// SwiftTerm view. Anchored via the same caret-origin callback the F-1
/// ghost-text overlay uses. Auto-flips upward when it would clip the bottom
/// of the viewport.
struct CompletionMenuOverlay: View {
    let snapshot: TermyStore.MenuSnapshot
    let anchor: CGPoint                  // SwiftUI top-left coords
    let viewportSize: CGSize
    let font: NSFont

    private let rowHeight: CGFloat = 22
    private let descriptionRowHeight: CGFloat = 34
    private let maxVisibleRows: Int = 8
    private let minWidth: CGFloat = 220
    private let horizontalInset: CGFloat = 8
    private let verticalInset: CGFloat = 4
    private let cornerRadius: CGFloat = 6

    private var hasAnyDescription: Bool {
        snapshot.items.contains { ($0.description?.isEmpty == false) }
    }

    private var menuMaxWidth: CGFloat {
        hasAnyDescription ? 480 : 320
    }

    private var maxHeight: CGFloat {
        let visibleItems = snapshot.items.prefix(maxVisibleRows)
        let totalRows = visibleItems.reduce(0) { sum, item in
            sum + ((item.description?.isEmpty == false) ? descriptionRowHeight : rowHeight)
        }
        return totalRows + 2 * verticalInset
    }

    private var width: CGFloat {
        let preferred = max(minWidth, menuMaxWidth)
        return max(min(preferred, viewportSize.width - 16), 120)
    }

    private var flipUpward: Bool {
        anchor.y + maxHeight > viewportSize.height
    }

    private var resolvedTop: CGFloat {
        flipUpward
            ? max(0, anchor.y - maxHeight - rowHeight)  // above the caret
            : anchor.y + rowHeight                       // below the caret
    }

    var body: some View {
        menuContent
            .frame(width: width, height: maxHeight)
            .background(menuBackground)
            .overlay(menuBorder)
            .position(x: min(max(anchor.x + width / 2, width / 2 + 4),
                             viewportSize.width - width / 2 - 4),
                      y: resolvedTop + maxHeight / 2)
    }

    private var menuContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            menuRows
                .padding(.vertical, verticalInset)
        }
    }

    private var menuRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hoist the instance method to a local: passing kindIcon directly inside the @ViewBuilder ForEach closure can trip the type-checker.
            let icon = kindIcon
            ForEach(Array(snapshot.items.enumerated()), id: \.offset) { idx, item in
                CompletionMenuRow(
                    item: item,
                    isSelected: idx == snapshot.selection,
                    font: font,
                    rowHeight: rowHeight,
                    descriptionRowHeight: descriptionRowHeight,
                    horizontalInset: horizontalInset,
                    kindIcon: icon
                )
            }
        }
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(DesignTokens.bg2))
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
    }

    private var menuBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(TermyDesign.subtleBorder, lineWidth: 0.5)
    }

    private func kindIcon(_ kind: CompletionKind) -> String {
        switch kind {
        case .command:    return "⌘"
        case .flag:       return "-"
        case .file:       return "/"
        case .gitBranch:  return "⎇"
        case .sshHost:    return "@"
        case .history:    return "↑"    // not used in F-3 (history: []), but keep mapping
        case .builtin:    return "⌥"
        case .alias:      return "~"
        case .directory:  return "/"
        case .option:     return "-"
        }
    }
}

private struct CommandInput: View {
    @Binding var command: String
    let suggestions: [CompletionCandidate]
    let inlineSuggestion: InlineAutosuggestion?
    let theme: TerminalTheme
    let fontPreferences: TerminalFontPreferences
    let acceptSuggestion: (CompletionCandidate) -> Void
    let acceptInlineSuggestion: (InlineAutosuggestion) -> Void
    let submit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.replacement) { suggestion in
                            Button {
                                acceptSuggestion(suggestion)
                            } label: {
                                Text(suggestion.title)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                }
            }

            HStack(spacing: 8) {
                Text("$")
                    .font(terminalFont(fontPreferences))
                    .foregroundStyle(Color(hex: theme.promptHex))
                ZStack(alignment: .leading) {
                    if let inlineSuggestion {
                        HStack(spacing: 0) {
                            Text(command)
                                .foregroundStyle(.clear)
                            Text(inlineSuggestion.ghostText)
                                .foregroundStyle(Color(hex: theme.foregroundHex).opacity(0.35))
                        }
                        .font(terminalFont(fontPreferences))
                        .allowsHitTesting(false)
                    }
                    TextField("Run local shell command", text: $command)
                        .textFieldStyle(.plain)
                        .font(terminalFont(fontPreferences))
                        .foregroundStyle(Color(hex: theme.foregroundHex))
                        .onSubmit(submit)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: TermyDesign.cornerRadius)
                    .fill(Color(hex: theme.foregroundHex).opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TermyDesign.cornerRadius)
                    .stroke(Color(hex: theme.promptHex).opacity(0.32), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .onKeyPress(.tab) {
                guard let inlineSuggestion else { return .ignored }
                acceptInlineSuggestion(inlineSuggestion)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                guard let inlineSuggestion else { return .ignored }
                acceptInlineSuggestion(inlineSuggestion)
                return .handled
            }
        }
        .background(Color(hex: theme.backgroundHex))
    }
}

private struct RemoteSessionPlaceholder: View {
    let session: TermySession
    let rdpFrame: RDPRemoteDesktopFrame?
    let handleRDPInput: ([RDPSlowPathInputEvent]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.profile.kind == .rdp, let rdpFrame {
                RDPRemoteDesktopFrameView(frame: rdpFrame, handleInput: handleRDPInput)
            } else {
                Text(session.profile.kind == .ssh ? "SSH connector surface" : "Embedded RDP surface")
                    .font(Typography.ui(15, weight: .semibold))
                Text("This session uses a saved profile and Keychain secret references. Transport implementation is intentionally isolated from the UI shell.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

private struct RDPRemoteDesktopFrameView: View {
    let frame: RDPRemoteDesktopFrame
    let handleInput: ([RDPSlowPathInputEvent]) -> Void

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = cgImage {
                    Image(decorative: image, scale: frame.scale, orientation: .up)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(.black)
                } else {
                    Text("RDP frame payload is invalid.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .focusable(true)
            .gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        let events = RDPInputEventMapper.pointerClickEvents(
                            at: RDPInputPoint(x: value.location.x, y: value.location.y),
                            viewport: RDPInputViewportSize(width: proxy.size.width, height: proxy.size.height),
                            frame: frame,
                            button: .left
                        )
                        handleInput(events)
                    }
            )
            .onKeyPress(phases: [.down, .repeat]) { keyPress in
                guard let input = RDPKeyboardInput(keyPress: keyPress) else {
                    return .ignored
                }
                let events = RDPKeyboardInputMapper.keyPressEvents(input)
                guard !events.isEmpty else { return .ignored }
                handleInput(events)
                return .handled
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private var cgImage: CGImage? {
        guard frame.hasValidPayload,
              let provider = CGDataProvider(data: frame.data as CFData)
        else {
            return nil
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        return CGImage(
            width: frame.width,
            height: frame.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: frame.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

private extension RDPKeyboardInput {
    init?(keyPress: KeyPress) {
        switch keyPress.key {
        case .return:
            self = .special(.enter)
        case .delete:
            self = .special(.backspace)
        case .tab:
            self = .special(.tab)
        case .escape:
            self = .special(.escape)
        case .upArrow:
            self = .special(.upArrow)
        case .downArrow:
            self = .special(.downArrow)
        case .leftArrow:
            self = .special(.leftArrow)
        case .rightArrow:
            self = .special(.rightArrow)
        default:
            guard keyPress.characters.count == 1,
                  let character = keyPress.characters.first else {
                return nil
            }
            self = .character(character)
        }
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
