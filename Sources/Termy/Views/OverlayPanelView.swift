import UniformTypeIdentifiers
import SwiftUI
import TermyCore

struct OverlayPanelView: View {
    let panel: OverlayPanel
    @ObservedObject var store: TermyStore
    var showsHeader = true

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
            HStack(spacing: 10) {
                Image(systemName: panel.systemImage)
                    .foregroundStyle(TermyDesign.accent)
                    .frame(width: 26, height: 26)
                    .background(TermyDesign.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(panel.title)
                        .font(Typography.ui(15, weight: .semibold))
                    Text(panel.subtitle)
                        .font(Typography.ui(12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    store.activePanel = nil
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(TermyIconButtonStyle())
                .help("Close panel")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(DesignTokens.bg2))

            Divider()
            }

            switch panel {
            case .ai:
                LocalAIPanel(store: store)
            case .files:
                FileExplorerPanel(store: store)
            case .git:
                GitPanel(store: store)
            case .editor:
                EditorPanel(store: store)
            case .connections:
                ConnectionsPanel(store: store)
            }
        }
        .background(TermyDesign.elevatedSurface)
    }
}

private struct LocalAIPanel: View {
    @ObservedObject var store: TermyStore
    /// Set when "Send to Terminal" is pressed on a destructive AI suggestion;
    /// drives the B4 confirmation dialog (offer, never take over).
    @State private var pendingDestructive: DestructiveCommandHeuristic.Verdict?

    /// Offline NL-vs-command read of the prompt field (AI-S6). Surfaced as a
    /// gentle inline offer — never auto-acts (B4). Empty/short prompts read as
    /// unknown and show nothing.
    private var promptClassification: NLCommandClassifier.NLClassification {
        NLCommandClassifier.classify(store.aiPrompt)
    }

