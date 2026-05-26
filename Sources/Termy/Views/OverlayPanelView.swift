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
            .background(.bar)

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
                    .textFieldStyle(.roundedBorder)
                TextField("Name or path", text: $store.fileDraftName)
                    .textFieldStyle(.roundedBorder)
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
                    .textFieldStyle(.roundedBorder)
                TextField("Move to folder", text: $store.fileMoveDestination)
                    .textFieldStyle(.roundedBorder)
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
                        .textFieldStyle(.roundedBorder)
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
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
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

            List(store.visibleFileTreeItems, selection: $store.selectedFilePath) { treeItem in
                HStack(spacing: 6) {
                    Spacer()
                        .frame(width: CGFloat(treeItem.depth) * 14)
                    Image(systemName: treeItem.iconName)
                        .foregroundStyle(treeItem.item.isDirectory ? Color(DesignTokens.git.base) : Color(DesignTokens.fg3))
                    Text(treeItem.item.name)
                    Spacer(minLength: 0)
                }
                .help(treeItem.item.relativePath)
                .tag(treeItem.item.relativePath)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Refresh") {
                    store.refreshGitStatus()
                }
                Button("Diff") {
                    store.refreshGitDiff()
                }
                Button("Stage All") {
                    store.stageAllGitChanges()
                }
                Button("Pull") {
                    store.pullCurrentGitBranch()
                }
                Button("Push") {
                    store.pushCurrentGitBranch()
                }
                Spacer()
            }

            HStack {
                Picker("Branch", selection: $store.selectedGitBranch) {
                    ForEach(store.gitBranches, id: \.self) { branch in
                        Text(branch).tag(Optional(branch))
                    }
                }
                if let divergence = store.gitDivergence {
                    Text("Ahead \(divergence.ahead) / Behind \(divergence.behind)")
                        .foregroundStyle(.secondary)
                }
                Button("Checkout") {
                    store.checkoutSelectedGitBranch()
                }
                .disabled(store.selectedGitBranch == nil)
            }

            HStack {
                TextField("New branch", text: $store.gitBranchDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Create") {
                    store.createGitBranch()
                }
                .disabled(store.gitBranchDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextField("Commit message", text: $store.gitCommitMessage)
                .textFieldStyle(.roundedBorder)

            Button("Commit") {
                store.commitGitChanges()
            }
            .disabled(store.gitCommitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("AI Message") {
                store.suggestGitCommitMessageWithLocalAI()
            }

            Button("Explain Conflicts") {
                store.explainGitConflictsWithLocalAI()
            }

            ScrollView {
                Text(gitOutput)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private var gitOutput: String {
        if !store.gitConflictExplanation.isEmpty {
            return store.gitConflictExplanation
        }
        return store.gitDiff.isEmpty ? store.gitStatus : store.gitDiff
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
                    .textFieldStyle(.roundedBorder)
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
                .background(.bar)
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
                .background(.bar)
            }
        }
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
            .background(.bar)

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

private struct ConnectionsPanel: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        // Wrapped in a ScrollView so this tall form does not impose a min height
        // larger than the window — an unscrolled VStack here overflows the parent
        // and pushes the module breadcrumb + global tab/status bars off-screen.
        ScrollView {
        VStack(spacing: 0) {
            HStack {
                Button("Import SSH Config") {
                    store.importSSHConfig()
                }
                Spacer()
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("SSH Tunnel")
                    .font(Typography.ui(15, weight: .semibold))
                Picker("Type", selection: $store.tunnelKind) {
                    ForEach(SSHTunnelKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    TextField(store.tunnelKind == .remote ? "Remote port" : "Local port", text: $store.tunnelLocalPort)
                    if store.tunnelKind != .dynamic {
                        TextField(store.tunnelKind == .remote ? "Local host" : "Remote host", text: $store.tunnelRemoteHost)
                        TextField(store.tunnelKind == .remote ? "Local port" : "Remote port", text: $store.tunnelRemotePort)
                    }
                }
                .textFieldStyle(.roundedBorder)
                if let sshProfile = store.profiles.first(where: { $0.kind == .ssh }) {
                    HStack {
                        Button("Save Tunnel") {
                            store.saveCurrentLocalTunnel(sshProfile)
                        }
                        Button("Start Saved") {
                            if let tunnel = store.savedTunnels.first {
                                store.openSavedTunnel(tunnel)
                            }
                        }
                        .disabled(store.savedTunnels.isEmpty)
                    }
                }
            }
            .padding()

            Divider()

            if !store.savedTunnels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Saved Tunnels")
                        .font(Typography.ui(15, weight: .semibold))
                    ForEach(store.savedTunnels) { tunnel in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tunnel.name)
                                Text(tunnel.autoReconnect ? "Auto-reconnect" : "Manual")
                                    .font(Typography.ui(12))
                                    .foregroundStyle(.secondary)
                                Text(store.tunnelHealth[tunnel.id]?.summary ?? "Not started")
                                    .font(Typography.ui(12))
                                    .foregroundStyle(.secondary)
                                Text(store.tunnelProbeStatus[tunnel.id] ?? "Not probed")
                                    .font(Typography.ui(12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Start") {
                                store.openSavedTunnel(tunnel)
                            }
                            Button("Probe") {
                                store.probeSavedTunnel(tunnel)
                            }
                        }
                    }
                }
                .padding()

                Divider()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("New SSH Profile")
                    .font(Typography.ui(15, weight: .semibold))
                HStack {
                    TextField("Name", text: $store.sshProfileNameDraft)
                    TextField("Host", text: $store.sshProfileHostDraft)
                }
                HStack {
                    TextField("User", text: $store.sshProfileUserDraft)
                    TextField("Port", text: $store.sshProfilePortDraft)
                    TextField("Identity path", text: $store.sshProfileIdentityDraft)
                }
                TextField("Group", text: $store.sshProfileGroupDraft)
                Button("Create SSH Profile") {
                    store.createSSHProfileFromDraft()
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("SSH Options")
                    .font(Typography.ui(15, weight: .semibold))
                TextEditor(text: $store.sshOptionsDraft)
                    .font(Typography.mono(12))
                    .frame(minHeight: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    )
                HStack {
                    Button("Save SSH Options") {
                        store.saveSSHOptionsForSelectedProfile()
                    }
                    .disabled(store.selectedConnectionProfileID == nil)
                    Text("One option per line, e.g. Compression=yes. Secret-bearing options are ignored.")
                        .font(Typography.ui(12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("SSH Keys")
                    .font(Typography.ui(15, weight: .semibold))
                TextField("Key path", text: $store.sshKeyPath)
                    .textFieldStyle(.roundedBorder)
                TextField("Comment", text: $store.sshKeyComment)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Generate Key") {
                        store.generateSSHKey()
                    }
                    Button("Add to Agent") {
                        store.addSSHKeyToAgent()
                    }
                    Button("Sync Key") {
                        store.importSSHPrivateKeyToKeychain()
                    }
                    Button("Restore Key") {
                        store.restoreSSHPrivateKeyFromKeychain()
                    }
                }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("RDP")
                    .font(Typography.ui(15, weight: .semibold))
                HStack {
                    TextField("Name", text: $store.rdpProfileNameDraft)
                    TextField("Host", text: $store.rdpProfileHostDraft)
                }
                HStack {
                    TextField("User", text: $store.rdpProfileUserDraft)
                    TextField("Gateway", text: $store.rdpProfileGatewayDraft)
                    TextField("Credential reference", text: $store.rdpProfileCredentialDraft)
                }
                TextField("Group", text: $store.rdpProfileGroupDraft)
                Button("Create RDP Profile") {
                    store.createRDPProfileFromDraft()
                }
                HStack {
                    TextField("Width", text: $store.rdpWidth)
                    TextField("Height", text: $store.rdpHeight)
                    TextField("Scale", text: $store.rdpScale)
                }
                .textFieldStyle(.roundedBorder)
                TextField("Local folder redirect", text: $store.rdpLocalFolderPath)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            List(store.profiles) { profile in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(Typography.ui(15, weight: .semibold))
                        Text("\(profile.kind.rawValue.uppercased())  \(profile.host)")
                            .foregroundStyle(.secondary)
                        if let gateway = profile.gateway {
                            Text("Gateway: \(gateway)")
                                .font(Typography.ui(12))
                                .foregroundStyle(.secondary)
                        }
                        if let groupPath = profile.groupPath {
                            Text("Group: \(groupPath)")
                                .font(Typography.ui(12))
                                .foregroundStyle(.secondary)
                        }
                        Text(profile.secretReferences.isEmpty ? "No secret required" : "Secrets stored by Keychain reference")
                            .font(Typography.ui(12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open") {
                        store.openConnection(profile)
                    }
                    if profile.kind == .ssh {
                        Button("Edit Options") {
                            store.selectConnectionProfileForEditing(profile)
                        }
                        Button("Tunnel") {
                            store.openLocalTunnel(profile)
                        }
                        Button("Save Tunnel") {
                            store.saveCurrentLocalTunnel(profile)
                        }
                        Button("SFTP") {
                            store.openSFTPSession(profile)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 260)
        }
        }
    }
}
