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
                TextField("Model", text: $store.aiModel)
                TextField("Describe command", text: $store.aiPrompt)
                HStack {
                    Button("Validate Local Endpoint") {
                        store.validateLocalAIEndpoint()
                    }
                    Button("Suggest Command") {
                        store.suggestCommandWithLocalAI()
                    }
                    .disabled(store.aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Ask") {
                        store.askLocalAIQuestion()
                    }
                    .disabled(store.aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Explain Last Error") {
                        store.explainLastErrorWithLocalAI()
                    }
                }
                if !store.aiSuggestedCommand.isEmpty {
                    Text(store.aiSuggestedCommand)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Button("Send to Terminal") {
                        store.sendSuggestedCommandToTerminal()
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
    }

    private var guidanceSummary: String {
        let names = store.projectGuidance.documents.map(\.fileName)
        return names.isEmpty ? "No TERMY.md, CLAUDE.md, or AGENTS.md found." : names.joined(separator: ", ")
    }
}

private struct FileExplorerPanel: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search files", text: $store.fileSearchQuery)
                    .textFieldStyle(GlassTextFieldStyle())
                TextField("Name or path", text: $store.fileDraftName)
                    .textFieldStyle(GlassTextFieldStyle())
                Button("File") {
                    store.createFileFromDraft()
                }
                Button("Folder") {
                    store.createDirectoryFromDraft()
                }
            }
            .padding()

            Divider()

            HStack {
                TextField("Rename selected to", text: $store.fileRenameName)
                    .textFieldStyle(GlassTextFieldStyle())
                TextField("Move to folder", text: $store.fileMoveDestination)
                    .textFieldStyle(GlassTextFieldStyle())
                Button("Open") {
                    store.openSelectedFileInEditor()
                }
                .disabled(store.selectedFilePath == nil)
                Button("Rename") {
                    store.renameSelectedFile()
                }
                .disabled(store.selectedFilePath == nil)
                Button("Move") {
                    store.moveSelectedFile()
                }
                .disabled(store.selectedFilePath == nil)
                Button("Delete", role: .destructive) {
                    store.deleteSelectedFile()
                }
                .disabled(store.selectedFilePath == nil)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("SFTP path", text: $store.sftpRemotePath)
                        .textFieldStyle(GlassTextFieldStyle())
                    if let profile = store.profiles.first(where: { $0.kind == .ssh }) {
                        Button("Browse SFTP") {
                            store.refreshSFTPFiles(profile: profile)
                        }
                        Button("Upload") {
                            store.uploadSelectedFileToSFTP(profile: profile)
                        }
                        .disabled(store.selectedFilePath == nil)
                        Button("Download") {
                            store.downloadSelectedSFTPFile(profile: profile)
                        }
                        .disabled(store.selectedSFTPRemotePath == nil)
                        Button("New Remote Folder") {
                            store.createSFTPDirectoryFromDraft(profile: profile)
                        }
                        .disabled(store.fileDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Rename Remote") {
                            store.renameSelectedSFTPItem(profile: profile)
                        }
                        .disabled(store.selectedSFTPRemotePath == nil)
                        Button("Move Remote") {
                            store.moveSelectedSFTPItem(profile: profile)
                        }
                        .disabled(store.selectedSFTPRemotePath == nil)
                        Button("Delete Remote", role: .destructive) {
                            store.deleteSelectedSFTPItem(profile: profile)
                        }
                        .disabled(store.selectedSFTPRemotePath == nil)
                    }
                }
                if let profile = store.profiles.first(where: { $0.kind == .ssh }) {
                    Text("Drop local files here to upload. Drag a remote item onto this panel to download.")
                        .font(Typography.ui(12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(DesignTokens.Glass.fillControl, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.control))
                        .onDrop(of: [UTType.fileURL.identifier, UTType.text.identifier], isTargeted: nil) { providers in
                            handleSFTPDrop(providers: providers, profile: profile)
                        }
                }
                if !store.sftpRemoteItems.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(store.filteredSFTPRemoteItems, id: \.path) { item in
                                Button {
                                    store.selectedSFTPRemotePath = item.path
                                } label: {
                                    Label(item.name, systemImage: item.isDirectory ? "folder.badge.gearshape" : "doc")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .draggable(item.path)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(store.visibleFileTreeItems) { treeItem in
                        let selected = store.selectedFilePath == treeItem.item.relativePath
                        Button {
                            store.selectedFilePath = treeItem.item.relativePath
                        } label: {
                            HStack(spacing: 6) {
                                Spacer().frame(width: CGFloat(treeItem.depth) * 14)
                                Image(systemName: treeItem.iconName)
                                    .foregroundStyle(treeItem.item.isDirectory ? Color(DesignTokens.fg2) : Color(DesignTokens.fg3))
                                Text(treeItem.item.name).foregroundStyle(Color(DesignTokens.fg1))
                                Spacer(minLength: 0)
                            }
                            .font(Typography.ui(13))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            // Neutral translucent selection bar — never a colored fill (DESIGN.md).
                            .background(selected ? DesignTokens.Glass.fillSelection : Color.clear,
                                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.row))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(treeItem.item.relativePath)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
            }
            .overlay {
                if store.visibleFileTreeItems.isEmpty {
                    ContentUnavailableView(
                        store.fileSearchQuery.isEmpty ? "No Files" : "No Matches",
                        systemImage: "folder"
                    )
                }
            }
        }
        .buttonStyle(TermyCompactButtonStyle())
        .onAppear {
            store.refreshFiles()
        }
    }

    private func handleSFTPDrop(providers: [NSItemProvider], profile: ConnectionProfile) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        url = item as? URL
                    }
                    if let url {
                        Task { @MainActor in
                            store.uploadDroppedLocalFilesToSFTP([url], profile: profile)
                        }
                    }
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
                        GitHistoryView(commits: store.gitRecentCommits)
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
    let commits: [GitLogEntry]

    var body: some View {
        if commits.isEmpty {
            ContentUnavailableView("No commits", systemImage: "clock")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                        GitHistoryRow(commit: commit, isFirst: index == 0, isLast: index == commits.count - 1)
                    }
                }
                .padding(.vertical, 8).padding(.trailing, 16)
            }
        }
    }
}