    var body: some View {
        Form {
            Section("CLI Agents") {
                Button("Launch Codex") {
                    store.launchCLIAgent(.codex)
                }
                Button("Launch Claude Code") {
                    store.launchCLIAgent(.claudeCode)
                }
                Text("Agents run as external CLI tools in a PTY and use their own authentication.")
                    .foregroundStyle(.secondary)
            }

            Section("Local Model") {
                TextField("Local model endpoint", text: $store.aiEndpoint)
                modelPickers
                TextField("Describe command", text: $store.aiPrompt)
                nlOffer
                HStack {
                    Button("Validate Local Endpoint") {
                        store.validateLocalAIEndpoint()
                    }
                    Button("Suggest Command") {
                        store.suggestCommandWithLocalAI()
                    }
                    .disabled(promptIsEmpty || store.aiStreaming)
                    Button("Ask") {
                        store.askLocalAIQuestion()
                    }
                    .disabled(promptIsEmpty || store.aiStreaming)
                    Button("Explain Last Error") {
                        store.explainLastErrorWithLocalAI()
                    }
                    .disabled(store.aiStreaming)
                }
                if store.aiStreaming {
                    streamingBar
                }
                if !store.aiSuggestedCommand.isEmpty {
                    Text(store.aiSuggestedCommand)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Send to Terminal") {
                        sendSuggestedCommand()
                    }
                }
                if !store.aiExplanation.isEmpty {
                    Text(store.aiExplanation)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Built-in AI is constrained to localhost model servers such as Ollama or LM Studio.")
                    .foregroundStyle(.secondary)
            }

            Section("Project Guidance") {
                HStack {
                    Text(guidanceSummary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reload") {
                        store.reloadProjectGuidance()
                    }
                }
            }

            Section("Prompt Snippets") {
                TextField("Title", text: $store.promptSnippetTitle)
                TextField("Body", text: $store.promptSnippetBody, axis: .vertical)
                    .lineLimit(2...4)
                Button("Add Snippet") {
                    store.addPromptSnippet()
                }
                ForEach(store.userPromptSnippets) { snippet in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(snippet.title)
                            Text(snippet.body)
                                .font(Typography.ui(12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Insert") {
                            store.insertPromptSnippet(snippet)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        // B4 destructive gate: an AI-suggested command that destroys data/state
        // requires a second, conscious confirmation before it reaches the shell.
        .confirmationDialog(
            "Run a destructive command?",
            isPresented: Binding(get: { pendingDestructive != nil }, set: { if !$0 { pendingDestructive = nil } }),
            presenting: pendingDestructive
        ) { _ in
            Button("Run command", role: .destructive) {
                pendingDestructive = nil
                store.sendSuggestedCommandToTerminal()
            }
            Button("Cancel", role: .cancel) { pendingDestructive = nil }
        } message: { verdict in
            Text(verdict.primaryReason ?? "This command may destroy data or state.")
        }
    }

    private var promptIsEmpty: Bool {
        store.aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Live streaming indicator + Cancel (Esc). Shown ONLY while a request is in
    /// flight so the Esc binding (`.cancelAction`) does not shadow other Esc
    /// semantics (panel close) when nothing is streaming.
    private var streamingBar: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Streaming from the local model…")
                .font(Typography.ui(12)).foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { store.cancelAIRequest() }
                .keyboardShortcut(.cancelAction)
                .help("Stop the local AI request (Esc)")
        }
    }

    /// Model role pickers. When the server has been queried (`discoveredModels`
    /// non-empty) the chat/completion roles become pickers over the installed
    /// models; otherwise the manual model TextField remains the only path so an
    /// offline-configured endpoint still works. A "Discover models" button
    /// issues the loopback `GET /api/tags` (never auto-fired on appear).
    @ViewBuilder private var modelPickers: some View {
        if store.discoveredModels.isEmpty {
            HStack {
                TextField("Model", text: $store.aiModel)
                Button("Discover models") { store.discoverLocalAIModels() }
            }
        } else {
            Picker("Chat model", selection: $store.chatModel) {
                ForEach(store.discoveredModels) { Text(modelLabel($0)).tag($0.name) }
            }
            Picker("Completion model", selection: $store.completionModel) {
                ForEach(store.discoveredModels) { Text(modelLabel($0)).tag($0.name) }
            }
            Button("Rediscover models") { store.discoverLocalAIModels() }
        }
    }

    private func modelLabel(_ model: DiscoveredModel) -> String {
        if let size = model.parameterSize { return "\(model.name) · \(size)" }
        return model.name
    }

    /// Offline NL-vs-command offer (AI-S6). When the typed prompt reads as a
    /// natural-language request, gently offer to translate it — a conscious tap
    /// (B4), never an auto-run. Hidden for command-shaped or empty input.
    @ViewBuilder private var nlOffer: some View {
        if promptClassification.suggestedAction == .offerNLToCommand, !store.aiStreaming {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(Color(DesignTokens.ai.base))
                Text("Looks like a request — turn it into a command?")
                    .font(Typography.ui(12)).foregroundStyle(.secondary)
                Spacer()
                Button("Suggest command") { store.suggestCommandWithLocalAI() }
            }
        }
    }

    /// Route an AI-suggested command through the destructive gate before it runs.
    private func sendSuggestedCommand() {
        let command = store.aiSuggestedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let verdict = DestructiveCommandHeuristic.evaluate(command)
        if verdict.requiresConfirmation {
            pendingDestructive = verdict
        } else {
            store.sendSuggestedCommandToTerminal()
        }
    }

    private var guidanceSummary: String {
        let names = store.projectGuidance.documents.map(\.fileName)
        return names.isEmpty ? "No TERMY.md, CLAUDE.md, or AGENTS.md found." : names.joined(separator: ", ")
    }
}

private struct FileExplorerPanel: View {
    @ObservedObject var store: TermyStore
    @State private var showSFTP = false
    @State private var showNewItem = false
    @State private var renaming = false
    @State private var moving = false
    /// Bumped to ask the Quick Look host to toggle the preview panel (context-menu
    /// "Quick Look" path; the Space key is handled inside the host's responder).
    @State private var quickLookTrigger = 0

    private var sshProfile: ConnectionProfile? { store.profiles.first { $0.kind == .ssh } }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color(DesignTokens.hair))
            tree
            if store.selectedFilePath != nil {
                Divider().overlay(Color(DesignTokens.hair))
                selectionBar
            }
        }
        .buttonStyle(TermyCompactButtonStyle())
        .onAppear { store.refreshFilesAsync() }
        .sheet(isPresented: $showSFTP) {
            if let profile = sshProfile { FileSFTPSheet(store: store, profile: profile) { showSFTP = false } }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(DesignTokens.Glass.textTertiary)
                TextField("Search files", text: $store.fileSearchQuery).textFieldStyle(.plain).font(Typography.ui(13))
            }
            .padding(.horizontal, 11).frame(height: 28).frame(maxWidth: 280)
            .background(DesignTokens.Glass.fillControl, in: Capsule())
            .overlay(Capsule().stroke(DesignTokens.Glass.hairline, lineWidth: 1))

            Button { showNewItem = true } label: { Label("New", systemImage: "plus") }
                .popover(isPresented: $showNewItem, arrowEdge: .bottom) { newItemPopover }
            Button { store.refreshFilesAsync() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh")
            Spacer()
            if sshProfile != nil {
                Button { showSFTP = true } label: { Label("SFTP", systemImage: "externaldrive.connected.to.line.below") }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var newItemPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New file or folder").font(Typography.ui(12, weight: .semibold))
            TextField("Name or path", text: $store.fileDraftName).textFieldStyle(GlassTextFieldStyle()).frame(width: 240)
            HStack {
                Button { store.createFileFromDraft(); showNewItem = false } label: { Label("File", systemImage: "doc") }
                Button { store.createDirectoryFromDraft(); showNewItem = false } label: { Label("Folder", systemImage: "folder") }
            }
            .disabled(store.fileDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .buttonStyle(TermyCompactButtonStyle())
        .padding(12)
    }

    /// During a search the tree flattens to matching files (depth 0); disclosure
    /// chevrons and expand-on-tap only make sense in the navigable (non-search) view.
    private var isSearching: Bool {
        !store.fileSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tree: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(store.visibleFileTreeItems) { treeItem in
                    fileRow(treeItem)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if store.visibleFileTreeItems.isEmpty {
                ContentUnavailableView(store.fileSearchQuery.isEmpty ? "No files" : "No matches", systemImage: "folder")
            }
        }
        .background(
            QuickLookHost(url: store.selectedFileURL, trigger: quickLookTrigger)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }

    private func fileRow(_ treeItem: LocalFileTreeItem) -> some View {
        let showDisclosure = treeItem.item.isDirectory && !isSearching
        let item = treeItem.item
        return FileTreeRowView(
            treeItem: treeItem,
            selected: store.selectedFilePath == item.relativePath,
            expanded: store.isFileDirectoryExpanded(item.relativePath),
            showDisclosure: showDisclosure
        ) {
            store.selectedFilePath = item.relativePath
            if showDisclosure { store.toggleFileDirectory(item.relativePath) }
        }
        .contextMenu { rowContextMenu(for: item) }
    }

    /// Right-click actions mirroring the selection bar plus M6 additions
    /// (Quick Look, Reveal in Finder). Selecting the row first keeps the
    /// store-backed actions targeting the clicked item.
    @ViewBuilder
    private func rowContextMenu(for item: LocalFileItem) -> some View {
        Button("Quick Look") {
            store.selectedFilePath = item.relativePath
            quickLookTrigger += 1
        }
        Button("Reveal in Finder") {
            store.selectedFilePath = item.relativePath
            store.revealSelectedFileInFinder()
        }
        Divider()
        if !item.isDirectory {
            Button("Open") {
                store.selectedFilePath = item.relativePath
                store.openSelectedFileInEditor()
            }
        }
        Button("Rename") {
            store.selectedFilePath = item.relativePath
            renaming = true
        }
        Button("Move") {
            store.selectedFilePath = item.relativePath
            moving = true
        }
        Divider()
        Button("Delete", role: .destructive) {
            store.selectedFilePath = item.relativePath
            store.deleteSelectedFile()
        }
    }

    /// Contextual action bar for the selected file (rename/move via popovers).
    private var selectionBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text").font(.system(size: 11)).foregroundStyle(Color(DesignTokens.fg3))
            Text(store.selectedFilePath ?? "").font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg2))
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Button { store.openSelectedFileInEditor() } label: { Label("Open", systemImage: "square.and.pencil") }
            Button { quickLookTrigger += 1 } label: { Label("Quick Look", systemImage: "eye") }.help("Quick Look (Space)")
            Button { store.revealSelectedFileInFinder() } label: { Label("Reveal", systemImage: "folder") }.help("Reveal in Finder")
            Button { renaming = true } label: { Label("Rename", systemImage: "pencil") }
                .popover(isPresented: $renaming, arrowEdge: .top) {
                    fieldPopover("Rename to", text: $store.fileRenameName) { store.renameSelectedFile(); renaming = false }
                }
            Button { moving = true } label: { Label("Move", systemImage: "arrow.right") }
                .popover(isPresented: $moving, arrowEdge: .top) {
                    fieldPopover("Move to folder", text: $store.fileMoveDestination) { store.moveSelectedFile(); moving = false }
                }
            Button(role: .destructive) { store.deleteSelectedFile() } label: { Label("Delete", systemImage: "trash") }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(DesignTokens.bg1))
    }

    private func fieldPopover(_ title: String, text: Binding<String>, confirm: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Typography.ui(12, weight: .semibold))
            TextField(title, text: text).textFieldStyle(GlassTextFieldStyle()).frame(width: 260)
            Button("Confirm", action: confirm).buttonStyle(TermyCommandButtonStyle(emphasized: true))
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
    }
}

/// One row in the Files Finder-lite tree. Pure inputs (no store) so it renders
/// in isolation for the static visual gate. Directories get a disclosure chevron
/// and an open/closed folder glyph (blue, matching the completion-menu folder
/// tint); files show their neutral type icon.
struct FileTreeRowView: View {
    let treeItem: LocalFileTreeItem
    let selected: Bool
    let expanded: Bool
    let showDisclosure: Bool
    let onTap: () -> Void

    /// Compact trailing metadata: "size · date" for files, just the date for
    /// directories (type is conveyed by the icon). Nil when nothing is known.
    private var metadataLabel: String? {
        let item = treeItem.item
        let size = LocalFileMetadata.sizeLabel(item.byteCount)
        let date = LocalFileMetadata.dateLabel(item.modificationDate)
        let joined = [size, date].compactMap { $0 }.joined(separator: " · ")
        return joined.isEmpty ? nil : joined
    }

    var body: some View {
        let isDir = treeItem.item.isDirectory
        let icon = isDir ? (expanded ? "folder.fill" : "folder") : treeItem.iconName
        Button(action: onTap) {
            HStack(spacing: 6) {
                Spacer().frame(width: CGFloat(treeItem.depth) * 14)
                Group {
                    if showDisclosure {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(DesignTokens.fg4))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 10)
                Image(systemName: icon)
                    .foregroundStyle(isDir ? Color(DesignTokens.primary2) : Color(DesignTokens.fg3))
                    .frame(width: 16, alignment: .center)
                Text(treeItem.item.name).foregroundStyle(Color(DesignTokens.fg1))
                Spacer(minLength: 8)
                if let meta = metadataLabel {
                    Text(meta)
                        .font(Typography.mono(11))
                        .foregroundStyle(Color(DesignTokens.fg4))
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
            }
            .font(Typography.ui(13))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? DesignTokens.Glass.fillSelection : Color.clear,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.row))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(treeItem.item.relativePath)
    }
}

/// SFTP transfer surface, lifted into a sheet off the Files toolbar.
private struct FileSFTPSheet: View {
    @ObservedObject var store: TermyStore
    let profile: ConnectionProfile
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SFTP — \(profile.name)").font(Typography.ui(14, weight: .semibold))
                Spacer()
                Button("Done", action: onClose)
            }
            .padding(14)
            Divider().overlay(Color(DesignTokens.hair))
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Remote path", text: $store.sftpRemotePath).textFieldStyle(GlassTextFieldStyle())
                    Button("Browse") { store.refreshSFTPFiles(profile: profile) }
                }
                HStack {
                    Button { store.uploadSelectedFileToSFTP(profile: profile) } label: { Label("Upload", systemImage: "arrow.up") }
                        .disabled(store.selectedFilePath == nil)
                    Button { store.downloadSelectedSFTPFile(profile: profile) } label: { Label("Download", systemImage: "arrow.down") }
                        .disabled(store.selectedSFTPRemotePath == nil)
                    Button { store.createSFTPDirectoryFromDraft(profile: profile) } label: { Label("New Folder", systemImage: "folder.badge.plus") }
                        .disabled(store.fileDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { store.renameSelectedSFTPItem(profile: profile) } label: { Label("Rename", systemImage: "pencil") }
                        .disabled(store.selectedSFTPRemotePath == nil)
                    Button(role: .destructive) { store.deleteSelectedSFTPItem(profile: profile) } label: { Label("Delete", systemImage: "trash") }
                        .disabled(store.selectedSFTPRemotePath == nil)
                }
                Text("Drop local files here to upload; drag a remote item out to download.")
                    .font(Typography.ui(12)).foregroundStyle(DesignTokens.Glass.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    .background(DesignTokens.Glass.fillControl, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.control))
                    .onDrop(of: [UTType.fileURL.identifier, UTType.text.identifier], isTargeted: nil) { handleSFTPDrop(providers: $0, profile: profile) }
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(store.filteredSFTPRemoteItems, id: \.path) { item in
                            Button { store.selectedSFTPRemotePath = item.path } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.isDirectory ? "folder" : "doc")
                                        .foregroundStyle(Color(DesignTokens.fg3))
                                    Text(item.name).foregroundStyle(Color(DesignTokens.fg1))
                                    Spacer(minLength: 0)
                                }
                                .font(Typography.ui(13)).padding(.horizontal, 8).padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(store.selectedSFTPRemotePath == item.path ? DesignTokens.Glass.fillSelection : Color.clear,
                                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.row))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .draggable(item.path)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay { if store.sftpRemoteItems.isEmpty { Text("Browse to list remote files.").font(Typography.ui(12)).foregroundStyle(DesignTokens.Glass.textTertiary) } }
            }
            .padding(16)
        }
        .frame(width: 620, height: 560)
        .background(Color(DesignTokens.bg1))
        .buttonStyle(TermyCompactButtonStyle())
    }

    private func handleSFTPDrop(providers: [NSItemProvider], profile: ConnectionProfile) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL? = (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) } ?? (item as? URL)
                    if let url { Task { @MainActor in store.uploadDroppedLocalFilesToSFTP([url], profile: profile) } }
                }
            } else if provider.canLoadObject(ofClass: NSString.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSString.self) { text, _ in
                    guard let path = text as? String else { return }
                    Task { @MainActor in
                        guard let item = store.sftpRemoteItems.first(where: { $0.path == path }) else { return }
                        store.downloadDroppedSFTPItem(item, profile: profile)
                    }
                }
            }
        }
        return handled
    }
}