private struct GitHistoryRow: View {
    let commit: GitLogEntry
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GraphRail(isMerge: commit.isMerge, isFirst: isFirst, isLast: isLast)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    ForEach(refChips, id: \.self) { ref in
                        Text(ref)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignTokens.Glass.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(DesignTokens.Glass.fillChip, in: Capsule())
                    }
                    Text(commit.subject).font(Typography.ui(13)).foregroundStyle(Color(DesignTokens.fg1))
                        .lineLimit(1).truncationMode(.tail)
                }
                HStack(spacing: 6) {
                    Text(commit.shortHash).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(DesignTokens.git.base))
                    Text(commit.author).font(Typography.ui(11)).foregroundStyle(DesignTokens.Glass.textTertiary)
                    Text("· \(commit.relativeDate)").font(Typography.ui(11)).foregroundStyle(DesignTokens.Glass.textQuaternary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 16).padding(.vertical, 7)
    }

    /// Decoded ref names without the "HEAD -> " prefix noise; tags shown bare.
    private var refChips: [String] {
        commit.refNames.compactMap { raw in
            if raw.hasPrefix("HEAD -> ") { return String(raw.dropFirst("HEAD -> ".count)) }
            if raw == "HEAD" { return "HEAD" }
            if raw.hasPrefix("tag: ") { return String(raw.dropFirst("tag: ".count)) }
            return raw
        }
    }
}

/// The graph spine + commit node for one history row.
private struct GraphRail: View {
    let isMerge: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy: CGFloat = 18
            Path { p in
                if !isFirst { p.move(to: CGPoint(x: cx, y: 0)); p.addLine(to: CGPoint(x: cx, y: cy)) }
                if !isLast { p.move(to: CGPoint(x: cx, y: cy)); p.addLine(to: CGPoint(x: cx, y: geo.size.height)) }
            }
            .stroke(Color(DesignTokens.hairStrong), lineWidth: 1.5)
            Circle()
                .fill(isMerge ? DesignTokens.Glass.accent : Color(DesignTokens.git.base))
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(Color(DesignTokens.bg0), lineWidth: 2).frame(width: 13, height: 13))
                .position(x: cx, y: cy)
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
                Text("Diff").font(Typography.ui(14, weight: .semibold))
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.editorFilePath ?? "Scratch")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                TextField("AI edit instruction", text: $store.editorAIInstruction)
                    .textFieldStyle(GlassTextFieldStyle())
                    .frame(maxWidth: 240)
                Button("Propose Edit") {
                    store.suggestEditorEditWithLocalAI()
                }
                .disabled(store.editorAIInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Explain Selection") {
                    store.explainEditorSelectionWithLocalAI()
                }
                .disabled(store.editorVimState.visualSelectionRange == nil)
                Button("Complete") {
                    store.suggestEditorCompletionWithLocalAI()
                }
                Button("Accept Completion") {
                    store.acceptEditorAICompletion()
                }
                .disabled(store.editorAICompletion.isEmpty)
                Button("Accept") {
                    store.acceptEditorAIProposal()
                }
                .disabled(store.editorAIProposal.isEmpty)
                Button("Apply Patch") {
                    store.applyEditorAIMultiFilePatch()
                }
                .disabled(store.editorAIMultiFilePatch.isEmpty)
                Button("Save") {
                    store.saveEditorFile()
                }
                .disabled(store.editorFilePath == nil)
                Toggle("Vim", isOn: Binding(
                    get: { store.editorVimEnabled },
                    set: { store.setEditorVimEnabled($0) }
                ))
                .toggleStyle(.switch)
            }
            .padding()

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

            HSplitView {
                TextEditor(text: editorText)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(minWidth: 280)

                SyntaxPreview(tokens: store.editorSyntaxTokens())
                    .frame(minWidth: 220)
            }

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

private struct SyntaxPreview: View {
    let tokens: [SyntaxToken]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Preview", systemImage: "curlybraces")
                    .font(Typography.ui(12))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(DesignTokens.bg2))

            ScrollView([.vertical, .horizontal]) {
                Text(attributedText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    private var attributedText: AttributedString {
        tokens.reduce(into: AttributedString()) { result, token in
            var part = AttributedString(token.text)
            part.foregroundColor = color(for: token.kind)
            result += part
        }
    }

    private func color(for kind: SyntaxTokenKind) -> Color {
        switch kind {
        case .plain:
            return Color(DesignTokens.fg1)
        case .heading:
            return Color(DesignTokens.primary)
        case .keyword, .key:
            return Color(DesignTokens.git.base)
        case .string:
            return Color(DesignTokens.sync.base)
        case .number:
            return Color(DesignTokens.agent.base)
        case .comment:
            return Color(DesignTokens.fg3)
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

            if store.profiles.isEmpty {
                ContentUnavailableView {
                    Label("No connections", systemImage: "network")
                } description: {
                    Text("Add an SSH or RDP host to connect, tunnel, or browse over SFTP.")
                } actions: {
                    Button("New SSH") { sheet = .ssh }.buttonStyle(TermyCommandButtonStyle(emphasized: true))
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                        ForEach(store.profiles) { ConnectionCard(store: store, profile: $0) }
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
private struct ConnectionCard: View {
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