private struct GitPanel: View {
    @ObservedObject var store: TermyStore
    @State private var showDiff = false

    var body: some View {
        Group {
            if store.gitIsRepository {
                VStack(spacing: 0) {
                    header
                    Divider().overlay(Color(DesignTokens.hair))
                    HStack(spacing: 0) {
                        GitChangesPane(store: store)
                            .frame(width: 340)
                        Divider().overlay(Color(DesignTokens.hair))
                        GitHistoryView(store: store, showDiff: $showDiff)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Not a git repository", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text("Open a shell session inside a repository, then return here.")
                }
            }
        }
        .buttonStyle(TermyCompactButtonStyle())
        .onAppear { store.refreshGitStatus() }
        // M2: re-refresh when the active session's cwd crosses into/out of a repo
        // (gitTrackedRootPath changes), so the module follows the live session.
        .onChange(of: store.gitTrackedRootPath) { store.refreshGitStatus() }
        .sheet(isPresented: $showDiff) {
            GitDiffSheet(store: store) { showDiff = false }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch").font(.system(size: 12))
                .foregroundStyle(Color(DesignTokens.git.base))
            Picker("", selection: $store.selectedGitBranch) {
                ForEach(store.gitBranches, id: \.self) { Text($0).tag(Optional($0)) }
            }
            .labelsHidden().fixedSize()
            Button("Checkout") { store.checkoutSelectedGitBranch() }
                .disabled(store.selectedGitBranch == nil)
            if let d = store.gitDivergence, d.ahead > 0 || d.behind > 0 {
                HStack(spacing: 6) {
                    if d.ahead > 0 { Label("\(d.ahead)", systemImage: "arrow.up").labelStyle(.titleAndIcon) }
                    if d.behind > 0 { Label("\(d.behind)", systemImage: "arrow.down").labelStyle(.titleAndIcon) }
                }
                .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg3))
            }
            Spacer()
            Button { store.refreshGitDiff(); showDiff = true } label: { Label("Diff", systemImage: "plusminus") }
            Button { store.pullCurrentGitBranch() } label: { Label("Pull", systemImage: "arrow.down") }
            Button { store.pushCurrentGitBranch() } label: { Label("Push", systemImage: "arrow.up") }
            Button { store.refreshGitStatus() } label: { Image(systemName: "arrow.clockwise") }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

/// Left pane: working-tree changes (staged/unstaged/untracked) + commit box.
private struct GitChangesPane: View {
    @ObservedObject var store: TermyStore

    private var staged: [GitChange] { store.gitChanges.filter { $0.isStaged && !$0.isUntracked } }
    private var unstaged: [GitChange] { store.gitChanges.filter { $0.isUnstaged && !$0.isStaged && !$0.isUntracked } }
    private var untracked: [GitChange] { store.gitChanges.filter { $0.isUntracked } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CHANGES").font(.system(size: 11, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(DesignTokens.Glass.textTertiary)
                Spacer()
                if !store.gitChanges.isEmpty {
                    Button("Stage All") { store.stageAllGitChanges() }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if store.gitChanges.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle").font(.system(size: 20))
                        .foregroundStyle(Color(DesignTokens.sync.base))
                    Text("Working tree clean").font(Typography.ui(12))
                        .foregroundStyle(DesignTokens.Glass.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        changeSection("Staged", staged, tint: DesignTokens.sync.base)
                        changeSection("Changed", unstaged, tint: DesignTokens.agent.base)
                        changeSection("Untracked", untracked, tint: DesignTokens.fg4)
                    }
                    .padding(.horizontal, 8)
                }
            }

            Divider().overlay(Color(DesignTokens.hair))
            VStack(spacing: 8) {
                TextField("Commit message", text: $store.gitCommitMessage, axis: .vertical)
                    .textFieldStyle(GlassTextFieldStyle()).lineLimit(1...3)
                HStack {
                    Button { store.commitGitChanges() } label: { Label("Commit", systemImage: "checkmark") }
                        .disabled(store.gitCommitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { store.suggestGitCommitMessageWithLocalAI() } label: { Label("AI", systemImage: "sparkles") }
                    Spacer()
                }
                HStack {
                    TextField("New branch", text: $store.gitBranchDraft).textFieldStyle(GlassTextFieldStyle())
                    Button("Create") { store.createGitBranch() }
                        .disabled(store.gitBranchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder private func changeSection(_ title: String, _ items: [GitChange], tint: OKLCH) -> some View {
        if !items.isEmpty {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.5)
                .foregroundStyle(DesignTokens.Glass.textQuaternary)
                .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 2)
            ForEach(items) { change in
                HStack(spacing: 8) {
                    Text(String([change.x, change.y]).trimmingCharacters(in: .whitespaces))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(tint)).frame(width: 18, alignment: .leading)
                    Text(change.path).font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg2))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
            }
        }
    }
}

/// Right pane: commit history with a graph rail (node + spine) and ref chips.
private struct GitHistoryView: View {
    @ObservedObject var store: TermyStore
    @Binding var showDiff: Bool

    var body: some View {
        let commits = store.gitRecentCommits
        if commits.isEmpty {
            ContentUnavailableView("No commits", systemImage: "clock")
        } else {
            let layout = GitGraphLayout.compute(commits)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(layout.rows) { row in
                        // M2: lazy per-commit diff — `git show` runs only on tap.
                        GitGraphRowView(row: row, maxLanes: layout.maxLanes)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.loadDiff(forCommit: row.commit.hash)
                                showDiff = true
                            }
                    }
                }
                .padding(.vertical, 8).padding(.trailing, 16)
            }
        }
    }
}

/// Lane colors cycle a small on-brand palette so adjacent branches read apart.
enum GitGraphPalette {
    static let colors: [Color] = [
        Color(DesignTokens.git.base),
        Color(DesignTokens.host.base),
        Color(DesignTokens.agent.base),
        Color(DesignTokens.sync.base),
        Color(DesignTokens.primary2),
    ]
    static func color(_ lane: Int) -> Color { colors[((lane % colors.count) + colors.count) % colors.count] }
}

struct GitGraphRowView: View {
    let row: GitGraphRow
    let maxLanes: Int
    private let rowHeight: CGFloat = 48
    private let laneSpacing: CGFloat = 16

    private var railWidth: CGFloat { CGFloat(max(maxLanes, 1)) * laneSpacing }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            GitGraphCell(row: row, laneSpacing: laneSpacing)
                .frame(width: railWidth, height: rowHeight)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    ForEach(refChips, id: \.self) { ref in
                        Text(ref)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignTokens.Glass.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(DesignTokens.Glass.fillChip, in: Capsule())
                    }
                    Text(row.commit.subject).font(Typography.ui(13)).foregroundStyle(Color(DesignTokens.fg1))
                        .lineLimit(1).truncationMode(.tail)
                }
                HStack(spacing: 6) {
                    Text(row.commit.shortHash).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(DesignTokens.git.base))
                    Text(row.commit.author).font(Typography.ui(11)).foregroundStyle(DesignTokens.Glass.textTertiary)
                    Text("· \(row.commit.relativeDate)").font(Typography.ui(11)).foregroundStyle(DesignTokens.Glass.textQuaternary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .frame(height: rowHeight)
    }

    /// Decoded ref names without the "HEAD -> " prefix noise; tags shown bare.
    private var refChips: [String] {
        row.commit.refNames.compactMap { raw in
            if raw.hasPrefix("HEAD -> ") { return String(raw.dropFirst("HEAD -> ".count)) }
            if raw == "HEAD" { return "HEAD" }
            if raw.hasPrefix("tag: ") { return String(raw.dropFirst("tag: ".count)) }
            return raw
        }
    }
}

/// Draws one commit-graph row: pass-through lanes, the merge-in / branch-out
/// diagonals around this commit, and the node — all from the pure GitGraphLayout.
private struct GitGraphCell: View {
    let row: GitGraphRow
    let laneSpacing: CGFloat

    private func x(_ lane: Int) -> CGFloat { CGFloat(lane) * laneSpacing + laneSpacing / 2 }

    var body: some View {
        Canvas { ctx, size in
            let cy = size.height / 2
            func line(_ a: CGPoint, _ b: CGPoint, _ color: Color) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(color), lineWidth: 1.5)
            }
            for pt in row.passThrough {
                line(CGPoint(x: x(pt.top), y: 0), CGPoint(x: x(pt.bottom), y: size.height),
                     GitGraphPalette.color(pt.bottom))
            }
            for top in row.mergeIntoNode {
                line(CGPoint(x: x(top), y: 0), CGPoint(x: x(row.node), y: cy), GitGraphPalette.color(top))
            }
            for bottom in row.branchFromNode {
                line(CGPoint(x: x(row.node), y: cy), CGPoint(x: x(bottom), y: size.height),
                     GitGraphPalette.color(bottom))
            }
            let radius: CGFloat = 4.5
            let nodeRect = CGRect(x: x(row.node) - radius, y: cy - radius, width: radius * 2, height: radius * 2)
            // Punch a ring in the pane background so crossing lines read behind the node.
            ctx.fill(Path(ellipseIn: nodeRect.insetBy(dx: -2, dy: -2)), with: .color(Color(DesignTokens.bg2)))
            ctx.fill(Path(ellipseIn: nodeRect),
                     with: .color(row.commit.isMerge ? Color(DesignTokens.primary2) : Color(DesignTokens.git.base)))
        }
    }
}

/// Full diff in a sheet (kept off the main two-column view).
private struct GitDiffSheet: View {
    @ObservedObject var store: TermyStore
    let onClose: () -> Void

    private var text: String {
        if !store.gitConflictExplanation.isEmpty { return store.gitConflictExplanation }
        return store.gitDiff.isEmpty ? "No diff — working tree clean or nothing staged." : store.gitDiff
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.gitDiffTitle).font(Typography.ui(14, weight: .semibold))
                Spacer()
                Button { store.explainGitConflictsWithLocalAI() } label: { Label("Explain Conflicts", systemImage: "sparkles") }
                    .buttonStyle(TermyCompactButtonStyle())
                Button("Done", action: onClose).buttonStyle(TermyCompactButtonStyle())
            }
            .padding(12)
            Divider()
            ScrollView {
                Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(Color(DesignTokens.bg1))
    }
}

private struct EditorPanel: View {
    @ObservedObject var store: TermyStore
    @State private var showAI = false

    var body: some View {
        VStack(spacing: 0) {
            editorTabStrip
                .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: store.editorFilePath == nil ? "doc.text" : "doc")
                    .font(.system(size: 12)).foregroundStyle(Color(DesignTokens.fg3))
                Text(store.editorFilePath.map { ($0 as NSString).lastPathComponent } ?? "Scratch")
                    .font(Typography.ui(13, weight: .medium)).foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                Spacer()
                Button { showAI = true } label: { Label("AI", systemImage: "sparkles") }
                    .popover(isPresented: $showAI, arrowEdge: .bottom) { aiPopover }
                Toggle("Vim", isOn: Binding(get: { store.editorVimEnabled },
                                            set: { store.setEditorVimEnabled($0) }))
                    .toggleStyle(.switch).tint(DesignTokens.Glass.accent).fixedSize()
                Button { store.saveEditorFile() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    .buttonStyle(TermyCommandButtonStyle(emphasized: true)).disabled(store.editorFilePath == nil)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            if store.editorVimEnabled {
                HStack(spacing: 8) {
                    Text("Vim \(store.editorVimState.mode.label)")
                        .font(Typography.ui(12))
                        .foregroundStyle(.secondary)
                    Text("Cursor \(store.editorVimState.cursorOffset)")
                        .font(Typography.ui(12))
                        .foregroundStyle(.secondary)
                    if let selection = store.editorVimState.visualSelectionRange {
                        Text("Selection \(selection.lowerBound)-\(selection.upperBound)")
                            .font(Typography.ui(12))
                            .foregroundStyle(.secondary)
                    }
                    if let pendingCount = store.editorVimState.pendingCount {
                        Text("Count \(pendingCount)")
                            .font(Typography.ui(12))
                            .foregroundStyle(.secondary)
                    }
                    if let pendingOperator = store.editorVimState.pendingOperator {
                        Text("Operator \(pendingOperator.label)")
                            .font(Typography.ui(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ForEach(1...3, id: \.self) { digit in
                        Button("\(digit)") { store.applyEditorVimCommand(.countDigit(digit)) }
                    }
                    Button("h") { store.applyEditorVimCommand(.moveLeft) }
                    Button("j") { store.applyEditorVimCommand(.moveDown) }
                    Button("k") { store.applyEditorVimCommand(.moveUp) }
                    Button("l") { store.applyEditorVimCommand(.moveRight) }
                    Button("J") { store.applyEditorVimCommand(.joinLineBelow) }
                    Button("0") { store.applyEditorVimCommand(.moveLineStart) }
                    Button("$") { store.applyEditorVimCommand(.moveLineEnd) }
                    Button("%") { store.applyEditorVimCommand(.moveMatchingBracket) }
                    Button("gg") { store.applyEditorVimCommand(.moveDocumentStart) }
                    Button("G") { store.applyEditorVimCommand(.moveDocumentEnd) }
                    Button("w") { store.applyEditorVimCommand(.moveWordForward) }
                    Button("b") { store.applyEditorVimCommand(.moveWordBackward) }
                    Button("e") { store.applyEditorVimCommand(.moveWordEnd) }
                    Button("d") { store.applyEditorVimCommand(.deleteOperator) }
                    Button("D") { store.applyEditorVimCommand(.deleteToLineEnd) }
                    Button("c") { store.applyEditorVimCommand(.changeOperator) }
                    Button("C") { store.applyEditorVimCommand(.changeToLineEnd) }
                    Button("y") { store.applyEditorVimCommand(.yankOperator) }
                    Button("Y") { store.applyEditorVimCommand(.yankToLineEnd) }
                    Button("u") { store.applyEditorVimCommand(.undoLastChange) }
                    Button("Ctrl-R") { store.applyEditorVimCommand(.redoLastUndo) }
                    Button("P") { store.applyEditorVimCommand(.pasteBefore) }
                    Button("p") { store.applyEditorVimCommand(.pasteAfter) }
                    Button("x") { store.applyEditorVimCommand(.deleteCharacter) }
                    Button("X") { store.applyEditorVimCommand(.deleteCharacterBeforeCursor) }
                    Button("s") { store.applyEditorVimCommand(.substituteCharacter) }
                    Button("S") { store.applyEditorVimCommand(.substituteLine) }
                    Button("~") { store.applyEditorVimCommand(.toggleCharacterCase) }
                    Button("v") { store.applyEditorVimCommand(.enterVisualMode) }
                    Button("i") { store.applyEditorVimCommand(.enterInsertMode) }
                    Button("I") { store.applyEditorVimCommand(.enterInsertLineStartMode) }
                    Button("a") { store.applyEditorVimCommand(.enterAppendMode) }
                    Button("A") { store.applyEditorVimCommand(.enterAppendLineMode) }
                    Button("o") { store.applyEditorVimCommand(.openLineBelow) }
                    Button("O") { store.applyEditorVimCommand(.openLineAbove) }
                    Button("Esc") { store.applyEditorVimCommand(.enterNormalMode) }
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
            }

            HighlightedCodeEditor(
                // The unnamed scratch buffer keeps its prior Markdown default
                // (its seed content is a "# Termy Scratch" heading) — matches the
                // old editorSyntaxTokens() `?? "Scratch.md"` fallback.
                text: editorText,
                fileName: store.editorFilePath.map { ($0 as NSString).lastPathComponent } ?? "Scratch.md"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !store.editorAIDiff.isEmpty {
                Divider()
                if !store.editorAIMultiFilePatchPaths.isEmpty {
                    HStack(spacing: 8) {
                        Text("Patch files")
                            .font(Typography.ui(12))
                            .foregroundStyle(.secondary)
                        ForEach(store.editorAIMultiFilePatchPaths, id: \.self) { path in
                            Text(path)
                                .font(Typography.mono(12))
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                }
                ScrollView(.horizontal) {
                    Text(store.editorAIDiff)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 140)
                .background(Color(DesignTokens.bg2))
            }
            if !store.editorAICompletion.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI completion")
                        .font(Typography.ui(12))
                        .foregroundStyle(.secondary)
                    Text(store.editorAICompletion)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color(DesignTokens.bg2))
            }
        }
        // Compact glass toolbar buttons; the Vim key bar sets its own .bordered style.
        .buttonStyle(TermyCompactButtonStyle())
    }

    /// AI actions + instruction, lifted out of the toolbar into a focused popover.
    private var aiPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local AI").font(Typography.ui(12, weight: .semibold))
            TextField("Edit instruction", text: $store.editorAIInstruction, axis: .vertical)
                .textFieldStyle(GlassTextFieldStyle()).lineLimit(1...3).frame(width: 280)
            HStack {
                Button { store.suggestEditorEditWithLocalAI() } label: { Label("Propose", systemImage: "wand.and.stars") }
                    .disabled(store.editorAIInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button { store.explainEditorSelectionWithLocalAI() } label: { Label("Explain", systemImage: "text.magnifyingglass") }
                    .disabled(store.editorVimState.visualSelectionRange == nil)
                Button { store.suggestEditorCompletionWithLocalAI() } label: { Label("Complete", systemImage: "text.append") }
            }
            HStack {
                Button { store.acceptEditorAIProposal() } label: { Label("Accept edit", systemImage: "checkmark") }
                    .disabled(store.editorAIProposal.isEmpty)
                Button { store.acceptEditorAICompletion() } label: { Label("Accept completion", systemImage: "checkmark.circle") }
                    .disabled(store.editorAICompletion.isEmpty)
                Button { store.applyEditorAIMultiFilePatch() } label: { Label("Apply patch", systemImage: "doc.badge.gearshape") }
                    .disabled(store.editorAIMultiFilePatch.isEmpty)
            }
        }
        .buttonStyle(TermyCompactButtonStyle())
        .padding(12)
    }

    /// Multi-file tab strip (M3). One pill per open buffer: active = filled,
    /// others ghost; per-tab dirty dot; close (x) button. ⌘1-9 / ⌘⇧[ ⌘⇧] switch.
    private var editorTabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(store.openBuffers.enumerated()), id: \.element.id) { index, buffer in
                    if index < 9 {
                        editorTab(buffer, index: index)
                            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    } else {
                        editorTab(buffer, index: index)
                    }
                }
                Button { store.newScratchBuffer() } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(TermyCompactButtonStyle())
                .help("New scratch buffer")
                Button { store.presentEditorQuickOpen() } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(TermyCompactButtonStyle())
                .help("Quick Open file or buffer (⌘P)")
            }
        }
        .background {
            // Hidden keyboard-only switchers for ⌘⇧[ / ⌘⇧] (prev/next tab).
            Group {
                Button("") { switchBuffer(by: -1) }.keyboardShortcut("[", modifiers: [.command, .shift])
                Button("") { switchBuffer(by: 1) }.keyboardShortcut("]", modifiers: [.command, .shift])
            }
            .opacity(0).frame(width: 0, height: 0)
        }
    }

    private func editorTab(_ buffer: EditorBuffer, index: Int) -> some View {
        let isActive = buffer.id == store.activeBufferID
        let name = buffer.filePath.map { ($0 as NSString).lastPathComponent } ?? "Scratch"
        return HStack(spacing: 6) {
            if buffer.isDirty {
                Circle().fill(Color(DesignTokens.primary2)).frame(width: 6, height: 6)
            }
            Text(name)
                .font(Typography.ui(12, weight: isActive ? .medium : .regular))
                .foregroundStyle(Color(isActive ? DesignTokens.fg1 : DesignTokens.fg3))
                .lineLimit(1)
            if store.openBuffers.count > 1 {
                Button { store.closeEditorBuffer(buffer.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(DesignTokens.fg4))
                .help("Close buffer")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(isActive ? DesignTokens.bg2 : DesignTokens.bg1))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color(DesignTokens.hair), lineWidth: isActive ? 1 : 0)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { store.selectEditorBuffer(buffer.id) }
    }

    private func switchBuffer(by delta: Int) {
        guard let current = store.openBuffers.firstIndex(where: { $0.id == store.activeBufferID }),
              !store.openBuffers.isEmpty else { return }
        let count = store.openBuffers.count
        let next = ((current + delta) % count + count) % count
        store.selectEditorBuffer(store.openBuffers[next].id)
    }

    private var editorText: Binding<String> {
        Binding(
            get: { store.scratchText },
            set: { newValue in
                store.scratchText = newValue
                if store.editorVimEnabled {
                    store.editorVimState = VimEditorState(buffer: newValue)
                }
            }
        )
    }
}

private extension VimEditorMode {
    var label: String {
        switch self {
        case .normal:
            return "NORMAL"
        case .insert:
            return "INSERT"
        case .visual:
            return "VISUAL"
        }
    }
}

private extension VimEditorOperator {
    var label: String {
        switch self {
        case .delete:
            return "d"
        case .change:
            return "c"
        case .yank:
            return "y"
        }
    }
}

private enum ConnSheet: String, Identifiable { case ssh, rdp, tunnels, keys; var id: String { rawValue } }

private struct ConnectionsPanel: View {
    @ObservedObject var store: TermyStore
    @State private var sheet: ConnSheet?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { sheet = .ssh } label: { Label("New SSH", systemImage: "plus") }
                Button { sheet = .rdp } label: { Label("New RDP", systemImage: "display") }
                Button { sheet = .tunnels } label: { Label("Tunnels", systemImage: "arrow.left.arrow.right") }
                Button { sheet = .keys } label: { Label("SSH Keys", systemImage: "key") }
                Spacer()
                Button { store.importSSHConfig() } label: { Label("Import", systemImage: "square.and.arrow.down") }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider().overlay(Color(DesignTokens.hair))

            // X3: the Connections list is about SSH/RDP remotes. The always-present
            // `.local` shell has no real host (and SFTP/Tunnel actions are SSH-only),
            // so filter it out — otherwise `profiles.isEmpty` is never true and the
            // empty state is unreachable, and `.local` renders as a bogus card.
            let remotes = store.profiles.filter { $0.kind == .ssh || $0.kind == .rdp }
            if remotes.isEmpty {
                ContentUnavailableView {
                    Label("No connections", systemImage: "network")
                } description: {
                    Text("Add an SSH or RDP host to connect, tunnel, or browse over SFTP.")
                } actions: {
                    Button("New SSH") { sheet = .ssh }.buttonStyle(TermyCommandButtonStyle(emphasized: true))
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(ConnectionGrouping.grouped(remotes).enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text((section.title ?? "Ungrouped").uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(DesignTokens.Glass.textQuaternary)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                                    ForEach(section.profiles) { ConnectionCard(store: store, profile: $0) }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .buttonStyle(TermyCompactButtonStyle())
        .sheet(item: $sheet) { which in
            ConnectionsSheet(store: store, kind: which) { sheet = nil }
        }
    }
}

/// One saved connection as a glass card: identity + Connect + per-kind actions.
struct ConnectionCard: View {
    @ObservedObject var store: TermyStore
    let profile: ConnectionProfile
    @State private var hovering = false

    private var hostLine: String {
        let user = profile.user.map { "\($0)@" } ?? ""
        let port = profile.port.map { ":\($0)" } ?? ""
        return "\(user)\(profile.host)\(port)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: profile.kind == .rdp ? "display" : "terminal")
                    .font(.system(size: 14)).foregroundStyle(Color(DesignTokens.host.base))
                    .frame(width: 32, height: 32)
                    .background(Color(DesignTokens.host.base).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).font(Typography.ui(14, weight: .semibold)).foregroundStyle(Color(DesignTokens.fg1))
                    Text(hostLine).font(Typography.mono(11)).foregroundStyle(DesignTokens.Glass.textTertiary).lineLimit(1)
                }
                Spacer()
                TermyPill(title: profile.kind.rawValue.uppercased(), tint: Color(DesignTokens.host.base))
            }
            if let gateway = profile.gateway, !gateway.isEmpty {
                Text("via \(gateway)").font(Typography.ui(11)).foregroundStyle(DesignTokens.Glass.textQuaternary)
            }
            HStack(spacing: 8) {
                Button { store.openConnection(profile) } label: { Label("Connect", systemImage: "bolt.fill") }
                    .buttonStyle(TermyCommandButtonStyle(emphasized: true))
                if profile.kind == .ssh {
                    Button { store.openSFTPSession(profile) } label: { Label("SFTP", systemImage: "folder") }
                    Button { store.openLocalTunnel(profile) } label: { Label("Tunnel", systemImage: "arrow.left.arrow.right") }
                }
                Spacer()
                Button(role: .destructive) { store.deleteProfile(profile.id) } label: {
                    Label("Remove", systemImage: "trash")
                }
                .help("Remove this connection")
            }
        }
        .padding(14)
        .background(DesignTokens.Glass.raised.opacity(0.55), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
            .stroke(hovering ? DesignTokens.Glass.hairlineStrong : DesignTokens.Glass.hairline, lineWidth: 1))
        .onHover { hovering = $0 }
    }
}

/// Creation / tools, lifted out of the old wall-of-forms into focused sheets.
private struct ConnectionsSheet: View {
    @ObservedObject var store: TermyStore
    let kind: ConnSheet
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Typography.ui(15, weight: .semibold))
                Spacer()
                Button("Done", action: onClose).buttonStyle(TermyCompactButtonStyle())
            }
            .padding(14)
            Divider().overlay(Color(DesignTokens.hair))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(18)
            }
        }
        .frame(width: 560, height: 540)
        .background(Color(DesignTokens.bg1))
        .buttonStyle(TermyCompactButtonStyle())
        .textFieldStyle(GlassTextFieldStyle())
    }

    private var title: String {
        switch kind {
        case .ssh: "New SSH connection"
        case .rdp: "New RDP connection"
        case .tunnels: "SSH tunnels"
        case .keys: "SSH keys & options"
        }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .ssh: sshForm
        case .rdp: rdpForm
        case .tunnels: tunnelsForm
        case .keys: keysForm
        }
    }

    private var sshForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $store.sshProfileNameDraft)
            TextField("Host", text: $store.sshProfileHostDraft)
            HStack {
                TextField("User", text: $store.sshProfileUserDraft)
                TextField("Port", text: $store.sshProfilePortDraft).frame(width: 90)
            }
            TextField("Identity path", text: $store.sshProfileIdentityDraft)
            TextField("Group", text: $store.sshProfileGroupDraft)
            Button { store.createSSHProfileFromDraft(); onClose() } label: { Label("Create SSH connection", systemImage: "plus") }
                .buttonStyle(TermyCommandButtonStyle(emphasized: true))
                .disabled(store.sshProfileNameDraft.trimmingCharacters(in: .whitespaces).isEmpty
                          || store.sshProfileHostDraft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var rdpForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $store.rdpProfileNameDraft)
            TextField("Host", text: $store.rdpProfileHostDraft)
            TextField("User", text: $store.rdpProfileUserDraft)
            TextField("Gateway", text: $store.rdpProfileGatewayDraft)
            TextField("Credential reference", text: $store.rdpProfileCredentialDraft)
            TextField("Group", text: $store.rdpProfileGroupDraft)
            HStack {
                TextField("Width", text: $store.rdpWidth)
                TextField("Height", text: $store.rdpHeight)
                TextField("Scale", text: $store.rdpScale)
            }
            TextField("Local folder redirect", text: $store.rdpLocalFolderPath)
            Button { store.createRDPProfileFromDraft(); onClose() } label: { Label("Create RDP connection", systemImage: "plus") }
                .buttonStyle(TermyCommandButtonStyle(emphasized: true))
                .disabled(store.rdpProfileNameDraft.trimmingCharacters(in: .whitespaces).isEmpty
                          || store.rdpProfileHostDraft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var tunnelsForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Type", selection: $store.tunnelKind) {
                ForEach(SSHTunnelKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            HStack {
                TextField(store.tunnelKind == .remote ? "Remote port" : "Local port", text: $store.tunnelLocalPort)
                if store.tunnelKind != .dynamic {
                    TextField(store.tunnelKind == .remote ? "Local host" : "Remote host", text: $store.tunnelRemoteHost)
                    TextField(store.tunnelKind == .remote ? "Local port" : "Remote port", text: $store.tunnelRemotePort)
                }
            }
            if let ssh = store.profiles.first(where: { $0.kind == .ssh }) {
                Button { store.saveCurrentLocalTunnel(ssh) } label: { Label("Save tunnel", systemImage: "square.and.arrow.down") }
            }
            if !store.savedTunnels.isEmpty {
                Divider().overlay(Color(DesignTokens.hair))
                Text("SAVED").font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(DesignTokens.Glass.textQuaternary)
                ForEach(store.savedTunnels) { tunnel in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tunnel.name).font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg2))
                            Text(store.tunnelHealth[tunnel.id]?.summary ?? "Not started")
                                .font(Typography.ui(11)).foregroundStyle(DesignTokens.Glass.textTertiary)
                        }
                        Spacer()
                        Button("Start") { store.openSavedTunnel(tunnel) }
                        Button("Probe") { store.probeSavedTunnel(tunnel) }
                    }
                }
            }
        }
    }

    private var keysForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SSH KEYS").font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(DesignTokens.Glass.textQuaternary)
            TextField("Key path", text: $store.sshKeyPath)
            TextField("Comment", text: $store.sshKeyComment)
            HStack {
                Button("Generate") { store.generateSSHKey() }
                Button("Add to Agent") { store.addSSHKeyToAgent() }
                Button("Sync") { store.importSSHPrivateKeyToKeychain() }
                Button("Restore") { store.restoreSSHPrivateKeyFromKeychain() }
            }
            Divider().overlay(Color(DesignTokens.hair))
            Text("SSH OPTIONS (selected profile)").font(.system(size: 10, weight: .semibold)).tracking(0.5).foregroundStyle(DesignTokens.Glass.textQuaternary)
            TextEditor(text: $store.sshOptionsDraft)
                .font(Typography.mono(12)).frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(DesignTokens.Glass.fillControl, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.control).stroke(DesignTokens.Glass.hairline, lineWidth: 1))
            Button("Save SSH options") { store.saveSSHOptionsForSelectedProfile() }
                .disabled(store.selectedConnectionProfileID == nil)
            Text("One option per line, e.g. Compression=yes. Secret-bearing options are ignored.")
                .font(Typography.ui(11)).foregroundStyle(DesignTokens.Glass.textTertiary)
        }
    }
}
