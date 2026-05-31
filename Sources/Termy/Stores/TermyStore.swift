import AppKit
import Foundation
import Security
import TermyCore
import TermySync
import TermyRDP

#if canImport(CloudKit)
import CloudKit
#endif

@MainActor
final class TermyStore: ObservableObject {
    private static let maxTerminalTranscriptLines = 10_000

    // M2c-3 strangler facade → `appModel.terminal`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var sessions: [TermySession] {
        get { appModel.terminal.sessions }
        set { objectWillChange.send(); appModel.terminal.sessions = newValue }
    }
    var selectedSessionID: UUID? {
        get { appModel.terminal.selectedSessionID }
        set {
            let old = appModel.terminal.selectedSessionID
            objectWillChange.send()
            appModel.terminal.selectedSessionID = newValue
            // F-3: close any open menu in the leaving session.
            if let old, old != newValue {
                terminalMenuStates[old] = nil
            }
        }
    }
    var isCommandCenterPresented: Bool {
        get { appModel.terminal.isCommandCenterPresented }
        set {
            objectWillChange.send()
            appModel.terminal.isCommandCenterPresented = newValue
            if newValue { refreshAgentVitals() }
        }
    }
    // M2c-3 strangler facade → `appModel.coordinator` (canonical invariant at
    // the `let appModel` comment below). Transient — deleted in final M2c.
    var activePanel: OverlayPanel? {
        get { appModel.coordinator.activePanel }
        set { objectWillChange.send(); appModel.coordinator.activePanel = newValue }
    }
    // M2c-3 strangler facade → `appModel.terminal` (canonical invariant at
    // the `let appModel` comment below). Transient — deleted in final M2c.
    var commandQuery: String {
        get { appModel.terminal.commandQuery }
        set { objectWillChange.send(); appModel.terminal.commandQuery = newValue }
    }
    // v3 shell navigation (Phase 2) → `appModel.shellNav`. Computed forwarders
    // + nav methods that `objectWillChange.send()` so the ObservableObject
    // views re-render (M2c-3 strangler-facade pattern).
    var activeTab: ShellNavigationModel.ActiveTab { appModel.shellNav.activeTab }
    var openTabs: [ShellNavigationModel.Module] { appModel.shellNav.openTabs }
    var activeTabKey: String { appModel.shellNav.activeTabKey }

    func openModuleTab(_ m: ShellNavigationModel.Module) {
        objectWillChange.send()
        appModel.shellNav.open(m)
    }

    func goToTab(_ tab: ShellNavigationModel.ActiveTab) {
        objectWillChange.send()
        appModel.shellNav.goTo(tab)
    }

    func goToDesktop() { goToTab(.desktop) }

    /// v3 Shell §6.1: spawn a new local zsh session (selects it + starts its PTY,
    /// via the shared `addSession` path). Backs the breadcrumb "New session" button.
    func newLocalShellSession() {
        addSession(profile: .local(name: "Local Shell \(sessions.count + 1)", terminalOutputMode: .blocks))
    }

    /// Context-aware ⌘T (author decision 2026-05-26): in the Shell module a new
    /// local shell session; everywhere else, the existing "go to Desktop".
    func handleNewTabShortcut() {
        if activeTab == .module(.shell) {
            newLocalShellSession()
        } else {
            goToDesktop()
        }
    }

    func goToTab(index: Int) {
        guard let m = appModel.shellNav.tab(at: index) else { return }
        goToTab(.module(m))
    }

    func closeModuleTab(_ m: ShellNavigationModel.Module) {
        objectWillChange.send()
        appModel.shellNav.close(m)
    }

    func closeActiveTab() {
        objectWillChange.send()
        appModel.shellNav.closeActive()
    }

    // M2c-1 strangler facade → `appModel.editor`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var scratchText: String {
        get { appModel.editor.scratchText }
        set { objectWillChange.send(); appModel.editor.scratchText = newValue }
    }
    var editorFilePath: String? {
        get { appModel.editor.editorFilePath }
        set { objectWillChange.send(); appModel.editor.editorFilePath = newValue }
    }
    var editorAIInstruction: String {
        get { appModel.editor.editorAIInstruction }
        set { objectWillChange.send(); appModel.editor.editorAIInstruction = newValue }
    }
    var editorAIProposal: String {
        get { appModel.editor.editorAIProposal }
        set { objectWillChange.send(); appModel.editor.editorAIProposal = newValue }
    }
    var editorAICompletion: String {
        get { appModel.editor.editorAICompletion }
        set { objectWillChange.send(); appModel.editor.editorAICompletion = newValue }
    }
    var editorAIDiff: String {
        get { appModel.editor.editorAIDiff }
        set { objectWillChange.send(); appModel.editor.editorAIDiff = newValue }
    }
    var editorAIMultiFilePatch: String {
        get { appModel.editor.editorAIMultiFilePatch }
        set { objectWillChange.send(); appModel.editor.editorAIMultiFilePatch = newValue }
    }
    var editorAIMultiFilePatchPaths: [String] {
        get { appModel.editor.editorAIMultiFilePatchPaths }
        set { objectWillChange.send(); appModel.editor.editorAIMultiFilePatchPaths = newValue }
    }
    var editorVimEnabled: Bool {
        get { appModel.editor.editorVimEnabled }
        set { objectWillChange.send(); appModel.editor.editorVimEnabled = newValue }
    }
    var editorVimState: VimEditorState {
        get { appModel.editor.editorVimState }
        set { objectWillChange.send(); appModel.editor.editorVimState = newValue }
    }
    // M2c-1 strangler facade → `appModel.ai`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var aiEndpoint: String {
        get { appModel.ai.aiEndpoint }
        set { objectWillChange.send(); appModel.ai.aiEndpoint = newValue }
    }
    var aiModel: String {
        get { appModel.ai.aiModel }
        set { objectWillChange.send(); appModel.ai.aiModel = newValue }
    }
    var aiPrompt: String {
        get { appModel.ai.aiPrompt }
        set { objectWillChange.send(); appModel.ai.aiPrompt = newValue }
    }
    var aiSuggestedCommand: String {
        get { appModel.ai.aiSuggestedCommand }
        set { objectWillChange.send(); appModel.ai.aiSuggestedCommand = newValue }
    }
    var aiExplanation: String {
        get { appModel.ai.aiExplanation }
        set { objectWillChange.send(); appModel.ai.aiExplanation = newValue }
    }
    var lastTerminalExplain: TerminalExplainRecord? {
        get { appModel.ai.lastTerminalExplain }
        set { objectWillChange.send(); appModel.ai.lastTerminalExplain = newValue }
    }

    /// Builds + stores the explain record for the failed block at `failedBlockStartLine`,
    /// resolving the 1-based ordinal against the SNAPSHOT `blocks` captured when the
    /// explain was launched (NOT a fresh post-await query) — so a mid-explain session
    /// switch can never fabricate an ordinal. nil ordinal = block not in the snapshot.
    /// `internal` (not `private`) so the wiring is unit-testable via `@testable`.
    func recordTerminalExplain(failedBlockStartLine: Int, in blocks: [TerminalCommandBlock],
                               durationSeconds: Double, succeeded: Bool, finishedAt: Date = Date()) {
        lastTerminalExplain = TerminalExplainRecord(
            blockOrdinal: TerminalExplainRecord.ordinal(ofBlockStartingAt: failedBlockStartLine, in: blocks),
            blockStartLine: failedBlockStartLine,
            command: blocks.first(where: { $0.startLine == failedBlockStartLine })?.command ?? "",
            durationSeconds: durationSeconds,
            finishedAt: finishedAt,
            succeeded: succeeded
        )
    }
    var aiConversationHistory: [String] {
        get { appModel.ai.aiConversationHistory }
        set { objectWillChange.send(); appModel.ai.aiConversationHistory = newValue }
    }
    var userPromptSnippets: [UserPromptSnippet] {
        get { appModel.ai.userPromptSnippets }
        set { objectWillChange.send(); appModel.ai.userPromptSnippets = newValue }
    }
    var promptSnippetTitle: String {
        get { appModel.ai.promptSnippetTitle }
        set { objectWillChange.send(); appModel.ai.promptSnippetTitle = newValue }
    }
    var promptSnippetBody: String {
        get { appModel.ai.promptSnippetBody }
        set { objectWillChange.send(); appModel.ai.promptSnippetBody = newValue }
    }
    // M2c-3 strangler facade → `appModel.coordinator` (canonical invariant at
    // the `let appModel` comment below). Transient — deleted in final M2c.
    var statusMessage: String {
        get { appModel.coordinator.statusMessage }
        set { objectWillChange.send(); appModel.coordinator.statusMessage = newValue }
    }
    // M2c-1 strangler facade → `appModel.git`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var gitStatus: String {
        get { appModel.git.gitStatus }
        set { objectWillChange.send(); appModel.git.gitStatus = newValue }
    }
    var gitCommitMessage: String {
        get { appModel.git.gitCommitMessage }
        set { objectWillChange.send(); appModel.git.gitCommitMessage = newValue }
    }
    var gitDiff: String {
        get { appModel.git.gitDiff }
        set { objectWillChange.send(); appModel.git.gitDiff = newValue }
    }
    var gitConflictExplanation: String {
        get { appModel.git.gitConflictExplanation }
        set { objectWillChange.send(); appModel.git.gitConflictExplanation = newValue }
    }
    var gitBranchDraft: String {
        get { appModel.git.gitBranchDraft }
        set { objectWillChange.send(); appModel.git.gitBranchDraft = newValue }
    }
    var selectedGitBranch: String? {
        get { appModel.git.selectedGitBranch }
        set { objectWillChange.send(); appModel.git.selectedGitBranch = newValue }
    }
    var gitDivergence: GitDivergence? {
        get { appModel.git.gitDivergence }
        set { objectWillChange.send(); appModel.git.gitDivergence = newValue }
    }
    // M2c-2 strangler facade → `appModel.files`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var fileItems: [LocalFileItem] {
        get { appModel.files.fileItems }
        set { objectWillChange.send(); appModel.files.fileItems = newValue }
    }
    var fileTreeItems: [LocalFileTreeItem] {
        get { appModel.files.fileTreeItems }
        set { objectWillChange.send(); appModel.files.fileTreeItems = newValue }
    }
    var sftpRemoteItems: [SFTPRemoteItem] {
        get { appModel.files.sftpRemoteItems }
        set { objectWillChange.send(); appModel.files.sftpRemoteItems = newValue }
    }
    var sftpRemotePath: String {
        get { appModel.files.sftpRemotePath }
        set { objectWillChange.send(); appModel.files.sftpRemotePath = newValue }
    }
    var selectedSFTPRemotePath: String? {
        get { appModel.files.selectedSFTPRemotePath }
        set { objectWillChange.send(); appModel.files.selectedSFTPRemotePath = newValue }
    }
    var selectedFilePath: String? {
        get { appModel.files.selectedFilePath }
        set { objectWillChange.send(); appModel.files.selectedFilePath = newValue }
    }
    var fileSearchQuery: String {
        get { appModel.files.fileSearchQuery }
        set { objectWillChange.send(); appModel.files.fileSearchQuery = newValue }
    }
    var fileDraftName: String {
        get { appModel.files.fileDraftName }
        set { objectWillChange.send(); appModel.files.fileDraftName = newValue }
    }
    var fileRenameName: String {
        get { appModel.files.fileRenameName }
        set { objectWillChange.send(); appModel.files.fileRenameName = newValue }
    }
    var fileMoveDestination: String {
        get { appModel.files.fileMoveDestination }
        set { objectWillChange.send(); appModel.files.fileMoveDestination = newValue }
    }
    // M2c-2 strangler facade → `appModel.connections` (canonical invariant at
    // the `let appModel` comment below). Seed list written by `init` (below).
    var profiles: [ConnectionProfile] {
        get { appModel.connections.profiles }
        set { objectWillChange.send(); appModel.connections.profiles = newValue }
    }
    // M2c-1 strangler facade → `appModel.git` (canonical invariant at the
    // `let appModel` comment below).
    var gitBranches: [String] {
        get { appModel.git.gitBranches }
        set { objectWillChange.send(); appModel.git.gitBranches = newValue }
    }
    // M2c-2 strangler facade → `appModel.connections`. Computed forwarders;
    // the canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var tunnelKind: SSHTunnelKind {
        get { appModel.connections.tunnelKind }
        set { objectWillChange.send(); appModel.connections.tunnelKind = newValue }
    }
    var tunnelLocalPort: String {
        get { appModel.connections.tunnelLocalPort }
        set { objectWillChange.send(); appModel.connections.tunnelLocalPort = newValue }
    }
    var tunnelRemoteHost: String {
        get { appModel.connections.tunnelRemoteHost }
        set { objectWillChange.send(); appModel.connections.tunnelRemoteHost = newValue }
    }
    var tunnelRemotePort: String {
        get { appModel.connections.tunnelRemotePort }
        set { objectWillChange.send(); appModel.connections.tunnelRemotePort = newValue }
    }
    var savedTunnels: [SavedSSHTunnel] {
        get { appModel.connections.savedTunnels }
        set { objectWillChange.send(); appModel.connections.savedTunnels = newValue }
    }
    var tunnelHealth: [String: SSHTunnelHealth] {
        get { appModel.connections.tunnelHealth }
        set { objectWillChange.send(); appModel.connections.tunnelHealth = newValue }
    }
    var tunnelProbeStatus: [String: String] {
        get { appModel.connections.tunnelProbeStatus }
        set { objectWillChange.send(); appModel.connections.tunnelProbeStatus = newValue }
    }
    var selectedConnectionProfileID: UUID? {
        get { appModel.connections.selectedConnectionProfileID }
        set { objectWillChange.send(); appModel.connections.selectedConnectionProfileID = newValue }
    }
    var sshProfileNameDraft: String {
        get { appModel.connections.sshProfileNameDraft }
        set { objectWillChange.send(); appModel.connections.sshProfileNameDraft = newValue }
    }
    var sshProfileHostDraft: String {
        get { appModel.connections.sshProfileHostDraft }
        set { objectWillChange.send(); appModel.connections.sshProfileHostDraft = newValue }
    }
    var sshProfileUserDraft: String {
        get { appModel.connections.sshProfileUserDraft }
        set { objectWillChange.send(); appModel.connections.sshProfileUserDraft = newValue }
    }
    var sshProfilePortDraft: String {
        get { appModel.connections.sshProfilePortDraft }
        set { objectWillChange.send(); appModel.connections.sshProfilePortDraft = newValue }
    }
    var sshProfileIdentityDraft: String {
        get { appModel.connections.sshProfileIdentityDraft }
        set { objectWillChange.send(); appModel.connections.sshProfileIdentityDraft = newValue }
    }
    var sshProfileGroupDraft: String {
        get { appModel.connections.sshProfileGroupDraft }
        set { objectWillChange.send(); appModel.connections.sshProfileGroupDraft = newValue }
    }
    var sshOptionsDraft: String {
        get { appModel.connections.sshOptionsDraft }
        set { objectWillChange.send(); appModel.connections.sshOptionsDraft = newValue }
    }
    var sshKeyPath: String {
        get { appModel.connections.sshKeyPath }
        set { objectWillChange.send(); appModel.connections.sshKeyPath = newValue }
    }
    var sshKeyComment: String {
        get { appModel.connections.sshKeyComment }
        set { objectWillChange.send(); appModel.connections.sshKeyComment = newValue }
    }
    var rdpWidth: String {
        get { appModel.connections.rdpWidth }
        set { objectWillChange.send(); appModel.connections.rdpWidth = newValue }
    }
    var rdpHeight: String {
        get { appModel.connections.rdpHeight }
        set { objectWillChange.send(); appModel.connections.rdpHeight = newValue }
    }
    var rdpScale: String {
        get { appModel.connections.rdpScale }
        set { objectWillChange.send(); appModel.connections.rdpScale = newValue }
    }
    var rdpLocalFolderPath: String {
        get { appModel.connections.rdpLocalFolderPath }
        set { objectWillChange.send(); appModel.connections.rdpLocalFolderPath = newValue }
    }
    var rdpProfileNameDraft: String {
        get { appModel.connections.rdpProfileNameDraft }
        set { objectWillChange.send(); appModel.connections.rdpProfileNameDraft = newValue }
    }
    var rdpProfileHostDraft: String {
        get { appModel.connections.rdpProfileHostDraft }
        set { objectWillChange.send(); appModel.connections.rdpProfileHostDraft = newValue }
    }
    var rdpProfileUserDraft: String {
        get { appModel.connections.rdpProfileUserDraft }
        set { objectWillChange.send(); appModel.connections.rdpProfileUserDraft = newValue }
    }
    var rdpProfileGatewayDraft: String {
        get { appModel.connections.rdpProfileGatewayDraft }
        set { objectWillChange.send(); appModel.connections.rdpProfileGatewayDraft = newValue }
    }
    var rdpProfileCredentialDraft: String {
        get { appModel.connections.rdpProfileCredentialDraft }
        set { objectWillChange.send(); appModel.connections.rdpProfileCredentialDraft = newValue }
    }
    var rdpProfileGroupDraft: String {
        get { appModel.connections.rdpProfileGroupDraft }
        set { objectWillChange.send(); appModel.connections.rdpProfileGroupDraft = newValue }
    }
    // M2c-3 strangler facade → `appModel.terminal`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var terminalSearchQuery: String {
        get { appModel.terminal.terminalSearchQuery }
        set { objectWillChange.send(); appModel.terminal.terminalSearchQuery = newValue }
    }
    /// v3 Shell §6.1: bumped by `requestTerminalSearchFocus()`; `TerminalSearchBar`
    /// focuses its field whenever this changes.
    private(set) var terminalSearchFocusToken = 0 // v3 Shell §6.1 — local coordination token (NOT a facade forwarder)
    /// v3 Shell §6.1: the find/output toolbar is on-demand, not a permanent strip
    /// (the handoff term-window has no toolbar). `false` until Find is invoked.
    private(set) var terminalSearchVisible = false // v3 Shell §6.1 — local UI state (NOT a facade forwarder)
    var terminalSearchResults: [TerminalSearchMatch] {
        get { appModel.terminal.terminalSearchResults }
        set { objectWillChange.send(); appModel.terminal.terminalSearchResults = newValue }
    }
    var terminalLinks: [TerminalLink] {
        get { appModel.terminal.terminalLinks }
        set { objectWillChange.send(); appModel.terminal.terminalLinks = newValue }
    }
    var selectedTerminalBlockStartLine: Int? {
        get { appModel.terminal.selectedTerminalBlockStartLine }
        set { objectWillChange.send(); appModel.terminal.selectedTerminalBlockStartLine = newValue }
    }
    var foldedTerminalBlockStartLines: Set<Int> {
        get { appModel.terminal.foldedTerminalBlockStartLines }
        set { objectWillChange.send(); appModel.terminal.foldedTerminalBlockStartLines = newValue }
    }
    var terminalScrollTargetLineID: UUID? {
        get { appModel.terminal.terminalScrollTargetLineID }
        set { objectWillChange.send(); appModel.terminal.terminalScrollTargetLineID = newValue }
    }
    var terminalLaunchDescriptors: [UUID: TerminalLaunchDescriptor] {
        get { appModel.terminal.terminalLaunchDescriptors }
        set { objectWillChange.send(); appModel.terminal.terminalLaunchDescriptors = newValue }
    }
    var terminalLaunchGenerations: [UUID: Int] {
        get { appModel.terminal.terminalLaunchGenerations }
        set { objectWillChange.send(); appModel.terminal.terminalLaunchGenerations = newValue }
    }
    var terminalScreenTextProviders: [UUID: () -> String] {
        get { appModel.terminal.terminalScreenTextProviders }
        set { objectWillChange.send(); appModel.terminal.terminalScreenTextProviders = newValue }
    }
    var hasRestorableSession: Bool {
        get { appModel.terminal.hasRestorableSession }
        set { objectWillChange.send(); appModel.terminal.hasRestorableSession = newValue }
    }
    var sessionRestoreStatus: String? {
        get { appModel.terminal.sessionRestoreStatus }
        set { objectWillChange.send(); appModel.terminal.sessionRestoreStatus = newValue }
    }
    var selectedTerminalThemeID: String {
        get { appModel.terminal.selectedTerminalThemeID }
        set { objectWillChange.send(); appModel.terminal.selectedTerminalThemeID = newValue }
    }
    var customTerminalThemes: [TerminalTheme] {
        get { appModel.terminal.customTerminalThemes }
        set { objectWillChange.send(); appModel.terminal.customTerminalThemes = newValue }
    }
    var customThemeName: String {
        get { appModel.terminal.customThemeName }
        set { objectWillChange.send(); appModel.terminal.customThemeName = newValue }
    }
    var customThemeBackgroundHex: String {
        get { appModel.terminal.customThemeBackgroundHex }
        set { objectWillChange.send(); appModel.terminal.customThemeBackgroundHex = newValue }
    }
    var customThemeForegroundHex: String {
        get { appModel.terminal.customThemeForegroundHex }
        set { objectWillChange.send(); appModel.terminal.customThemeForegroundHex = newValue }
    }
    var customThemePromptHex: String {
        get { appModel.terminal.customThemePromptHex }
        set { objectWillChange.send(); appModel.terminal.customThemePromptHex = newValue }
    }
    var customThemeErrorHex: String {
        get { appModel.terminal.customThemeErrorHex }
        set { objectWillChange.send(); appModel.terminal.customThemeErrorHex = newValue }
    }
    var customThemeMutedHex: String {
        get { appModel.terminal.customThemeMutedHex }
        set { objectWillChange.send(); appModel.terminal.customThemeMutedHex = newValue }
    }
    var terminalFontSize: Double {
        get { appModel.terminal.terminalFontSize }
        set { objectWillChange.send(); appModel.terminal.terminalFontSize = newValue }
    }
    var terminalFontFamily: String {
        get { appModel.terminal.terminalFontFamily }
        set { objectWillChange.send(); appModel.terminal.terminalFontFamily = newValue }
    }
    var terminalUsesLigatures: Bool {
        get { appModel.terminal.terminalUsesLigatures }
        set { objectWillChange.send(); appModel.terminal.terminalUsesLigatures = newValue }
    }
    var terminalIncreasedContrast: Bool {
        get { appModel.terminal.terminalIncreasedContrast }
        set { objectWillChange.send(); appModel.terminal.terminalIncreasedContrast = newValue }
    }
    // M2c-3 strangler facade → `appModel.coordinator` (canonical invariant at
    // the `let appModel` comment below). Transient — deleted in final M2c.
    var interfaceTextScaleRawValue: String {
        get { appModel.coordinator.interfaceTextScaleRawValue }
        set { objectWillChange.send(); appModel.coordinator.interfaceTextScaleRawValue = newValue }
    }
    // M2c-3 strangler facade → `appModel.terminal`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var terminalShellKind: String {
        get { appModel.terminal.terminalShellKind }
        set { objectWillChange.send(); appModel.terminal.terminalShellKind = newValue }
    }
    var terminalCustomShellPath: String {
        get { appModel.terminal.terminalCustomShellPath }
        set { objectWillChange.send(); appModel.terminal.terminalCustomShellPath = newValue }
    }
    var terminalCustomShellArguments: String {
        get { appModel.terminal.terminalCustomShellArguments }
        set { objectWillChange.send(); appModel.terminal.terminalCustomShellArguments = newValue }
    }
    var terminalOutputMode: String {
        get { appModel.terminal.terminalOutputMode }
        set { objectWillChange.send(); appModel.terminal.terminalOutputMode = newValue }
    }
    // M2c-3 strangler facade → `appModel.keymap`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Seed profile written by `init` (below). Transient.
    var keymapProfile: KeymapProfile {
        get { appModel.keymap.keymapProfile }
        set { objectWillChange.send(); appModel.keymap.keymapProfile = newValue }
    }
    var selectedKeymapActionID: String {
        get { appModel.keymap.selectedKeymapActionID }
        set { objectWillChange.send(); appModel.keymap.selectedKeymapActionID = newValue }
    }
    var keymapModifier: String {
        get { appModel.keymap.keymapModifier }
        set { objectWillChange.send(); appModel.keymap.keymapModifier = newValue }
    }
    var keymapKey: String {
        get { appModel.keymap.keymapKey }
        set { objectWillChange.send(); appModel.keymap.keymapKey = newValue }
    }
    // M2c-3 strangler facade → `appModel.coordinator` (canonical invariant at
    // the `let appModel` comment below). Transient — deleted in final M2c.
    var projectGuidance: ProjectGuidance {
        get { appModel.coordinator.projectGuidance }
        set { objectWillChange.send(); appModel.coordinator.projectGuidance = newValue }
    }
    // M2c-2 strangler facade → `appModel.sync`. Computed forwarders; the
    // canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var privateSyncRecords: [PrivateSyncRecord] {
        get { appModel.sync.privateSyncRecords }
        set { objectWillChange.send(); appModel.sync.privateSyncRecords = newValue }
    }
    var privateSyncStatus: String {
        get { appModel.sync.privateSyncStatus }
        set { objectWillChange.send(); appModel.sync.privateSyncStatus = newValue }
    }
    var privateSyncPendingOperations: [PrivateSyncOperation] {
        get { appModel.sync.privateSyncPendingOperations }
        set { objectWillChange.send(); appModel.sync.privateSyncPendingOperations = newValue }
    }
    var privateSyncLastOperationResults: [PrivateSyncOperationResult] {
        get { appModel.sync.privateSyncLastOperationResults }
        set { objectWillChange.send(); appModel.sync.privateSyncLastOperationResults = newValue }
    }
    var privateSyncChangeToken: PrivateSyncChangeToken? {
        get { appModel.sync.privateSyncChangeToken }
        set { objectWillChange.send(); appModel.sync.privateSyncChangeToken = newValue }
    }
    var privateSyncEngineAccountState: PrivateSyncEngineAccountState? {
        get { appModel.sync.privateSyncEngineAccountState }
        set { objectWillChange.send(); appModel.sync.privateSyncEngineAccountState = newValue }
    }
    // M2c strangler facade (canonical invariant). Extracted domain state
    // lives in `appModel.*` (Update added M2c-0; AI/Git/Editor added M2c-1;
    // Files/Connections/Workspace/Sync added M2c-2; Terminal/Keymap/
    // Coordinator added M2c-3 — every `@Published` is now extracted; the
    // final M2c sub-plan deletes this facade).
    // The `var`s above and below are computed
    // forwarders whose setters send `objectWillChange` BEFORE mutating,
    // matching the `@Published` willSet timing so `@ObservedObject`
    // consumers re-render identically. Internal production code must mutate
    // through the unqualified facade names (e.g. `self.terminalFontSize = …`,
    // `self.aiPrompt = …`), never `appModel.<domain>.* = …` directly, or
    // `objectWillChange` will not fire and consumers will stall (in-place
    // collection mutation like `self.aiConversationHistory.append(…)` is
    // fine — it routes through the forwarder's get/set). Transient — the
    // entire forwarding layer is deleted in the final M2c sub-plan when
    // views observe `@Environment(AppModel.self)` directly.
    let appModel = AppModel()

    // M2c-2 strangler facade → `appModel.workspace`. Computed forwarders;
    // the canonical bypass invariant + rationale is at the `let appModel`
    // comment below. Transient — deleted in the final M2c sub-plan.
    var workspaceStore: WorkspaceStore {
        get { appModel.workspace.workspaceStore }
        set { objectWillChange.send(); appModel.workspace.workspaceStore = newValue }
    }
    var paneLayout: WorkspacePaneLayout {
        get { appModel.workspace.paneLayout }
        set { objectWillChange.send(); appModel.workspace.paneLayout = newValue }
    }
    var selectedWorkspaceID: String? {
        get { appModel.workspace.selectedWorkspaceID }
        set { objectWillChange.send(); appModel.workspace.selectedWorkspaceID = newValue }
    }

    let catalog = FeatureCatalog.termDefault
    let privacyPolicy = PrivacyPolicy.termDefault
    let historyStore: HistoryStore
    let commandActivityLog: CommandActivityLog
    let sessionRestoreStore: SessionRestoreStore

    private static func defaultHistoryDirectory() -> URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory())
        return support.appendingPathComponent("Termy", isDirectory: true)
    }

    private let registry: CommandRegistry
    private let runner: ShellCommandRunner
    private var tunnelReconnectAttempts: [UUID: Int] = [:]
    private struct TunnelReconnectContext {
        let tunnel: SavedSSHTunnel
        let profile: ConnectionProfile
    }
    private var tunnelReconnectContexts: [UUID: TunnelReconnectContext] = [:]
    private var terminalInitialTranscriptReplays: [UUID: String] = [:]
    private let rdpPasteboardAdapter = RDPClipboardPasteboardAdapter()
    private let rdpAudioOutputPlayer = RDPAudioOutputPlayer()
    /// Post-Task-6 cutover state: per-session router plus the live
    /// FreeRDPSession driving the connection. The router holds the
    /// lifecycle, dedup gates, clipboard/audio synchronizers, frame buffer,
    /// and drive bridge (RDPTransportEventRouter internalises all of those
    /// — see RDPSessionModel.swift). The FreeRDPSession owns the off-main
    /// pump and produces the same `RDPTransportEvent` seam values the
    /// bespoke engine used to. `rdpConnectionTasks` covers in-flight starts
    /// (cancel on shutdown). The router exposes the descriptor via
    /// `lifecycle.descriptor` so a separate descriptor dict is not needed.
    private var rdpRouters: [UUID: RDPTransportEventRouter] = [:]
    private var rdpSessions: [UUID: FreeRDPSession] = [:]
    private var rdpConnectionTasks: [UUID: Task<Void, Never>] = [:]
    private let rdpConnect: @Sendable (RDPSessionDescriptor) async throws -> FreeRDPSession
    private let remoteNotificationSink: (RemoteSessionNotification) -> Void
    private let appIsActive: () -> Bool
    private let sshPrivateKeyVault: SSHPrivateKeyVault
    private let projectRootURL: URL
    private let agentWorktreeRoot: URL
    private let agentStateRoot: URL
    private let agentHookHelperPath: String?
    private var agentWorktrees: [UUID: AgentWorktreeHandle] = [:]
    private let localAISession: URLSession
    private var privateSyncCoordinator = PrivateSyncAppEventCoordinator()
    private var privateSyncEngineRuntime = PrivateSyncEngineRuntime()
    #if canImport(CloudKit)
    private var privateSyncEngineSession: CloudKitPrivateSyncEngineSession?
    #endif
    private var privateSyncDebounceTask: Task<Void, Never>?
    private let privateSyncDebounceSeconds = 5

    init(
        startInitialPTY: Bool = true,
        projectRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        agentWorktreeRoot: URL = TermyStore.defaultAgentWorktreeParent(),
        agentStateRoot: URL = TermyStore.defaultAgentStateRoot(),
        agentHookHelperPath: String? = TermyStore.defaultAgentHookHelperPath(),
        localAISession: URLSession = .shared,
        sshPrivateKeyVault: SSHPrivateKeyVault = SSHPrivateKeyVault(),
        remoteNotificationSink: @escaping (RemoteSessionNotification) -> Void = { _ in },
        appIsActive: @escaping () -> Bool = { true },
        rdpConnect: @escaping @Sendable (RDPSessionDescriptor) async throws -> FreeRDPSession = { descriptor in
            FreeRDPSession(descriptor: descriptor)
        },
        historyStore: HistoryStore? = nil,
        commandActivityLog: CommandActivityLog? = nil,
        sessionRestoreStore: SessionRestoreStore = SessionRestoreStore()
    ) {
        if let historyStore {
            self.historyStore = historyStore
        } else {
            let historyDir = Self.defaultHistoryDirectory()
            self.historyStore = HistoryStore(
                fileURL: historyDir.appendingPathComponent("history.jsonl"),
                markerURL: historyDir.appendingPathComponent(".history-imported")
            )
        }
        if let commandActivityLog {
            self.commandActivityLog = commandActivityLog
        } else {
            self.commandActivityLog = CommandActivityLog(
                fileURL: Self.defaultHistoryDirectory().appendingPathComponent("command-activity.json")
            )
        }
        self.sessionRestoreStore = sessionRestoreStore
        CompletionSidecar.sweepStaleWorkDirs(in: Self.sidecarWorkDirParent())
        Task.detached { GitRepository.sweepCleanAgentWorktrees(in: agentWorktreeRoot) }
        // FB-3-2: at startup no agent sessions are live, so every state file is
        // an orphan from a prior run.
        AgentStateFiles.sweepOrphans(in: agentStateRoot, keeping: [])
        AgentProgressFiles.sweepOrphans(in: agentStateRoot, keeping: [])
        // v3 §6.1: the default local shell renders as the block terminal too
        // (matches ⌘T sessions); `.local()` alone defaults to `.stream`.
        let local = ConnectionProfile.local(terminalOutputMode: .blocks)
        let sampleSSH = ConnectionProfile.ssh(
            name: "Example Bastion",
            host: "bastion.example.test",
            user: NSUserName(),
            port: 22,
            identity: .keychain("termy.example.ssh")
        )
        let sampleRDP = ConnectionProfile.rdp(
            name: "Example Windows VM",
            host: "windows.example.test",
            user: NSUserName(),
            gateway: nil,
            credential: .keychain("termy.example.rdp")
        )

        self.registry = CommandRegistry(actions: FeatureCatalog.termDefault.commandCenterActions)
        self.runner = ShellCommandRunner(workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        self.rdpConnect = rdpConnect
        self.remoteNotificationSink = remoteNotificationSink
        self.appIsActive = appIsActive
        self.sshPrivateKeyVault = sshPrivateKeyVault
        self.projectRootURL = projectRoot.standardizedFileURL
        self.agentWorktreeRoot = agentWorktreeRoot
        self.agentStateRoot = agentStateRoot
        self.agentHookHelperPath = agentHookHelperPath
        self.localAISession = localAISession
        // M2c-3: `profiles`, `keymapProfile`, `sessions`, and
        // `selectedSessionID` are all computed forwarders. These are one-time
        // construction seeds written before any view observes `TermyStore`
        // (no `objectWillChange` subscriber exists during `init`), so writing
        // the models directly and writing through the forwarders are
        // observably identical; direct writes also avoid spurious
        // `objectWillChange` emissions during construction. This is outside
        // the bypass invariant's scope, not an exception to it.
        appModel.connections.profiles = [local, sampleSSH, sampleRDP]
        appModel.keymap.keymapProfile = KeymapProfile.defaults(for: FeatureCatalog.termDefault.commandCenterActions)
        appModel.terminal.sessions = [
            TermySession(
                title: "Local Shell",
                profile: local,
                lines: [
                    TerminalLine(role: .system, text: "Termy local shell initialized. Built-in AI is local-only; no telemetry is present."),
                    TerminalLine(role: .system, text: "Use Command-K for the command center.")
                ],
                interactionMode: .rawPTY
            )
        ]
        appModel.terminal.selectedSessionID = appModel.terminal.sessions.first?.id
        let hasSnapshot = sessionRestoreStore.hasValidSnapshot()
        appModel.terminal.hasRestorableSession = hasSnapshot
        appModel.terminal.sessionRestoreStatus = hasSnapshot ? "Previous session available." : nil
        if startInitialPTY, let selectedSessionID {
            startPTY(for: selectedSessionID)
        }
        reloadProjectGuidance()
        refreshFiles()
        refreshGitBranches()

        // F-2: ensure history.jsonl is canonical on app quit. F-4 follow-up:
        // also drop the sidecar workDirs so they don't accumulate across runs.
        // NotificationCenter retains the closure (weak self prevents the
        // back-edge); the observer token is deliberately not stored — TermyStore
        // is app-lifetime.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.suppressAgentWorktreeCleanup = true
                self.terminalSurfacePool.drain()
                self.historyStore.flushPendingWrites()
                self.commandActivityLog.flushPendingWrites()
                do {
                    try self.captureSessionRestoreSnapshotNow()
                } catch {
                    self.sessionRestoreStatus = "Session restore capture failed: \(error.localizedDescription)"
                }
                self.shutdown()
            }
        }
    }

    deinit {
        privateSyncDebounceTask?.cancel()
    }

    var selectedSession: TermySession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    var terminalTheme: TerminalTheme {
        let theme = terminalThemeCatalog.theme(id: selectedTerminalThemeID) ?? terminalThemeCatalog.defaultTheme
        return terminalIncreasedContrast ? theme.applyingIncreasedContrast() : theme
    }

    var terminalThemeCatalog: TerminalThemeCatalog {
        TerminalThemeCatalog.builtIn.merging(customThemes: customTerminalThemes)
    }

    var terminalFontPreferences: TerminalFontPreferences {
        TerminalFontPreferences(size: terminalFontSize, family: terminalFontFamily, usesLigatures: terminalUsesLigatures)
    }

    var interfaceTextScale: InterfaceTextScale {
        get { InterfaceTextScale(rawValue: interfaceTextScaleRawValue) ?? .regular }
        set { interfaceTextScaleRawValue = newValue.rawValue }
    }

    var terminalShellProfile: ShellLaunchProfile {
        switch terminalShellKind {
        case "bash":
            return .bash
        case "custom":
            return .custom(
                path: terminalCustomShellPath.trimmingCharacters(in: .whitespacesAndNewlines),
                arguments: shellArguments(from: terminalCustomShellArguments)
            )
        default:
            return .zsh
        }
    }

    var gitStatusBarSummary: String {
        let branch = selectedGitBranch?.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = ["git: \(branch?.isEmpty == false ? branch! : "no branch")"]
        let dirtyCount = gitStatus
            .split(whereSeparator: \.isNewline)
            .filter { line in
                let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.count > 2 && (text.first?.isLetter == true || text.first == "?" || text.first == "!")
            }
            .count
        parts.append(dirtyCount == 0 ? "clean" : "\(dirtyCount) \(dirtyCount == 1 ? "change" : "changes")")
        if let gitDivergence {
            if gitDivergence.ahead > 0 {
                parts.append("+\(gitDivergence.ahead)")
            }
            if gitDivergence.behind > 0 {
                parts.append("-\(gitDivergence.behind)")
            }
        }
        return parts.joined(separator: " ")
    }

    var terminalOutputModeValue: TerminalOutputMode {
        TerminalOutputMode(rawValue: terminalOutputMode) ?? .stream
    }

    var selectedTerminalOutputModeValue: TerminalOutputMode {
        selectedSession?.profile.terminalOutputMode ?? terminalOutputModeValue
    }

    var selectedTerminalOutputModeRawValue: String {
        selectedTerminalOutputModeValue.rawValue
    }

    var aiGuidanceContext: String {
        [
            projectGuidance.combinedContext(maxCharacters: 4_000),
            UserPromptSnippetLibrary(snippets: userPromptSnippets).promptContext()
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }

    var leadingTiledPanel: OverlayPanel? {
        overlayPanel(for: paneLayout.leadingPane)
    }

    var trailingTiledPanel: OverlayPanel? {
        overlayPanel(for: paneLayout.trailingPane)
    }

    var topTiledPanel: OverlayPanel? {
        overlayPanel(for: paneLayout.topPane)
    }

    var bottomTiledPanel: OverlayPanel? {
        overlayPanel(for: paneLayout.bottomPane)
    }

    func refreshTerminalIndex() {
        guard let selectedSession else {
            terminalSearchResults = []
            terminalLinks = []
            return
        }
        let index = TerminalTextIndex(lines: selectedSession.lines.map(\.text))
        terminalSearchResults = index.search(terminalSearchQuery)
        terminalLinks = index.links()
    }

    func openTerminalLink(_ link: TerminalLink) {
        guard let url = URL(string: link.urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    /// v3 Shell §6.1: global count of commands run today (across all sessions).
    func commandsToday() -> Int {
        commandActivityLog.commandsToday(now: Date())
    }

    /// v3 Shell §6.1: the vendored syntax-highlighter name + version, read from
    /// the bundled `PINS` (same dir the launch descriptor sources). nil if the
    /// resource is somehow absent — honest empty, never fabricated.
    var syntaxHighlightVendor: (name: String, version: String)? {
        guard let dir = Bundle.main.resourceURL?
            .appendingPathComponent("zsh-syntax-highlighting", isDirectory: true) else { return nil }
        let pins = dir.appendingPathComponent("PINS", isDirectory: false)
        guard let contents = try? String(contentsOf: pins, encoding: .utf8) else { return nil }
        return SyntaxHighlightVendorInfo.parse(contents)
    }

    /// v3 Shell §6.1: real per-session zsh version, or nil (chip falls back to "zsh").
    /// Returns the cached probe result only — never blocks; `warmShellVersionIfNeeded`
    /// populates it off the main thread.
    func shellVersion(forSession sessionID: UUID) -> String? {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              session.interactionMode == .rawPTY, session.agentType == nil else { return nil }
        // Key by the session's OWN launched shell, not the current global default
        // (which drifts when the user changes the default shell mid-run).
        guard let shellPath = terminalLaunchDescriptors[sessionID]?.executable else { return nil }
        return shellVersionCache[shellPath]
    }

    /// Probes `<shell> --version` once per shell path, off the main thread, then caches.
    /// The outer `Task` inherits this type's `@MainActor` isolation (so the cache write
    /// is main-actor-safe); only the blocking `Process` probe is offloaded via an inner
    /// detached task.
    func warmShellVersionIfNeeded(forShellPath shellPath: String) {
        guard shellVersionCache[shellPath] == nil else { return }
        Task { [weak self] in
            let version = await Task.detached { Self.probeShellVersion(shellPath: shellPath) }.value
            guard let self, let version else { return }
            self.objectWillChange.send()
            self.shellVersionCache[shellPath] = version
        }
    }

    private nonisolated static func probeShellVersion(shellPath: String) -> String? {
        guard FileManager.default.isExecutableFile(atPath: shellPath) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ShellVersionProbe.parseZshVersion(String(decoding: data, as: UTF8.self))
    }

    func terminalCommandBlocks() -> [TerminalCommandBlock] {
        guard let selectedSession else { return [] }
        let entries = selectedSession.lines.map { line in
            TerminalTranscriptEntry(role: transcriptRole(for: line.role), text: line.text)
        }
        return TerminalCommandBlockIndexer().blocks(from: entries)
    }

    /// v3 Shell §6.1 sub-rail: command-block count for an arbitrary session
    /// (the parameterless `terminalCommandBlocks()` is selected-session-only).
    func terminalCommandBlocks(forSession sessionID: UUID) -> [TerminalCommandBlock] {
        guard let session = sessions.first(where: { $0.id == sessionID }) else { return [] }
        let entries = session.lines.map { line in
            TerminalTranscriptEntry(role: transcriptRole(for: line.role), text: line.text)
        }
        return TerminalCommandBlockIndexer().blocks(from: entries)
    }

    /// v3 Shell §6.1 Session-stats card: trailing-60s crash count for a session's
    /// completion sidecar (the Slice-1 `recentCrashCount`, first consumer here).
    /// `0` when the session has no sidecar — honest, never fabricated.
    func sidecarRecentCrashCount(forSession id: UUID) async -> Int {
        guard let sidecar = completionSidecars[id] else { return 0 }
        return await sidecar.recentCrashCount()
    }

    func renderedTerminalLines() -> [TerminalRenderedLine] {
        guard let selectedSession else { return [] }
        let blocks = terminalCommandBlocks()
        let blockStarts = Set(blocks.map(\.startLine))
        let hiddenLines = TerminalCommandBlockVisibility().hiddenLineIndexes(
            for: blocks,
            foldedStartLines: foldedTerminalBlockStartLines
        )

        return selectedSession.lines.enumerated().compactMap { index, line in
            guard !hiddenLines.contains(index) else { return nil }
            return TerminalRenderedLine(
                index: index,
                line: line,
                isBlockStart: blockStarts.contains(index),
                isSelectedBlock: selectedTerminalBlockStartLine == index,
                isFoldedBlock: foldedTerminalBlockStartLines.contains(index)
            )
        }
    }

    func renderedTerminalCommandBlocks() -> [TerminalRenderedCommandBlock] {
        guard let selectedSession else { return [] }
        return terminalCommandBlocks().map { block in
            let outputLines = selectedSession.lines.enumerated().compactMap { index, line -> TerminalLine? in
                guard index > block.startLine,
                      index <= block.endLine else {
                    return nil
                }
                switch line.role {
                case .stdout, .stderr:
                    return line
                case .prompt, .system:
                    return nil
                }
            }
            return TerminalRenderedCommandBlock(
                command: block.command,
                startLine: block.startLine,
                endLine: block.endLine,
                exitCode: block.exitCode,
                duration: commandDuration(forSession: selectedSession.id, startLine: block.startLine),
                outputLines: outputLines,
                isSelected: selectedTerminalBlockStartLine == block.startLine,
                isFolded: foldedTerminalBlockStartLines.contains(block.startLine)
            )
        }
    }

    func selectNextTerminalBlock() {
        let blocks = terminalCommandBlocks()
        guard let startLine = TerminalCommandBlockVisibility().nextBlockStart(
            after: selectedTerminalBlockStartLine,
            in: blocks
        ) else {
            statusMessage = "No command block available."
            return
        }
        selectTerminalBlock(startLine: startLine)
    }

    func selectPreviousTerminalBlock() {
        let blocks = terminalCommandBlocks()
        guard let startLine = TerminalCommandBlockVisibility().previousBlockStart(
            before: selectedTerminalBlockStartLine,
            in: blocks
        ) else {
            statusMessage = "No command block available."
            return
        }
        selectTerminalBlock(startLine: startLine)
    }

    func toggleSelectedTerminalBlockFolded() {
        guard let selectedTerminalBlockStartLine else {
            selectNextTerminalBlock()
            return
        }
        toggleTerminalBlockFolded(startLine: selectedTerminalBlockStartLine)
    }

    func toggleTerminalBlockFolded(startLine: Int) {
        if foldedTerminalBlockStartLines.contains(startLine) {
            foldedTerminalBlockStartLines.remove(startLine)
            statusMessage = "Expanded command block."
        } else {
            foldedTerminalBlockStartLines.insert(startLine)
            statusMessage = "Folded command block."
        }
        selectTerminalBlock(startLine: startLine)
    }

    func selectTerminalBlock(startLine: Int) {
        guard let selectedSession,
              selectedSession.lines.indices.contains(startLine) else { return }
        selectedTerminalBlockStartLine = startLine
        terminalScrollTargetLineID = selectedSession.lines[startLine].id
        statusMessage = "Selected command block."
    }

    func copyLastCommandOutput() {
        guard let block = terminalCommandBlocks().last else {
            statusMessage = "No command block available to copy."
            return
        }
        copyCommandOutput(block)
    }

    func copySelectedCommandOutput() {
        guard let selectedTerminalBlockStartLine,
              let block = terminalCommandBlocks().first(where: { $0.startLine == selectedTerminalBlockStartLine }) else {
            statusMessage = "No selected command block available to copy."
            return
        }
        copyCommandOutput(block)
    }

    func copyVisibleTerminalScreen() {
        guard let id = selectedSessionID,
              let provider = terminalScreenTextProviders[id] else {
            statusMessage = "No terminal screen content to copy."
            return
        }
        var lines = provider().components(separatedBy: "\n")
        while lines.last?.isEmpty == true { lines.removeLast() }
        let copiedText = lines.joined(separator: "\n")
        guard !copiedText.isEmpty else {
            statusMessage = "No terminal screen content to copy."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copiedText, forType: .string)
        statusMessage = "Copied terminal screen."
    }

    private func copyCommandOutput(_ block: TerminalCommandBlock) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(block.output, forType: .string)
        statusMessage = "Copied output for \(block.command)."
    }

    var filteredActions: [CommandAction] {
        keymapProfile.apply(to: availableCommandActions(registry.search(commandQuery)))
    }

    /// FB-3-4: cheap, always-live per-agent facts (no git). Merged with
    /// `appModel.agents.gitCache` to produce `agentVitals`.
    func agentVitalsSnapshots() -> [AgentVitalsSnapshot] {
        sessions.compactMap { session in
            guard let agentType = session.agentType else { return nil }
            let isolation: AgentIsolationKind = agentWorktrees[session.id]
                .map { .worktree(path: $0.path.path) } ?? .here
            let progress = agentProgress[session.id] ?? .empty
            return AgentVitalsSnapshot(
                id: session.id, name: session.title, agentType: agentType,
                state: session.agentActivity, cwd: session.currentWorkingDirectory,
                isolation: isolation, startedAt: session.startedAt,
                stateChangedAt: session.stateChangedAt,
                plan: progress.plan, touched: progress.touched)
        }
    }

    /// FB-3-4: live agent vitals (state from sessions, git from the cache).
    var agentVitals: [AgentSessionVitals] {
        mergeAgentVitals(snapshots: agentVitalsSnapshots(), gitCache: appModel.agents.gitCache)
    }

    /// FB-3-4: kick an off-main git refresh for all current agent sessions.
    func refreshAgentVitals() {
        appModel.agents.refresh(snapshots: agentVitalsSnapshots())
    }

    var filteredCommandCenterItems: [CommandCenterItem] {
        let query = commandQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingAgents = agentVitals.filter { vitals in
            guard !query.isEmpty else { return true }
            return [vitals.name, vitals.branch ?? "", vitals.cwd ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
        let agentItems = agentVitalsFlatOrder(matchingAgents).map(CommandCenterItem.agentSession)
        let profileItems = filteredConnectionProfiles().map(CommandCenterItem.profile)
        let actionItems = filteredActions.map(CommandCenterItem.action)
        // Agents are the top resume targets; keep the prior action/profile order otherwise.
        return query.isEmpty
            ? agentItems + actionItems + profileItems
            : agentItems + profileItems + actionItems
    }

    var keymapActions: [CommandAction] {
        keymapProfile.apply(to: catalog.commandCenterActions)
    }

    var keymapConflicts: [KeymapConflict] {
        keymapProfile.conflicts(in: catalog.commandCenterActions)
    }

    var shortcutCheatSheet: [ShortcutCheatSheetEntry] {
        keymapProfile.shortcutCheatSheet(for: catalog.commandCenterActions)
    }

    func shortcut(for actionID: String) -> ShortcutDescriptor? {
        guard let action = catalog.commandCenterActions.first(where: { $0.id == actionID }) else { return nil }
        return keymapProfile.shortcut(for: action)
    }

    func loadSelectedKeymapAction() {
        guard let shortcut = shortcut(for: selectedKeymapActionID) else { return }
        keymapModifier = shortcut.modifierName
        keymapKey = shortcut.key
    }

    func applyKeymapDraft() {
        let key = keymapKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty,
              let shortcut = ShortcutDescriptor(modifierName: keymapModifier, key: key) else {
            statusMessage = "Shortcut must include a modifier and key."
            return
        }

        var bindings = keymapProfile.bindings
        bindings[selectedKeymapActionID] = shortcut
        keymapProfile = KeymapProfile(bindings: bindings)

        if keymapConflicts.isEmpty {
            statusMessage = "Updated shortcut."
        } else {
            statusMessage = "Updated shortcut with conflict."
        }
        stampSyncEdit("appearance-default")
        stagePrivateSyncSnapshot()
    }

    func addCustomTerminalTheme() {
        let name = customThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusMessage = "Theme name is required."
            return
        }

        let theme = TerminalTheme(
            id: customThemeID(for: name),
            name: name,
            backgroundHex: normalizedHex(customThemeBackgroundHex),
            foregroundHex: normalizedHex(customThemeForegroundHex),
            promptHex: normalizedHex(customThemePromptHex),
            errorHex: normalizedHex(customThemeErrorHex),
            mutedHex: normalizedHex(customThemeMutedHex)
        )
        customTerminalThemes.removeAll { $0.id == theme.id }
        customTerminalThemes.append(theme)
        customTerminalThemes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectedTerminalThemeID = theme.id
        statusMessage = "Added custom theme \(theme.name)."
        stampSyncEdit("appearance-default")
        stagePrivateSyncSnapshot()
    }

    func perform(_ actionID: String) {
        switch actionID {
        case "open-command-center":
            commandQuery = ""
            isCommandCenterPresented = true
        case "new-local-terminal":
            newLocalShellSession()
        case "close-session":
            if let id = selectedSessionID {
                closeSession(sessionID: id)
            }
        case "set-terminal-output-stream":
            setSelectedTerminalOutputMode(.stream)
            stampSyncEdit("appearance-default")
            stagePrivateSyncSnapshot()
            statusMessage = "Terminal output uses classic stream."
        case "set-terminal-output-blocks":
            setSelectedTerminalOutputMode(.blocks)
            stampSyncEdit("appearance-default")
            stagePrivateSyncSnapshot()
            statusMessage = "Terminal output uses command blocks."
        case "copy-selected-command-output":
            copySelectedCommandOutput()
        case "copy-last-command-output":
            copyLastCommandOutput()
        case "copy-visible-terminal-screen":
            copyVisibleTerminalScreen()
        case "terminal-next-command-block":
            selectNextTerminalBlock()
        case "terminal-previous-command-block":
            selectPreviousTerminalBlock()
        case "terminal-toggle-command-block-fold":
            toggleSelectedTerminalBlockFolded()
        case "restore-last-session":
            restoreLastSession()
        case "connect-ssh":
            openModuleTab(.connections)
            addRemotePreview(kind: .ssh)
        case "create-ssh-profile":
            openModuleTab(.connections)
            createSSHProfileFromDraft()
        case "connect-rdp":
            openModuleTab(.connections)
            addRemotePreview(kind: .rdp)
        case "create-rdp-profile":
            openModuleTab(.connections)
            createRDPProfileFromDraft()
        case "toggle-ai-panel":
            toggle(.ai)
        case "explain-last-error":
            activePanel = .ai
            explainLastErrorWithLocalAI()
        case "run-claude-code-here":
            launchCLIAgent(.claudeCode, isolation: .here, baseCwd: selectedSessionWorkingDirectory)
        case "run-claude-code-worktree":
            launchCLIAgent(.claudeCode, isolation: .newWorktree, baseCwd: selectedSessionWorkingDirectory)
        case "run-codex-here":
            launchCLIAgent(.codex, isolation: .here, baseCwd: selectedSessionWorkingDirectory)
        case "run-codex-worktree":
            launchCLIAgent(.codex, isolation: .newWorktree, baseCwd: selectedSessionWorkingDirectory)
        case "interrupt-agent":
            if let id = selectedSessionID { interruptAgent(sessionID: id) }
        case "restart-agent":
            if let id = selectedSessionID { restartAgent(sessionID: id) }
        case "toggle-file-explorer":
            openModuleTab(.files)
        case "file-next-item":
            openModuleTab(.files)
            selectNextFileTreeItem()
        case "file-previous-item":
            openModuleTab(.files)
            selectPreviousFileTreeItem()
        case "sftp-next-item":
            openModuleTab(.files)
            selectNextSFTPRemoteItem()
        case "sftp-previous-item":
            openModuleTab(.files)
            selectPreviousSFTPRemoteItem()
        case "sftp-create-directory":
            openModuleTab(.files)
            if let profile = profiles.first(where: { $0.kind == .ssh }) {
                createSFTPDirectoryFromDraft(profile: profile)
            }
        case "sftp-rename-selected":
            openModuleTab(.files)
            if let profile = profiles.first(where: { $0.kind == .ssh }) {
                renameSelectedSFTPItem(profile: profile)
            }
        case "sftp-move-selected":
            openModuleTab(.files)
            if let profile = profiles.first(where: { $0.kind == .ssh }) {
                moveSelectedSFTPItem(profile: profile)
            }
        case "sftp-delete-selected":
            openModuleTab(.files)
            if let profile = profiles.first(where: { $0.kind == .ssh }) {
                deleteSelectedSFTPItem(profile: profile)
            }
        case "toggle-git-panel":
            openModuleTab(.git)
        case "toggle-editor":
            openModuleTab(.editor)
        case "tile-editor-right":
            tile(.editor, edge: .trailing)
        case "tile-files-left":
            tile(.files, edge: .leading)
        case "tile-git-top":
            tile(.git, edge: .top)
        case "tile-ai-bottom":
            tile(.ai, edge: .bottom)
        case "focus-next-pane":
            paneLayout.focusNextPane()
            statusMessage = "Focused \(paneLayout.focusedPane.rawValue) pane."
        case "resize-focused-pane-larger":
            paneLayout.resizeFocusedPane(by: 0.05)
            statusMessage = "Resized focused pane."
        case "resize-focused-pane-smaller":
            paneLayout.resizeFocusedPane(by: -0.05)
            statusMessage = "Resized focused pane."
        case "close-focused-pane":
            paneLayout.closeFocusedPane()
            statusMessage = "Closed focused pane."
        case "split-pane-trailing":
            if let kind = WorkspacesModuleModel.addablePaneKinds(present: paneLayout.visiblePanes).first {
                splitPane(kind, edge: .trailing)
            } else {
                statusMessage = "All pane kinds are already in the workspace."
            }
        case "split-pane-bottom":
            if let kind = WorkspacesModuleModel.addablePaneKinds(present: paneLayout.visiblePanes).first {
                splitPane(kind, edge: .bottom)
            } else {
                statusMessage = "All pane kinds are already in the workspace."
            }
        case "save-workspace":
            saveCurrentWorkspaceLayout()
            if let id = selectedWorkspaceID { stampSyncEdit("workspace-\(id)") }
            stagePrivateSyncSnapshot()
        default:
            statusMessage = "No handler registered for \(actionID)."
        }

        isCommandCenterPresented = false
    }

    func performCommandCenterItem(_ item: CommandCenterItem) {
        switch item {
        case .action(let action):
            perform(action.id)
        case .profile(let profile):
            openConnection(profile)
            isCommandCenterPresented = false
        case .agentSession(let vitals):
            focusAgentSession(vitals.id)
            isCommandCenterPresented = false
        }
    }

    func runCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let selectedSessionID,
              sessions.contains(where: { $0.id == selectedSessionID }) else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [runner] in
            let result: Result<ShellCommandResult, Error>
            do {
                result = .success(try runner.run(command))
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                self.apply(commandResult: result, to: selectedSessionID)
            }
        }
    }

    private func availableCommandActions(_ actions: [CommandAction]) -> [CommandAction] {
        actions.filter { action in
            switch action.id {
            case "restore-last-session":
                return hasRestorableSession
            case "interrupt-agent", "restart-agent":
                return selectedSessionIsLiveAgent
            default:
                return true
            }
        }
    }

    /// FB-3-6: the selected session is an agent whose process is still alive.
    /// Gates the Interrupt/Restart ⌘K entries (nothing to act on otherwise).
    var selectedSessionIsLiveAgent: Bool {
        guard let id = selectedSessionID,
              let session = sessions.first(where: { $0.id == id }) else { return false }
        return session.agentType != nil && session.agentActivity != .exited
    }

    private func filteredConnectionProfiles() -> [ConnectionProfile] {
        let remoteProfiles = profiles.filter { $0.kind == .ssh || $0.kind == .rdp }
        let normalizedQuery = commandQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return remoteProfiles }

        let tokens = normalizedQuery.split(separator: " ").map(String.init)
        return remoteProfiles
            .compactMap { profile -> (ConnectionProfile, Int)? in
                let fields = [
                    profile.kind.rawValue,
                    profile.name,
                    profile.host,
                    profile.user ?? "",
                    profile.gateway ?? "",
                    profile.groupPath ?? ""
                ]
                let haystack = fields.joined(separator: " ").lowercased()
                guard tokens.allSatisfy({ haystack.contains($0) }) else {
                    return nil
                }

                var score = 0
                if profile.name.lowercased() == normalizedQuery || profile.host.lowercased() == normalizedQuery {
                    score += 100
                }
                if profile.name.lowercased().contains(normalizedQuery) {
                    score += 50
                }
                if profile.host.lowercased().contains(normalizedQuery) {
                    score += 40
                }
                if profile.groupPath?.lowercased().contains(normalizedQuery) == true {
                    score += 20
                }
                return (profile, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }

    func setSelectedTerminalOutputMode(_ mode: TerminalOutputMode) {
        terminalOutputMode = mode.rawValue
        guard let selectedSessionID,
              let sessionIndex = sessions.firstIndex(where: { $0.id == selectedSessionID }) else {
            return
        }

        let updatedProfile = sessions[sessionIndex].profile.withTerminalOutputMode(mode)
        sessions[sessionIndex].profile = updatedProfile
        if let profileIndex = profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
            profiles[profileIndex] = updatedProfile
        }
    }

    func refreshGitStatus() {
        let repository = GitRepository(root: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.statusShort() }
            let divergence = try? repository.aheadBehind()
            DispatchQueue.main.async {
                switch result {
                case .success(let status):
                    self.gitStatus = self.format(status)
                    self.gitDivergence = divergence
                case .failure(let error):
                    self.gitStatus = error.localizedDescription
                    self.gitDivergence = nil
                }
            }
        }
        refreshGitBranches()
    }

    func stageAllGitChanges() {
        let repository = GitRepository(root: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.stageAll() }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.statusMessage = "Staged all git changes."
                    self.refreshGitStatus()
                case .failure(let error):
                    self.statusMessage = "Git stage failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func commitGitChanges() {
        let message = gitCommitMessage
        let repository = GitRepository(root: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.commit(message: message) }
            DispatchQueue.main.async {
                switch result {
                case .success(let commit):
                    self.gitCommitMessage = ""
                    self.gitStatus = commit.summary
                    self.statusMessage = "Git commit created."
                    self.refreshGitBranches()
                case .failure(let error):
                    self.statusMessage = "Git commit failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func refreshGitDiff() {
        let repository = GitRepository(root: projectRoot)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.diff() }
            DispatchQueue.main.async {
                switch result {
                case .success(let diff):
                    self.gitDiff = diff.isEmpty ? "No unstaged diff." : diff
                    self.statusMessage = "Git diff refreshed."
                case .failure(let error):
                    self.statusMessage = "Git diff failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func suggestGitCommitMessageWithLocalAI() {
        let repository = GitRepository(root: projectRoot)
        Task {
            do {
                let diff = try await Task.detached(priority: .userInitiated) {
                    try repository.diff()
                }.value
                guard !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    statusMessage = "No diff available for a commit message."
                    return
                }
                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let client = localAIClient(endpoint: endpoint)
                let suggestion = try await client.suggestCommitMessage(forDiff: diff)
                gitCommitMessage = suggestion.text
                statusMessage = "Local AI suggested a commit message."
            } catch {
                statusMessage = "Commit message suggestion failed: \(error.localizedDescription)"
            }
        }
    }

    func explainGitConflictsWithLocalAI() {
        let repository = GitRepository(root: projectRoot)
        Task {
            do {
                let hunks = try await Task.detached(priority: .userInitiated) {
                    try repository.conflictHunks()
                }.value
                guard !hunks.isEmpty else {
                    gitConflictExplanation = "No merge conflict markers found in conflicted files."
                    statusMessage = "No git conflicts found."
                    return
                }

                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let client = localAIClient(endpoint: endpoint)
                let explanation = try await client.explainGitConflict(
                    hunks: hunks,
                    projectGuidance: aiGuidanceContext
                )
                gitConflictExplanation = explanation.text
                statusMessage = "Local AI explained git conflict(s)."
            } catch {
                gitConflictExplanation = ""
                statusMessage = "Git conflict explanation failed: \(error.localizedDescription)"
            }
        }
    }

    func createGitBranch() {
        let name = gitBranchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let repository = GitRepository(root: projectRoot)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.createBranch(named: name, checkout: true) }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.gitBranchDraft = ""
                    self.selectedGitBranch = name
                    self.statusMessage = "Created and checked out \(name)."
                    self.refreshGitBranches()
                case .failure(let error):
                    self.statusMessage = "Create branch failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func checkoutSelectedGitBranch() {
        guard let selectedGitBranch else { return }
        let repository = GitRepository(root: projectRoot)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.checkoutBranch(selectedGitBranch) }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.statusMessage = "Checked out \(selectedGitBranch)."
                    self.refreshGitBranches()
                case .failure(let error):
                    self.statusMessage = "Checkout failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func pushCurrentGitBranch() {
        let repository = GitRepository(root: projectRoot)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.pushCurrentBranch() }
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self.gitStatus = output.output
                    self.statusMessage = "Git push completed."
                case .failure(let error):
                    self.statusMessage = "Git push failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func pullCurrentGitBranch() {
        let repository = GitRepository(root: projectRoot)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try repository.pullCurrentBranch() }
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self.gitStatus = output.output
                    self.statusMessage = "Git pull completed."
                    self.refreshFiles()
                case .failure(let error):
                    self.statusMessage = "Git pull failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func refreshFiles() {
        do {
            let service = LocalFileService(root: projectRoot)
            let tree = try service.tree()
            fileTreeItems = tree
            fileItems = tree.map(\.item)
        } catch {
            statusMessage = "File refresh failed: \(error.localizedDescription)"
        }
    }

    var filteredFileItems: [LocalFileItem] {
        LocalFileSearch(items: fileItems).search(fileSearchQuery)
    }

    var visibleFileTreeItems: [LocalFileTreeItem] {
        let query = fileSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return fileTreeItems }
        return filteredFileItems.map {
            LocalFileTreeItem(item: $0, depth: 0)
        }
    }

    func selectNextFileTreeItem() {
        selectFileTreeItem(offset: 1)
    }

    func selectPreviousFileTreeItem() {
        selectFileTreeItem(offset: -1)
    }

    func selectNextSFTPRemoteItem() {
        selectSFTPRemoteItem(offset: 1)
    }

    func selectPreviousSFTPRemoteItem() {
        selectSFTPRemoteItem(offset: -1)
    }

    var filteredSFTPRemoteItems: [SFTPRemoteItem] {
        let query = fileSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sftpRemoteItems }

        let tokens = query.split(separator: " ").map(String.init)
        return sftpRemoteItems.filter { item in
            let haystack = "\(item.name) \(item.path)".lowercased()
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    var selectedSFTPRemoteItem: SFTPRemoteItem? {
        guard let selectedSFTPRemotePath else { return nil }
        return sftpRemoteItems.first { $0.path == selectedSFTPRemotePath }
    }

    func refreshSFTPFiles(profile: ConnectionProfile) {
        do {
            let launch = try SFTPLaunchCommand(profile: profile)
            let batchURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("termy-sftp-\(UUID().uuidString).txt")
            let remotePath = sftpRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
            try SFTPBatchCommand.listDirectory(remotePath: remotePath).script.write(to: batchURL, atomically: true, encoding: .utf8)
            let command = ([launch.executablePath, "-b", batchURL.path] + launch.arguments)
                .map(shellQuote)
                .joined(separator: " ")
            let root = projectRoot

            DispatchQueue.global(qos: .userInitiated).async {
                defer { try? FileManager.default.removeItem(at: batchURL) }
                let result = Result { try ShellCommandRunner(workingDirectory: root).run(command) }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let output):
                        self.sftpRemoteItems = SFTPDirectoryListingParser().parse(
                            output.stdout,
                            currentDirectory: remotePath.isEmpty ? "." : remotePath
                        )
                        self.selectedSFTPRemotePath = self.sftpRemoteItems.first?.path
                        self.statusMessage = "Fetched \(self.sftpRemoteItems.count) SFTP item(s)."
                    case .failure(let error):
                        self.statusMessage = "SFTP listing failed: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            statusMessage = "SFTP listing failed: \(error.localizedDescription)"
        }
    }

    func uploadSelectedFileToSFTP(profile: ConnectionProfile) {
        guard let selectedFilePath else {
            statusMessage = "Select a local file before uploading."
            return
        }

        let fileName = URL(fileURLWithPath: selectedFilePath).lastPathComponent
        let remoteDirectory = sftpRemotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let remotePath = "\(remoteDirectory.isEmpty ? "." : remoteDirectory)/\(fileName)"
        runSFTPBatch(
            .upload(localPath: projectRoot.appendingPathComponent(selectedFilePath).path, remotePath: remotePath),
            profile: profile,
            successMessage: "Uploaded \(selectedFilePath) to \(remotePath).",
            refreshRemoteFiles: true
        )
    }

    func downloadSelectedSFTPFile(profile: ConnectionProfile) {
        guard let selectedSFTPRemotePath else {
            statusMessage = "Select a remote file before downloading."
            return
        }

        let fileName = URL(fileURLWithPath: selectedSFTPRemotePath).lastPathComponent
        runSFTPBatch(
            .download(remotePath: selectedSFTPRemotePath, localPath: projectRoot.appendingPathComponent(fileName).path),
            profile: profile,
            successMessage: "Downloaded \(selectedSFTPRemotePath) to \(fileName).",
            refreshLocalFiles: true
        )
    }

    func uploadDroppedLocalFilesToSFTP(_ urls: [URL], profile: ConnectionProfile) {
        guard !urls.isEmpty else { return }
        let planner = SFTPTransferPlanner(localRoot: projectRoot, remoteDirectory: sftpRemotePath)
        for url in urls {
            runSFTPBatch(
                planner.uploadDroppedLocalFile(url),
                profile: profile,
                successMessage: "Uploaded dropped file \(url.lastPathComponent).",
                refreshRemoteFiles: true
            )
        }
    }

    func downloadDroppedSFTPItem(_ item: SFTPRemoteItem, profile: ConnectionProfile) {
        let planner = SFTPTransferPlanner(localRoot: projectRoot, remoteDirectory: sftpRemotePath)
        runSFTPBatch(
            planner.downloadDroppedRemoteItem(item),
            profile: profile,
            successMessage: "Downloaded dropped remote file \(item.name).",
            refreshLocalFiles: true
        )
    }

    func createSFTPDirectoryFromDraft(profile: ConnectionProfile) {
        let name = fileDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        fileDraftName = ""
        let planner = SFTPTransferPlanner(localRoot: projectRoot, remoteDirectory: sftpRemotePath)
        runSFTPBatch(
            planner.createDirectory(named: name),
            profile: profile,
            successMessage: "Created remote folder \(name).",
            refreshRemoteFiles: true
        )
    }

    func renameSelectedSFTPItem(profile: ConnectionProfile) {
        guard let selectedSFTPRemoteItem else { return }
        let newName = fileRenameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }

        fileRenameName = ""
        let planner = SFTPTransferPlanner(localRoot: projectRoot, remoteDirectory: sftpRemotePath)
        runSFTPBatch(
            planner.rename(selectedSFTPRemoteItem, to: newName),
            profile: profile,
            successMessage: "Renamed remote \(selectedSFTPRemoteItem.name) to \(newName).",
            refreshRemoteFiles: true
        )
    }

    func moveSelectedSFTPItem(profile: ConnectionProfile) {
        guard let selectedSFTPRemoteItem else { return }
        let destination = fileMoveDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return }

        fileMoveDestination = ""
        let planner = SFTPTransferPlanner(localRoot: projectRoot, remoteDirectory: sftpRemotePath)
        runSFTPBatch(
            planner.move(selectedSFTPRemoteItem, toDirectory: destination),
            profile: profile,
            successMessage: "Moved remote \(selectedSFTPRemoteItem.name) to \(destination).",
            refreshRemoteFiles: true
        )
    }

    func deleteSelectedSFTPItem(profile: ConnectionProfile) {
        guard let selectedSFTPRemoteItem else { return }

        selectedSFTPRemotePath = nil
        let planner = SFTPTransferPlanner(localRoot: projectRoot, remoteDirectory: sftpRemotePath)
        runSFTPBatch(
            planner.delete(selectedSFTPRemoteItem),
            profile: profile,
            successMessage: "Deleted remote \(selectedSFTPRemoteItem.name).",
            refreshRemoteFiles: true
        )
    }

    func reloadProjectGuidance() {
        projectGuidance = ProjectGuidanceLoader().load(from: projectRoot)
    }

    func addPromptSnippet() {
        let title = promptSnippetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = promptSnippetBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty else {
            statusMessage = "Snippet title and body are required."
            return
        }

        let snippet = UserPromptSnippet(id: promptSnippetID(for: title), title: title, body: body)
        userPromptSnippets.removeAll { $0.id == snippet.id }
        userPromptSnippets.append(snippet)
        userPromptSnippets.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        statusMessage = "Added prompt snippet \(title)."
        stampSyncEdit("snippet-user-\(snippet.id)")
        stagePrivateSyncSnapshot()
    }

    func insertPromptSnippet(_ snippet: UserPromptSnippet) {
        let body = snippet.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        aiPrompt = aiPrompt.isEmpty ? body : "\(aiPrompt)\n\(body)"
    }

    // MARK: - D1 sync conflict timestamps

    /// Per-record last-edited stamps captured at mutation choke points, consumed by the
    /// next `stagePrivateSyncSnapshot` into each record's `modifiedAt`. Transient — the
    /// authoritative stamp then rides inside `privateSyncRecords` (and through CloudKit).
    private var syncRecordEditTimes: [String: Date] = [:]

    /// Set while applying fetched remote records so adoption never self-stamps as a local
    /// edit (which would let local falsely win on the next push — sync ping-pong).
    private var isApplyingRemoteSync = false

    /// D2: record names removed locally (trimmed ai-history) that must be tombstoned in
    /// CloudKit so they don't resurrect on the next fetch. Drained into the CKSyncEngine
    /// send batch; cleared once a push completes (re-deleting is idempotent).
    private var pendingSyncDeletions: Set<String> = []

    /// Stamp a syncable record as locally edited "now". No-op while adopting remote
    /// records. `recordName` must match the encoder: `connection-<id>` / `snippet-<id>` /
    /// `workspace-<id>` / `appearance-default`. A missed call degrades safely (the record
    /// keeps its prior stamp and loses only under an actual concurrent newer-remote edit).
    func stampSyncEdit(_ recordName: String) {
        guard !isApplyingRemoteSync else { return }
        syncRecordEditTimes[recordName] = Date()
    }

    /// Overlay the mutation-stamped `modifiedAt` onto freshly-built records: a record
    /// edited this session gets `now`; an untouched record preserves its prior stamp;
    /// ai-history is excluded (append/truncate, not edited — D2). Prior stamps come from
    /// the records about to be replaced, so call this BEFORE reassigning `privateSyncRecords`.
    private func overlaySyncModifiedAt(_ records: [PrivateSyncRecord]) -> [PrivateSyncRecord] {
        let previous = Dictionary(
            privateSyncRecords.compactMap { record in
                record.fields["modifiedAt"].map { (record.recordName, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        return records.map { record in
            guard record.recordType != "AIConversation" else { return record }
            if let edited = syncRecordEditTimes[record.recordName] {
                return record.settingField("modifiedAt", String(edited.timeIntervalSince1970))
            }
            if let prior = previous[record.recordName] {
                return record.settingField("modifiedAt", prior)
            }
            return record
        }
    }

    func stagePrivateSyncSnapshot(scheduleSync: Bool = true) {
        saveCurrentWorkspaceLayout()
        let guidanceSnippets = projectGuidance.documents.map {
            SyncSnippet(id: $0.fileName, title: $0.fileName, body: $0.contents)
        }
        let userSnippets = PrivateSyncPlanner.syncSnippets(from: UserPromptSnippetLibrary(snippets: userPromptSnippets))
        let snapshot = PrivateSyncSnapshot(
            profiles: profiles.filter { $0.kind != .local },
            terminalThemeID: selectedTerminalThemeID,
            terminalFontSize: terminalFontPreferences.size,
            terminalFontFamily: terminalFontPreferences.family,
            terminalUsesLigatures: terminalFontPreferences.usesLigatures,
            terminalIncreasedContrast: terminalIncreasedContrast,
            interfaceTextScale: interfaceTextScale,
            terminalShell: terminalShellProfile,
            terminalOutputMode: terminalOutputModeValue,
            customTerminalThemes: customTerminalThemes,
            keymapBindings: keymapProfile.bindings,
            snippets: guidanceSnippets + userSnippets,
            workspaces: workspaceStore.layouts.map {
                SyncWorkspace(id: $0.id, name: $0.name, panelIDs: $0.panelIDs, paneTree: $0.paneTree)
            },
            terminalScrollback: selectedSession?.lines.map(\.text) ?? [],
            aiConversationHistory: currentAIConversationHistory()
        )
        let plan = PrivateSyncPlanner().plan(for: snapshot)
        let stagedRecords = overlaySyncModifiedAt(plan.records)
        // D2: ai-history records that disappeared since the last stage are orphans to
        // tombstone; anything (re)staged is no longer an orphan.
        pendingSyncDeletions.formUnion(
            PrivateSyncDeletionPlanner.aiHistoryOrphans(previous: privateSyncRecords, current: stagedRecords)
        )
        pendingSyncDeletions.subtract(stagedRecords.map(\.recordName))
        privateSyncRecords = stagedRecords
        syncRecordEditTimes.removeAll()
        statusMessage = "Staged \(plan.records.count) CloudKit private sync record(s); secrets remain in iCloud Keychain."
        if scheduleSync {
            schedulePrivateSyncChangePush()
        }
    }

    func applyPrivateSyncRecordsToAppState() {
        // Adopting fetched remote records must never self-stamp as a local edit (that
        // would let local falsely win on the next push — ping-pong). The merged records
        // already carry the winners' `modifiedAt`, preserved by the next stage's overlay.
        isApplyingRemoteSync = true
        defer { isApplyingRemoteSync = false }
        let restored = PrivateSyncSnapshotRestorer().restore(from: privateSyncRecords)
        if !restored.profiles.isEmpty {
            profiles = [ConnectionProfile.local(terminalOutputMode: .blocks)] + restored.profiles
        }
        if let terminalThemeID = restored.terminalThemeID {
            selectedTerminalThemeID = terminalThemeID
        }
        if let terminalFontSize = restored.terminalFontSize {
            self.terminalFontSize = terminalFontSize
        }
        if let terminalFontFamily = restored.terminalFontFamily {
            self.terminalFontFamily = terminalFontFamily
        }
        if let terminalUsesLigatures = restored.terminalUsesLigatures {
            self.terminalUsesLigatures = terminalUsesLigatures
        }
        if let terminalIncreasedContrast = restored.terminalIncreasedContrast {
            self.terminalIncreasedContrast = terminalIncreasedContrast
        }
        if let interfaceTextScale = restored.interfaceTextScale {
            self.interfaceTextScale = interfaceTextScale
        }
        if let terminalShell = restored.terminalShell {
            applyRestoredTerminalShell(terminalShell)
        }
        if let terminalOutputMode = restored.terminalOutputMode {
            self.terminalOutputMode = terminalOutputMode.rawValue
        }
        if !restored.customTerminalThemes.isEmpty {
            customTerminalThemes = restored.customTerminalThemes
        }
        if !restored.keymapBindings.isEmpty {
            keymapProfile = KeymapProfile(bindings: restored.keymapBindings)
        }
        if !restored.snippets.isEmpty {
            userPromptSnippets = restored.snippets.map { snippet in
                let id = snippet.id.hasPrefix("user-") ? String(snippet.id.dropFirst("user-".count)) : snippet.id
                return UserPromptSnippet(id: id, title: snippet.title, body: snippet.body)
            }
        }
        if !restored.workspaces.isEmpty {
            workspaceStore = WorkspaceStore(layouts: restored.workspaces.map { workspace in
                WorkspaceLayout(
                    id: workspace.id,
                    name: workspace.name,
                    sessionProfileIDs: [],
                    activeSessionProfileID: nil,
                    panelIDs: workspace.panelIDs,
                    splitRatio: 0.5,
                    paneTree: workspace.paneTree
                )
            })
        }
        if !restored.aiConversationHistory.isEmpty {
            aiConversationHistory = restored.aiConversationHistory
        }
    }

    func checkPrivateSyncAccount() {
        Task {
            #if canImport(CloudKit)
            guard hasCloudKitPrivateSyncEntitlement else {
                privateSyncStatus = "CloudKit entitlement unavailable"
                statusMessage = "Private iCloud sync requires a signed build with the iCloud container entitlement."
                return
            }
            let status = await CloudKitPrivateSyncClient(containerIdentifier: "iCloud.pl.kacper.Termy").accountStatus()
            privateSyncStatus = formatCloudAccountStatus(status)
            statusMessage = "iCloud account status: \(privateSyncStatus)."
            #else
            privateSyncStatus = "CloudKit unavailable"
            statusMessage = "CloudKit is unavailable on this platform."
            #endif
        }
    }

    func pushPrivateSyncRecords() {
        if privateSyncRecords.isEmpty {
            stagePrivateSyncSnapshot(scheduleSync: false)
        }

        Task {
            let now = currentPrivateSyncTimestamp()
            _ = await runPrivateSyncEvent(.localChange, at: now)
            _ = await runPrivateSyncEvent(.timer, at: now + privateSyncDebounceSeconds)
        }
    }

    func fetchPrivateSyncWorkspaceRecords() {
        Task {
            _ = await runPrivateSyncEvent(.silentRemoteNotification)
        }
    }

    func startPrivateSyncAppLaunch() {
        #if canImport(CloudKit)
        guard hasCloudKitPrivateSyncEntitlement else {
            privateSyncStatus = "CloudKit entitlement unavailable"
            return
        }
        startPrivateSyncEngineRuntime()
        Task {
            _ = await runPrivateSyncEvent(.appLaunch)
        }
        #else
        privateSyncStatus = "CloudKit unavailable"
        #endif
    }

    @discardableResult
    func runPrivateSyncEvent(
        _ event: PrivateSyncEvent,
        at timestamp: Int? = nil
    ) async -> PrivateSyncAppEventStep {
        let now = timestamp ?? currentPrivateSyncTimestamp()
        var coordinator = privateSyncCoordinator
        #if canImport(CloudKit)
        guard hasCloudKitPrivateSyncEntitlement else {
            let unavailable = NSError(
                domain: "Termy.PrivateSync",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Private iCloud sync requires a signed build with the iCloud container entitlement."]
            )
            let step = await coordinator.handle(
                event: event,
                at: now,
                records: privateSyncRecords,
                activeLocalSessionRecordNames: activePrivateSyncRecordNames,
                save: { _ in throw unavailable },
                fetch: { _ in throw unavailable }
            )
            privateSyncCoordinator = coordinator
            applyPrivateSyncEventStep(step)
            return step
        }
        let client = CloudKitPrivateSyncClient(containerIdentifier: "iCloud.pl.kacper.Termy")
        let step = await coordinator.handle(
            event: event,
            at: now,
            records: privateSyncRecords,
            activeLocalSessionRecordNames: activePrivateSyncRecordNames,
            save: { records in
                guard !records.isEmpty else { return [] }
                let saved = try await client.save(records)
                try await client.ensureSubscription()
                return saved
            },
            fetch: { recordType in
                try await client.fetch(recordType: recordType)
            }
        )
        #else
        let unavailable = NSError(
            domain: "Termy.PrivateSync",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "CloudKit is unavailable on this platform."]
        )
        let step = await coordinator.handle(
            event: event,
            at: now,
            records: privateSyncRecords,
            activeLocalSessionRecordNames: activePrivateSyncRecordNames,
            save: { _ in throw unavailable },
            fetch: { _ in throw unavailable }
        )
        #endif

        privateSyncCoordinator = coordinator
        applyPrivateSyncEventStep(step)
        return step
    }

    @discardableResult
    func handlePrivateSyncEngineEvent(
        _ event: PrivateSyncEngineEvent,
        at timestamp: Int? = nil
    ) async -> PrivateSyncEngineRuntimeStep {
        let now = timestamp ?? currentPrivateSyncTimestamp()
        var runtime = privateSyncEngineRuntime

        #if canImport(CloudKit)
        let step: PrivateSyncEngineRuntimeStep
        if hasCloudKitPrivateSyncEntitlement {
            let client = CloudKitPrivateSyncClient(containerIdentifier: "iCloud.pl.kacper.Termy")
            step = await runtime.handle(
                event: event,
                at: now,
                records: privateSyncRecords,
                activeLocalSessionRecordNames: activePrivateSyncRecordNames,
                save: { records in
                    guard !records.isEmpty else { return [] }
                    let saved = try await client.save(records)
                    try await client.ensureSubscription()
                    return saved
                },
                fetch: { recordType in
                    try await client.fetch(recordType: recordType)
                }
            )
        } else {
            let unavailable = NSError(
                domain: "Termy.PrivateSync",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Private iCloud sync requires a signed build with the iCloud container entitlement."]
            )
            step = await runtime.handle(
                event: event,
                at: now,
                records: privateSyncRecords,
                activeLocalSessionRecordNames: activePrivateSyncRecordNames,
                save: { _ in throw unavailable },
                fetch: { _ in throw unavailable }
            )
        }
        #else
        let unavailable = NSError(
            domain: "Termy.PrivateSync",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "CloudKit is unavailable on this platform."]
        )
        let step = await runtime.handle(
            event: event,
            at: now,
            records: privateSyncRecords,
            activeLocalSessionRecordNames: activePrivateSyncRecordNames,
            save: { _ in throw unavailable },
            fetch: { _ in throw unavailable }
        )
        #endif

        privateSyncEngineRuntime = runtime
        applyPrivateSyncEngineRuntimeStep(step)
        return step
    }

    func saveCurrentWorkspaceLayout(name: String = "Current Workspace") {
        let layout = WorkspaceLayout(
            id: "current",
            name: name,
            sessionProfileIDs: sessions.map(\.profile.name),
            activeSessionProfileID: selectedSession?.profile.name,
            panelIDs: paneLayout.visiblePanes.map(\.rawValue) + (activePanel.map { [$0.rawValue] } ?? []),
            splitRatio: 0.68,
            paneTree: paneLayout.paneTree
        )
        workspaceStore.save(layout)
        selectedWorkspaceID = layout.id
        statusMessage = "Saved workspace \(name)."
    }

    func restoreSelectedWorkspace() {
        guard let selectedWorkspaceID,
              let layout = workspaceStore.restore(id: selectedWorkspaceID) else {
            statusMessage = "No workspace selected."
            return
        }

        if let panelID = layout.panelIDs.dropFirst().first,
           let panel = OverlayPanel(rawValue: panelID) {
            activePanel = panel
        } else {
            activePanel = nil
        }
        if let paneTree = layout.paneTree {
            paneLayout = WorkspacePaneLayout(paneTree: paneTree, focusedPane: paneTree.panes.first ?? .terminal)
        }

        if let activeProfileID = layout.activeSessionProfileID,
           let session = sessions.first(where: { $0.profile.name == activeProfileID }) {
            selectedSessionID = session.id
        }
        statusMessage = "Restored workspace \(layout.name)."
    }

    /// Focus a specific workspace pane (Workspaces viz click). Live-mirrors into
    /// the Shell tab, which renders the same paneLayout.
    func focusPane(_ kind: WorkspacePaneKind) {
        paneLayout.focus(kind)
        statusMessage = "Focused \(kind.rawValue) pane."
    }

    /// Close a specific workspace pane (Workspaces viz ×). No-op for .terminal.
    func closePane(_ kind: WorkspacePaneKind) {
        paneLayout.close(kind)
        _ = persistSelectedWorkspacePaneTree()
        statusMessage = "Closed \(kind.rawValue) pane."
    }

    /// Add a pane to the layout at the given edge (Workspaces New-pane picker /
    /// ⌘D / ⌘⇧D). Persists the updated tree to the selected saved layout.
    func splitPane(_ kind: WorkspacePaneKind, edge: WorkspaceSplitEdge) {
        paneLayout.split(kind, edge: edge)
        _ = persistSelectedWorkspacePaneTree()
        statusMessage = "Added \(kind.rawValue) pane."
    }

    func resizePaneSplit(
        at path: [WorkspacePaneTreeBranch],
        byDraggingPixels pixels: Double,
        inContainerLength containerLength: Double
    ) {
        paneLayout.resizeSplit(
            at: path,
            byDraggingPixels: pixels,
            inContainerLength: containerLength
        )
    }

    func finishPaneSplitResize() {
        let persisted = persistSelectedWorkspacePaneTree()
        if persisted {
            if let id = selectedWorkspaceID { stampSyncEdit("workspace-\(id)") }
            stagePrivateSyncSnapshot()
        }
        statusMessage = "Resized workspace split."
    }

    func completionSuggestions(for input: String) -> [CompletionCandidate] {
        CompletionEngine(
            history: historyStore.rankedSnapshot(forCwd: currentSessionCwd()),
            commandNames: Self.commandNames,
            commandFlags: Self.commandFlags,
            filePaths: fileItems.map(\.relativePath),
            sshHosts: profiles.filter { $0.kind == .ssh }.map(\.name),
            gitBranches: gitBranches
        )
        .suggestions(for: input)
    }

    /// F-3: parallel to `completionSuggestions(for:)` (which feeds the legacy
    /// `.commandLine` `CommandInput`). Differences:
    /// - `history: []` — menu surfaces contextual kinds only; ghost-text keeps
    ///   history.
    /// - `filePaths: []` — file-path completions deferred to F-4 sidecar;
    ///   the narrow CwdAwareFilePaths stopgap is retired (F-4 Task 10).
    /// - `limit: 10` (vs default 6) — menu has more vertical room than ghost.
    func completionSuggestionsForMenu(text: String, sessionID: UUID) -> [CompletionCandidate] {
        return CompletionEngine(
            history: [],
            commandNames: Self.commandNames,
            commandFlags: Self.commandFlags,
            filePaths: [],
            sshHosts: profiles.filter { $0.kind == .ssh }.map(\.name),
            gitBranches: gitBranches
        ).suggestions(for: text, limit: 10)
    }

    // MARK: - Inline command completion tables (F-4 Task 10: retired as module-level constants)

    private static let commandNames = [
        "cat", "cd", "code", "git", "grep", "ls", "mkdir",
        "mv", "nano", "open", "pwd", "rm", "ssh", "tail", "vim"
    ]

    private static let commandFlags: [String: [String]] = [
        "cat": ["-n", "-b", "-s"],
        "git": ["--help", "--version", "--no-pager"],
        "grep": ["--ignore-case", "--line-number", "--recursive", "--invert-match"],
        "ls": ["-a", "-l", "-la", "-lh"],
        "mkdir": ["-p"],
        "rm": ["-r", "-f", "-rf"],
        "ssh": ["-A", "-J", "-L", "-R", "-D", "-i", "-p", "-v"],
        "tail": ["-f", "-n"]
    ]

    func inlineAutosuggestion(for input: String) -> InlineAutosuggestion? {
        historyStore.inlineSuggestion(for: input, cwd: currentSessionCwd())
    }

    private func currentSessionCwd() -> String? {
        guard let id = selectedSessionID,
              let session = sessions.first(where: { $0.id == id }) else { return nil }
        return session.currentWorkingDirectory
    }

    /// F-1: latest zsh line-editor buffer per session, from the
    /// `OSC 133 ; T` zle-line-pre-redraw report. Only the newest value is
    /// kept (inherently coalesced — no stale recompute queue), and it is
    /// cleared when a command starts so a suggestion never survives into
    /// execution.
    private var terminalInputBuffers: [UUID: (text: String, cursor: Int, length: Int)] = [:]
    /// FB-1: zsh-syntax-highlighting `region_highlight` spans for the live input
    /// line (OSC 133 `H`), used to color the live block. Cleared with the buffer.
    private var terminalInputHighlights: [UUID: [InputHighlightSpan]] = [:]

    // MARK: - F-4 sidecar state

    /// F-4: per-session completion sidecar actors. Keyed by session UUID.
    /// Only `.rawPTY` sessions running zsh ever get an entry here.
    private var completionSidecars: [UUID: CompletionSidecar] = [:]
    private var completionSidecarTokens: [UUID: UUID] = [:]

    /// F-4: in-flight debounce tasks, keyed by session UUID.
    private var sidecarDebounceTasks: [UUID: Task<Void, Never>] = [:]

    /// F-4: last applied response ID per session (stale-drop guard).
    private var sidecarLastAppliedId: [UUID: Int] = [:]

    /// F-4: sessions whose 80 ms debounce has elapsed and are eligible
    /// for auto-open. Cleared on every new keystroke; set when the debounce
    /// fires (or when Tab is pressed — Tab counts as silence).
    private var sidecarDebounceElapsed: Set<UUID> = []

    /// F-4: last received sidecar items per session (even when menu is closed).
    /// Used by `recomputeSidecarGhost` to derive the ghost suffix without
    /// requiring the menu to be open.
    private var sidecarLastCandidates: [UUID: [CompletionCandidate]] = [:]

    /// F-4: top-1 sidecar ghost per session (suffix relative to active token).
    /// Nil when history ghost is present or the menu is open.
    private var sidecarGhosts: [UUID: String] = [:]

    /// F-4: sessions whose sidecar is in the `.disabled` state. Used to show
    /// a UI indicator (planned) and to skip the async query.
    @Published private(set) var sidecarDisabledSessions: Set<UUID> = []

    // Timing knobs (spec §5.5).
    private static let sidecarDebounceNs: UInt64 = 80_000_000    // 80 ms

    // MARK: - FB-3-2 agent state detection

    /// Per-agent-session activity state machines (pure reducers).
    private var agentStateMachines: [UUID: AgentStateMachine] = [:]
    /// FB-3-5: per-agent plan + touched files, folded from PostToolUse hook files.
    private var agentProgress: [UUID: AgentProgress] = [:]
    /// v3 Shell §6.1: cached zsh version per shell path, populated off the main thread by warmShellVersionIfNeeded.
    private var shellVersionCache: [String: String] = [:]
    /// Per-session output-quiescence timers (cancel-and-restart, like the F-4 debounce).
    private var agentQuiescenceTasks: [UUID: Task<Void, Never>] = [:]
    /// Single watcher over `agentStateRoot`; created lazily on first agent launch.
    private var agentStateWatcher: AgentStateWatcher?

    /// Silence after which a `.working` agent is treated as `.idle` (heuristic).
    private static let agentQuiescenceNs: UInt64 = 2_000_000_000   // 2.0 s

    // MARK: - F-3 menu state

    /// F-3: per-session inline completion menu state. Sole owner of menu
    /// visibility and selection — the SwiftUI overlay layer reads this via
    /// `terminalMenuSnapshot(for:)`. Cleared on close / session switch /
    /// commandStarted / engine-returns-empty during live narrow.
    private struct MenuState: Equatable {
        var items: [CompletionCandidate]
        var selection: Int
    }

    private var terminalMenuStates: [UUID: MenuState] = [:]

    // MARK: - v3 block terminal: per-command timing

    /// v3 block terminal: per-command timing keyed by the prompt line's index
    /// (== the rendered block's startLine). Runtime-only, not synced.
    private var commandStartTimes: [UUID: [Int: Date]] = [:]
    private var commandDurations: [UUID: [Int: TimeInterval]] = [:]
    private var pendingCommandPromptIndex: [UUID: Int] = [:]

    func commandDuration(forSession id: UUID, startLine: Int) -> TimeInterval? {
        commandDurations[id]?[startLine]
    }

    /// v3 block terminal: render-only clear of the live SwiftTerm VIEW (not the
    /// PTY). Registered by the view; fired on commandFinished so the live zone
    /// shows only the current command (history lives in the frozen block cards).
    private var terminalLocalClearSinks: [UUID: () -> Void] = [:]
    func registerTerminalLocalClear(_ sink: @escaping () -> Void, for id: UUID) {
        terminalLocalClearSinks[id] = sink
    }

    /// v3 block terminal: whether a foreground program is on the alternate screen
    /// (vim/htop/fzf). Pushed from SwiftTerm's post-render hook; drives the live
    /// zone's full-area takeover.
    private var terminalAltScreen: [UUID: Bool] = [:]
    func terminalAltScreenActive(for id: UUID) -> Bool { terminalAltScreen[id] ?? false }
    func setTerminalAltScreen(_ active: Bool, for id: UUID) {
        guard terminalAltScreen[id] != active else { return }
        objectWillChange.send()
        terminalAltScreen[id] = active
    }

    /// v3 block terminal: shift every line-keyed entry DOWN by `overflow` (the
    /// number of lines `trimTerminalTranscriptIfNeeded` removed from the front),
    /// dropping entries whose new key would be negative (those lines were
    /// trimmed away). Mirrors the `selectedTerminalBlockStartLine` /
    /// `foldedTerminalBlockStartLines` remap, applied to the timing dictionaries.
    static func shiftLineKeys<V>(_ dict: [Int: V], by overflow: Int) -> [Int: V] {
        var shifted: [Int: V] = [:]
        for (key, value) in dict where key >= overflow {
            shifted[key - overflow] = value
        }
        return shifted
    }

    /// Read snapshot for the overlay layer. Foundation value — safe for SwiftUI re-render.
    struct MenuSnapshot: Equatable {
        let items: [CompletionCandidate]
        let selection: Int
    }

    func terminalMenuSnapshot(for sessionID: UUID) -> MenuSnapshot? {
        guard let s = terminalMenuStates[sessionID] else { return nil }
        return MenuSnapshot(items: s.items, selection: s.selection)
    }

    /// Opens the menu if candidates are available for the cached buffer.
    ///
    /// For `.rawPTY` sessions with a live sidecar: fires an async sidecar query
    /// and returns `true` to swallow Tab (the result arrives via `onEvent` →
    /// `applyCompletionResponse` and populates the menu). Returns `false` only
    /// when the sidecar is `.disabled` AND the engine also returns 0 candidates
    /// (fall-through to native zsh Tab).
    ///
    /// For `.commandLine` sessions (SSH), delegates to the engine as before.
    @discardableResult
    func terminalMenuOpen(for sessionID: UUID) -> Bool {
        guard let buf = terminalInputBuffers[sessionID] else { return false }
        // F-4: sidecar path for rawPTY sessions.
        if let sidecar = completionSidecars[sessionID],
           !sidecarDisabledSessions.contains(sessionID) {
            // Tab counts as "silence" — mark debounce elapsed so the next result
            // can auto-open the menu even without the 80 ms timer firing first.
            sidecarDebounceElapsed.insert(sessionID)
            Task { await sidecar.query(buffer: buf.text, cursor: buf.cursor, cwd:
                sessions.first(where: { $0.id == sessionID })?.currentWorkingDirectory ?? "/")
            }
            return true  // swallow Tab; menu populates asynchronously
        }
        // F-3: engine path for .commandLine sessions.
        // rawPTY sessions with a disabled sidecar fall through here but return
        // false (no engine for local sessions), letting Tab pass through to zsh.
        let items = completionSuggestionsForMenu(text: buf.text, sessionID: sessionID)
        guard !items.isEmpty else { return false }
        terminalMenuStates[sessionID] = MenuState(items: items, selection: 0)
        objectWillChange.send()
        return true
    }

    func terminalMenuMoveSelection(for sessionID: UUID, by delta: Int) {
        guard var s = terminalMenuStates[sessionID], !s.items.isEmpty else { return }
        let n = s.items.count
        // Wrap arithmetic that handles arbitrary positive/negative delta.
        let raw = (s.selection + delta) % n
        s.selection = raw < 0 ? raw + n : raw
        terminalMenuStates[sessionID] = s
        objectWillChange.send()
    }

    func terminalMenuClose(for sessionID: UUID) {
        guard terminalMenuStates[sessionID] != nil else { return }
        terminalMenuStates[sessionID] = nil
        objectWillChange.send()
    }

    /// Returns the bytes to inject (`send(txt:)`) for the currently selected
    /// candidate, or `nil` when there is no open menu or the candidate is
    /// stale w.r.t. the current buffer. An *empty* return is valid — the user
    /// typed the full candidate and the menu should close without emitting.
    ///
    /// Engine guarantees `replacement` is full-buffer-shaped (see
    /// `CompletionEngine.replaceLastToken`), so the suffix is the portion
    /// after the cached buffer prefix.
    func terminalMenuAcceptedSuffix(for sessionID: UUID) -> String? {
        guard let state = terminalMenuStates[sessionID],
              let buf = terminalInputBuffers[sessionID],
              state.selection >= 0, state.selection < state.items.count else {
            return nil
        }
        let replacement = state.items[state.selection].replacement
        // Two candidate shapes share this menu:
        //  • Engine candidates are full-buffer-shaped ("git status" for "git s").
        //  • Sidecar (F-4) candidates are last-token-shaped ("status" for "git s").
        // Prefer the full-buffer interpretation, then fall back to the last
        // whitespace-delimited token (which also yields the whole candidate when
        // the buffer ends in a space, e.g. "git " → file completion).
        if replacement.hasPrefix(buf.text) {
            return String(replacement.dropFirst(buf.text.count))
        }
        let token = Self.lastWhitespaceToken(buf.text)
        if replacement.hasPrefix(token) {
            return String(replacement.dropFirst(token.count))
        }
        return nil
    }

    /// The trailing whitespace-delimited token of `text` (the partial word being
    /// completed); "" when `text` ends in whitespace. Unlike `split(" ").last`,
    /// this is correct for a trailing space (returns "", not the prior word).
    static func lastWhitespaceToken(_ text: String) -> String {
        guard let spaceIdx = text.lastIndex(of: " ") else { return text }
        return String(text[text.index(after: spaceIdx)...])
    }

    /// The ghost-text suffix to display/accept for `sessionID`, or nil when
    /// gating fails. Delegates to `inlineAutosuggestion(for:)`, which queries
    /// `historyStore` with the active session's cwd (F-2). The store is fed
    /// from the OSC 133 `C` `commandStarted` stream. Suffix semantics require
    /// the cursor at buffer end.
    func terminalInlineSuggestionSuffix(for sessionID: UUID) -> String? {
        // F-3: when the menu is the active surface for this session, the
        // ghost-text channel is suppressed to avoid double-rendering. F-2's
        // terminalInlineSuggestionNextComponent reads through here, so Ctrl-→
        // inherits the suppression automatically.
        if terminalMenuStates[sessionID] != nil { return nil }
        guard let buf = terminalInputBuffers[sessionID],
              !buf.text.isEmpty,
              buf.cursor == buf.length,
              let suggestion = inlineAutosuggestion(for: buf.text) else { return nil }
        return suggestion.ghostText
    }

    /// F-2: returns the next *component* of the pending inline ghost text for
    /// `sessionID`, or nil if there is no pending suffix. Used by
    /// SwiftTermTerminalView's Ctrl-→ key path to accept one whitespace- or
    /// path-segment-bounded token at a time.
    func terminalInlineSuggestionNextComponent(for sessionID: UUID) -> String? {
        guard let suffix = terminalInlineSuggestionSuffix(for: sessionID) else { return nil }
        return HistoryStore.nextComponent(of: suffix)
    }

    /// v3 §6.1 block terminal: the live line-editor buffer (text + cursor index)
    /// for `sessionID`, or nil when nothing is being typed. Rendered as the live
    /// block's `❯ <text>` + caret. Source: OSC 133 T (the F-1 buffer publish).
    func terminalLiveInput(for sessionID: UUID) -> (text: String, cursor: Int)? {
        guard let buf = terminalInputBuffers[sessionID] else { return nil }
        return (buf.text, buf.cursor)
    }

    /// FB-1: the live input's syntax-highlight spans (zsh-syntax-highlighting
    /// `region_highlight`) for `sessionID`, used to color the live block.
    func terminalLiveHighlights(for sessionID: UUID) -> [InputHighlightSpan] {
        terminalInputHighlights[sessionID] ?? []
    }

    /// v3 §6.1 block terminal: true while a command for `sessionID` is executing
    /// (between OSC 133 `C` and `D`) — its output streams in the live SwiftTerm
    /// until it finishes and folds into a block.
    func terminalCommandIsExecuting(for sessionID: UUID) -> Bool {
        pendingCommandPromptIndex[sessionID] != nil
    }

    func createFileFromDraft() {
        let name = fileDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try LocalFileService(root: projectRoot).createFile(named: name)
            fileDraftName = ""
            refreshFiles()
            statusMessage = "Created file \(name)."
        } catch {
            statusMessage = "Create file failed: \(error.localizedDescription)"
        }
    }

    func createDirectoryFromDraft() {
        let name = fileDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            try LocalFileService(root: projectRoot).createDirectory(named: name)
            fileDraftName = ""
            refreshFiles()
            statusMessage = "Created folder \(name)."
        } catch {
            statusMessage = "Create folder failed: \(error.localizedDescription)"
        }
    }

    func renameSelectedFile() {
        guard let selectedFilePath else { return }
        let newName = fileRenameName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }

        do {
            try LocalFileService(root: projectRoot).rename(selectedFilePath, to: newName)
            self.selectedFilePath = newName
            fileRenameName = ""
            refreshFiles()
            statusMessage = "Renamed \(selectedFilePath) to \(newName)."
        } catch {
            statusMessage = "Rename failed: \(error.localizedDescription)"
        }
    }

    func moveSelectedFile() {
        guard let selectedFilePath else { return }
        let destination = fileMoveDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return }

        do {
            let movedPath = try LocalFileService(root: projectRoot).move(selectedFilePath, toDirectory: destination)
            self.selectedFilePath = movedPath
            fileMoveDestination = ""
            refreshFiles()
            statusMessage = "Moved \(selectedFilePath) to \(movedPath)."
        } catch {
            statusMessage = "Move failed: \(error.localizedDescription)"
        }
    }

    func deleteSelectedFile() {
        guard let selectedFilePath else { return }
        do {
            try LocalFileService(root: projectRoot).delete(selectedFilePath)
            self.selectedFilePath = nil
            refreshFiles()
            statusMessage = "Deleted \(selectedFilePath)."
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func openSelectedFileInEditor() {
        guard let selectedFilePath else { return }
        do {
            scratchText = try LocalFileService(root: projectRoot).readText(selectedFilePath)
            editorVimState = VimEditorState(buffer: scratchText)
            editorFilePath = selectedFilePath
            openModuleTab(.editor)
            statusMessage = "Opened \(selectedFilePath)."
        } catch {
            statusMessage = "Open file failed: \(error.localizedDescription)"
        }
    }

    func saveEditorFile() {
        guard let editorFilePath else {
            statusMessage = "No file is open in the editor."
            return
        }
        do {
            try LocalFileService(root: projectRoot).writeText(scratchText, to: editorFilePath)
            refreshFiles()
            statusMessage = "Saved \(editorFilePath)."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func editorSyntaxTokens() -> [SyntaxToken] {
        SyntaxHighlighter().highlight(scratchText, fileName: editorFilePath ?? "Scratch.md")
    }

    func setEditorVimEnabled(_ enabled: Bool) {
        editorVimEnabled = enabled
        editorVimState = VimEditorState(buffer: scratchText)
        statusMessage = enabled ? "Vim mode enabled." : "Vim mode disabled."
    }

    func applyEditorVimCommand(_ command: VimEditorCommand) {
        guard editorVimEnabled else { return }
        var state = editorVimState
        state.apply(command)
        editorVimState = state
        scratchText = state.buffer
        if let selection = state.visualSelectionRange {
            statusMessage = "Vim \(state.mode) selection \(selection.lowerBound)-\(selection.upperBound), cursor \(state.cursorOffset)."
        } else if let pendingOperator = state.pendingOperator {
            statusMessage = "Vim \(state.mode) operator \(pendingOperator), cursor \(state.cursorOffset)."
        } else if let pendingCount = state.pendingCount {
            statusMessage = "Vim \(state.mode) count \(pendingCount), cursor \(state.cursorOffset)."
        } else {
            statusMessage = "Vim \(state.mode) cursor \(state.cursorOffset)."
        }
    }

    func insertEditorVimText(_ text: String) {
        guard editorVimEnabled else { return }
        var state = editorVimState
        state.insert(text)
        editorVimState = state
        scratchText = state.buffer
        statusMessage = "Vim insert cursor \(state.cursorOffset)."
    }

    func suggestEditorEditWithLocalAI() {
        let instruction = editorAIInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }

        Task {
            do {
                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let client = localAIClient(endpoint: endpoint)
                let proposal = try await client.suggestEditorEdit(
                    instruction: instruction,
                    buffer: scratchText,
                    projectGuidance: aiGuidanceContext
                )
                switch EditorAIProposalResolver.resolvedProposal(from: proposal.text, original: scratchText) {
                case .bufferReplacement(let resolvedProposal):
                    editorAIProposal = resolvedProposal
                    editorAIDiff = TextDiffPreview.makeDiff(original: scratchText, proposed: resolvedProposal)
                    editorAIMultiFilePatch = ""
                    editorAIMultiFilePatchPaths = []
                    statusMessage = "Local AI proposed an editor change."
                case .multiFilePatch(let patch, let changedPaths):
                    editorAIProposal = ""
                    editorAIDiff = patch
                    editorAIMultiFilePatch = patch
                    editorAIMultiFilePatchPaths = changedPaths
                    statusMessage = "Local AI proposed a multi-file patch for \(changedPaths.count) files."
                }
            } catch {
                statusMessage = "Editor AI failed: \(error.localizedDescription)"
            }
        }
    }

    func explainEditorSelectionWithLocalAI() {
        guard let selection = selectedEditorTextForAI() else {
            statusMessage = "No editor selection to explain."
            return
        }

        Task {
            do {
                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let explanation = try await localAIClient(endpoint: endpoint).explainEditorSelection(
                    selection,
                    projectGuidance: aiGuidanceContext
                )
                aiExplanation = explanation.text
                appendAIConversationHistoryEntry("editor-selection: \(explanation.text)")
                statusMessage = "Local AI explained the editor selection."
            } catch {
                statusMessage = "Editor selection AI failed: \(error.localizedDescription)"
            }
        }
    }

    func suggestEditorCompletionWithLocalAI() {
        let context = editorCompletionContext()

        Task {
            do {
                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let completion = try await localAIClient(endpoint: endpoint).suggestEditorCompletion(
                    prefix: context.prefix,
                    suffix: context.suffix,
                    projectGuidance: aiGuidanceContext
                )
                editorAICompletion = completion.text
                appendAIConversationHistoryEntry("editor-completion: \(completion.text)")
                statusMessage = "Local AI suggested an editor completion."
            } catch {
                statusMessage = "Editor completion AI failed: \(error.localizedDescription)"
            }
        }
    }

    func acceptEditorAICompletion() {
        guard !editorAICompletion.isEmpty else { return }
        let insertionOffset = editorInsertionOffset()
        let startIndex = scratchText.index(scratchText.startIndex, offsetBy: insertionOffset)
        scratchText.insert(contentsOf: editorAICompletion, at: startIndex)
        if editorVimEnabled {
            editorVimState = VimEditorState(
                buffer: scratchText,
                cursorOffset: insertionOffset + editorAICompletion.count,
                mode: editorVimState.mode
            )
        }
        editorAICompletion = ""
        statusMessage = "Accepted editor AI completion."
    }

    func acceptEditorAIProposal() {
        guard !editorAIProposal.isEmpty else { return }
        scratchText = editorAIProposal
        editorAIProposal = ""
        editorAIDiff = ""
        editorAIMultiFilePatch = ""
        editorAIMultiFilePatchPaths = []
        statusMessage = "Accepted editor AI proposal."
    }

    func applyEditorAIMultiFilePatch() {
        guard !editorAIMultiFilePatch.isEmpty else { return }
        do {
            let result = try MultiFileUnifiedPatch.apply(
                editorAIMultiFilePatch,
                using: LocalFileService(root: projectRoot)
            )
            editorAIMultiFilePatch = ""
            editorAIMultiFilePatchPaths = []
            editorAIDiff = ""
            refreshFiles()
            statusMessage = "Applied AI patch to \(result.changedPaths.count) files."
        } catch {
            statusMessage = "Apply AI patch failed: \(error.localizedDescription)"
        }
    }

    func validateLocalAIEndpoint() {
        do {
            _ = try LocalAIEndpoint(urlString: aiEndpoint)
            statusMessage = "Local AI endpoint accepted."
        } catch {
            statusMessage = "Built-in AI accepts localhost endpoints only."
        }
    }

    func suggestCommandWithLocalAI() {
        let prompt = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        Task {
            do {
                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let client = localAIClient(endpoint: endpoint)
                let suggestion = try await client.suggestCommand(
                    for: prompt,
                    projectGuidance: aiGuidanceContext
                )
                aiSuggestedCommand = suggestion.command
                appendAIConversationHistoryEntry("prompt: \(prompt)", scheduleSync: false)
                appendAIConversationHistoryEntry("suggested-command: \(suggestion.command)")
                statusMessage = "Local AI suggested a command."
            } catch {
                statusMessage = "Local AI request failed: \(error.localizedDescription)"
            }
        }
    }

    func askLocalAIQuestion() {
        let question = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        Task {
            do {
                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let client = localAIClient(endpoint: endpoint)
                let answer = try await client.answerQuestion(
                    question,
                    projectGuidance: aiGuidanceContext
                )
                aiExplanation = answer.text
                appendAIConversationHistoryEntry("question: \(question)", scheduleSync: false)
                appendAIConversationHistoryEntry("answer: \(answer.text)")
                statusMessage = "Local AI answered the question."
            } catch {
                statusMessage = "Local AI question failed: \(error.localizedDescription)"
            }
        }
    }

    func sendSuggestedCommandToTerminal() {
        let command = aiSuggestedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        runCommand(command)
    }

    func explainLastErrorWithLocalAI() {
        let blocks = terminalCommandBlocks()
        guard let failedBlock = blocks.last(where: { ($0.exitCode ?? 0) != 0 }) else {
            statusMessage = "No failed command block is available."
            return
        }
        let startLine = failedBlock.startLine
        Task {
            let start = Date()
            do {
                let endpoint = try LocalAIEndpoint(urlString: aiEndpoint)
                let client = localAIClient(endpoint: endpoint)
                let explanation = try await client.explainFailedCommand(
                    command: failedBlock.command,
                    output: failedBlock.output,
                    projectGuidance: aiGuidanceContext
                )
                aiExplanation = explanation.text
                appendAIConversationHistoryEntry("explanation: \(explanation.text)")
                activePanel = .ai
                recordTerminalExplain(failedBlockStartLine: startLine, in: blocks,
                                      durationSeconds: Date().timeIntervalSince(start), succeeded: true)
                statusMessage = "Local AI explained the failed command."
            } catch {
                recordTerminalExplain(failedBlockStartLine: startLine, in: blocks,
                                      durationSeconds: Date().timeIntervalSince(start), succeeded: false)
                statusMessage = "Error explanation failed: \(error.localizedDescription)"
            }
        }
    }

    nonisolated static func defaultAgentWorktreeParent() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Termy/agent-worktrees", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    nonisolated static func defaultAgentStateRoot() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Termy/agent-state", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    nonisolated static func defaultAgentHookHelperPath() -> String? {
        Bundle.main.resourceURL?
            .appendingPathComponent("termy-agent-hook.sh", isDirectory: false).path
    }

    private var selectedSessionWorkingDirectory: String? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first(where: { $0.id == id })?.currentWorkingDirectory
    }

    func launchCLIAgent(_ agent: CLIAgent) {
        launchCLIAgent(agent, isolation: .here, baseCwd: nil)
    }

    func launchCLIAgent(_ agent: CLIAgent, isolation: AgentIsolation, baseCwd: String?) {
        let sessionID = UUID()
        let workingDirectory: URL
        var worktreeHandle: AgentWorktreeHandle?

        switch isolation {
        case .here:
            workingDirectory = URL(fileURLWithPath: baseCwd ?? projectRoot.path)
        case .newWorktree:
            let repo = GitRepository(root: projectRoot)
            guard repo.isRepository() else {
                statusMessage = "Cannot start \(agent.displayName) in a worktree: \(projectRoot.path) is not a git repository."
                return
            }
            let shortID = UUID().uuidString.prefix(8).lowercased()
            let name = "agent-\(agent.rawValue)-\(shortID)"
            let path = agentWorktreeRoot.appendingPathComponent(name, isDirectory: true)
            let branch = "termy/\(name)"
            do {
                let baseSHA = try repo.resolveHEAD()
                try repo.addWorktree(branch: branch, base: baseSHA, path: path)
                worktreeHandle = AgentWorktreeHandle(path: path, branch: branch, repoRoot: projectRoot, baseSHA: baseSHA)
                workingDirectory = path
            } catch {
                statusMessage = "Failed to create worktree for \(agent.displayName): \(error.localizedDescription)"
                return
            }
        }

        let hookArguments = agent == .claudeCode
            ? AgentHookProtocol.claudeCodeLaunchArguments(
                helperPath: agentHookHelperPath,
                stateDir: agentStateRoot.path,
                sessionID: sessionID)
            : []
        let command = CLIAgentLaunchCommand(
            agent: agent, arguments: hookArguments, workingDirectory: workingDirectory)
        let profile = ConnectionProfile.local(name: "\(agent.displayName) Agent")
        var session = TermySession(
            id: sessionID,
            title: "\(agent.displayName) — \(workingDirectory.lastPathComponent)",
            profile: profile,
            lines: [
                TerminalLine(role: .system, text: "Launching \(agent.displayName) in \(command.workingDirectory.path)."),
                TerminalLine(role: .system, text: "Authentication stays with the external CLI; Termy does not store API keys or tokens.")
            ],
            interactionMode: .rawPTY,
            agentType: agent
        )
        session.agentActivity = .working
        agentStateMachines[sessionID] = AgentStateMachine()   // initial .working
        ensureAgentStateWatcherStarted()
        sessions.append(session)
        selectedSessionID = session.id
        if let worktreeHandle {
            agentWorktrees[session.id] = worktreeHandle
        }

        var environment = ProcessInfo.processInfo.environment
        environment.merge(command.environmentOverrides) { _, new in new }
        environment["TERM"] = "xterm-256color"

        let descriptor = TerminalLaunchDescriptor(
            executable: command.executablePath,
            arguments: command.arguments,
            environment: environment,
            workingDirectory: command.workingDirectory.path,
            usesZshIntegration: false)
        registerTerminalLaunch(descriptor, for: session.id)
        let isolationNote = isolation == .newWorktree ? " (worktree)" : ""
        appendAIConversationHistoryEntry("agent: \(agent.displayName) launched in \(command.workingDirectory.path)\(isolationNote)")
        statusMessage = "\(agent.displayName) launched."
        openModuleTab(.agents)
        refreshAgentVitals()
    }

    /// FB-3-6: send a single ^C (ETX) into a live agent's PTY. Tool-agnostic —
    /// the TTY line discipline delivers SIGINT to the foreground process group,
    /// exactly like pressing Ctrl-C, and works even when the terminal is unfocused.
    func interruptAgent(sessionID: UUID) {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              session.agentType != nil, session.agentActivity != .exited else { return }
        terminalInputSinks[sessionID]?("\u{03}")
        statusMessage = "Interrupt sent to \(session.title)."
    }

    /// Read-only session lookup for the Agents embed (FB-3 / Slice 3).
    func session(for id: UUID) -> TermySession? {
        sessions.first { $0.id == id }
    }

    /// Slice 3: write a reply line into a live agent's PTY (mirrors `interruptAgent`,
    /// but a full line + CR instead of ^C). No-op for a non-agent, exited, or empty input.
    func sendAgentReply(_ text: String, to sessionID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let session = sessions.first(where: { $0.id == sessionID }),
              session.agentType != nil, session.agentActivity != .exited else { return }
        terminalInputSinks[sessionID]?(trimmed + "\r")
        statusMessage = "Sent to \(session.title)."
    }

    /// v3 Shell §6.1 History action: place a chosen command at the selected
    /// session's live prompt WITHOUT executing it (no CR — the user reviews then
    /// presses Enter). Falls back to the pasteboard when the session has no live
    /// input sink (e.g. a `.commandLine` SSH session).
    func insertCommandAtPrompt(_ command: String) {
        guard let id = selectedSessionID else { return }
        if let sink = terminalInputSinks[id] {
            sink(command)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            statusMessage = "Copied \"\(command)\" to the clipboard (no live prompt)."
        }
    }

    /// v3 Shell §6.1 Find action: reveal the on-demand find/output toolbar and
    /// ask its field to take focus. The field (`TerminalSearchBar`) observes the
    /// monotonic token; the toolbar is gated on `terminalSearchVisible`.
    func requestTerminalSearchFocus() {
        objectWillChange.send()
        terminalSearchVisible = true
        terminalSearchFocusToken += 1
    }

    /// v3 Shell §6.1: hide the find/output toolbar (its `xmark` / Esc). Leaves the
    /// query untouched so re-opening Find restores the last search.
    func dismissTerminalSearch() {
        objectWillChange.send()
        terminalSearchVisible = false
    }

    /// FB-3-6: re-spawn a live agent in place — same worktree/cwd, same hook
    /// args, same sessionID — via a launch-generation bump. Resets the agent's
    /// state machine and progress (the new run reuses TaskCreate ids "1","2",…,
    /// so old progress must be wiped) and purges its stale state/tool files.
    /// Exited agents are not restartable (a clean exit already removed a
    /// disposable worktree) — re-launch via ⌘K instead.
    func restartAgent(sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }),
              sessions[index].agentType != nil,
              sessions[index].agentActivity != .exited else { return }

        agentQuiescenceTasks[sessionID]?.cancel()
        agentQuiescenceTasks.removeValue(forKey: sessionID)
        agentStateMachines[sessionID] = AgentStateMachine()      // fresh .working
        agentProgress.removeValue(forKey: sessionID)
        try? FileManager.default.removeItem(
            at: agentStateRoot.appendingPathComponent("\(sessionID.uuidString).state"))
        AgentProgressFiles.removeAll(forSession: sessionID, in: agentStateRoot)
        terminalInputBuffers[sessionID] = nil
        terminalInputHighlights[sessionID] = nil
        // The old surface (and its [weak view] input sink) is torn down below.
        // Clear the stale sink so a restart on an unmounted tab doesn't leave a
        // dead closure that silently swallows a later interrupt/reply.
        terminalInputSinks[sessionID] = nil

        let now = Date()
        sessions[index].agentActivity = .working
        sessions[index].startedAt = now
        sessions[index].stateChangedAt = now

        let name = sessions[index].agentType?.displayName ?? "agent"
        appendLine(TerminalLine(role: .system, text: "Restarting \(name)…"), to: sessionID)
        let oldGeneration = terminalLaunchGeneration(for: sessionID)
        bumpTerminalLaunchGeneration(for: sessionID)
        // Slice 5: dismantleNSView no longer reaps the previous run — kill it here,
        // after the bump, so its old-gen exit is ignored by the generation guard.
        terminalSurfacePool.terminate(forKey: "\(sessionID.uuidString)#\(oldGeneration)")
        refreshAgentVitals()
        statusMessage = "\(name) restarted."
    }

    /// Removes a clean agent worktree (and its branch) on session end; keeps a
    /// dirty/unmerged one and reports it. Idempotent — consumes the handle.
    private func cleanupAgentWorktreeIfNeeded(for sessionID: UUID) {
        guard !suppressAgentWorktreeCleanup else { return }
        guard let handle = agentWorktrees.removeValue(forKey: sessionID) else { return }
        let worktreeRepo = GitRepository(root: handle.path)
        let mainRepo = GitRepository(root: handle.repoRoot)
        do {
            if try worktreeRepo.isDisposable(baseSHA: handle.baseSHA) {
                try mainRepo.removeWorktree(path: handle.path)
                try? mainRepo.deleteBranch(handle.branch)
            } else {
                appendLine(TerminalLine(role: .system,
                    text: "Worktree kept (uncommitted/unmerged changes): \(handle.path.path)"),
                    to: sessionID)
            }
        } catch {
            appendLine(TerminalLine(role: .system,
                text: "Worktree cleanup failed: \(error.localizedDescription)"),
                to: sessionID)
        }
    }

    func importSSHConfig() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")

        do {
            let config = try String(contentsOf: url, encoding: .utf8)
            let imported = try SSHConfigImporter().importProfiles(from: config)
            let existingNames = Set(profiles.map(\.name))
            let newProfiles = imported.filter { !existingNames.contains($0.name) }
            profiles.append(contentsOf: newProfiles)
            statusMessage = "Imported \(newProfiles.count) SSH profile(s)."
        } catch CocoaError.fileReadNoSuchFile {
            statusMessage = "No ~/.ssh/config file found."
        } catch {
            statusMessage = "SSH config import failed: \(error.localizedDescription)"
        }
    }

    func createSSHProfileFromDraft() {
        let name = sshProfileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = sshProfileHostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = sshProfileUserDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = sshProfilePortDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let identityPath = sshProfileIdentityDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupPath = sshProfileGroupDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !host.isEmpty, !user.isEmpty, !identityPath.isEmpty else {
            statusMessage = "SSH profile name, host, user, and identity are required."
            return
        }
        guard let port = Int(portText) else {
            statusMessage = "SSH profile port must be a number."
            return
        }

        let profile = ConnectionProfile.ssh(
            name: name,
            host: host,
            user: user,
            port: port,
            identity: .keychain("ssh.identity.\(identityPath)"),
            groupPath: groupPath,
            sshOptions: ConnectionProfile.sshOptions(fromDraft: sshOptionsDraft)
        )
        profiles.removeAll { $0.kind == .ssh && $0.name == profile.name }
        profiles.append(profile)
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        sshProfileNameDraft = ""
        sshProfileHostDraft = ""
        sshProfilePortDraft = "22"
        sshProfileGroupDraft = ""
        selectedConnectionProfileID = profile.id
        stampSyncEdit("connection-\(profile.id.uuidString)")
        stagePrivateSyncSnapshot()
        statusMessage = "Created SSH profile \(profile.name)."
    }

    func createRDPProfileFromDraft() {
        let name = rdpProfileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = rdpProfileHostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = rdpProfileUserDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let gateway = rdpProfileGatewayDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let credential = rdpProfileCredentialDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupPath = rdpProfileGroupDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !host.isEmpty, !user.isEmpty, !credential.isEmpty else {
            statusMessage = "RDP profile name, host, user, and credential reference are required."
            return
        }

        let profile = ConnectionProfile.rdp(
            name: name,
            host: host,
            user: user,
            gateway: gateway.isEmpty ? nil : gateway,
            credential: .keychain(credential),
            groupPath: groupPath
        )
        profiles.removeAll { $0.kind == .rdp && $0.name == profile.name }
        profiles.append(profile)
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        rdpProfileNameDraft = ""
        rdpProfileHostDraft = ""
        rdpProfileGatewayDraft = ""
        rdpProfileGroupDraft = ""
        selectedConnectionProfileID = profile.id
        stampSyncEdit("connection-\(profile.id.uuidString)")
        stagePrivateSyncSnapshot()
        statusMessage = "Created RDP profile \(profile.name)."
    }

    func selectConnectionProfileForEditing(_ profile: ConnectionProfile) {
        selectedConnectionProfileID = profile.id
        sshOptionsDraft = ConnectionProfile.serializedSSHOptions(profile.sshOptions)
            .split(separator: ";")
            .joined(separator: "\n")
    }

    func saveSSHOptionsForSelectedProfile() {
        guard let selectedConnectionProfileID,
              let index = profiles.firstIndex(where: { $0.id == selectedConnectionProfileID }),
              profiles[index].kind == .ssh else {
            statusMessage = "Select an SSH profile before saving options."
            return
        }

        let options = ConnectionProfile.sshOptions(fromDraft: sshOptionsDraft)
        profiles[index] = profiles[index].withSSHOptions(options)

        let profileName = profiles[index].name
        sshOptionsDraft = ConnectionProfile.serializedSSHOptions(options)
            .split(separator: ";")
            .joined(separator: "\n")
        stampSyncEdit("connection-\(selectedConnectionProfileID.uuidString)")
        stagePrivateSyncSnapshot()
        statusMessage = "Updated SSH options for \(profileName)."
    }

    func generateSSHKey() {
        do {
            let command = try SSHKeyGenerationCommand(keyPath: sshKeyPath, comment: sshKeyComment)
            launchToolSession(
                title: "SSH Keygen",
                executablePath: command.executablePath,
                arguments: command.arguments,
                startMessage: "Generating SSH key at \(sshKeyPath). Passphrase entry is handled by ssh-keygen in the PTY."
            )
        } catch {
            statusMessage = "SSH key generation failed: \(error.localizedDescription)"
        }
    }

    func addSSHKeyToAgent() {
        do {
            let command = try SSHAgentAddCommand(keyPath: sshKeyPath)
            launchToolSession(
                title: "SSH Agent",
                executablePath: command.executablePath,
                arguments: command.arguments,
                startMessage: "Adding SSH key to macOS ssh-agent and Apple Keychain."
            )
        } catch {
            statusMessage = "SSH agent add failed: \(error.localizedDescription)"
        }
    }

    func importSSHPrivateKeyToKeychain() {
        do {
            let privateKey = try Data(contentsOf: sshKeyURL())
            _ = try sshPrivateKeyVault.savePrivateKey(privateKey, identityPath: sshKeyPath)
            statusMessage = "Stored SSH private key in iCloud Keychain."
        } catch {
            statusMessage = "SSH private key import failed: \(error.localizedDescription)"
        }
    }

    func restoreSSHPrivateKeyFromKeychain() {
        do {
            let reference = try SSHPrivateKeyVault.reference(forIdentityPath: sshKeyPath)
            try sshPrivateKeyVault.restorePrivateKey(reference, to: sshKeyURL())
            statusMessage = "Restored SSH private key from iCloud Keychain."
        } catch {
            statusMessage = "SSH private key restore failed: \(error.localizedDescription)"
        }
    }

    func openConnection(_ profile: ConnectionProfile) {
        switch profile.kind {
        case .local:
            newLocalShellSession()
        case .ssh:
            openSSHConnection(profile)
        case .rdp:
            openRDPSession(profile)
        }
    }

    func openLocalTunnel(_ profile: ConnectionProfile) {
        do {
            let spec = try currentTunnelDraft().spec()
            let tunnel = try SavedSSHTunnel(
                name: tunnelName(profile: profile, spec: spec),
                profile: profile,
                tunnels: [spec],
                autoReconnect: false
            )
            startSavedTunnel(tunnel, profile: profile)
        } catch {
            statusMessage = "SSH tunnel failed: \(error.localizedDescription)"
        }
    }

    func saveCurrentLocalTunnel(_ profile: ConnectionProfile) {
        do {
            let spec = try currentTunnelDraft().spec()
            let tunnel = try SavedSSHTunnel(
                name: tunnelName(profile: profile, spec: spec),
                profile: profile,
                tunnels: [spec],
                autoReconnect: true
            )
            savedTunnels.removeAll { $0.name == tunnel.name && $0.profileName == tunnel.profileName }
            savedTunnels.append(tunnel)
            savedTunnels.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            statusMessage = "Saved SSH tunnel \(tunnel.name)."
        } catch {
            statusMessage = "Save tunnel failed: \(error.localizedDescription)"
        }
    }

    func currentTunnelDraft() -> SSHTunnelDraft {
        SSHTunnelDraft(
            kind: tunnelKind,
            bindPort: tunnelLocalPort,
            targetHost: tunnelRemoteHost,
            targetPort: tunnelRemotePort
        )
    }

    func openSavedTunnel(_ tunnel: SavedSSHTunnel) {
        guard let profile = profiles.first(where: { $0.kind == .ssh && $0.name == tunnel.profileName }) else {
            statusMessage = "Saved tunnel profile \(tunnel.profileName) is missing."
            return
        }
        startSavedTunnel(tunnel, profile: profile)
    }

    func probeSavedTunnel(_ tunnel: SavedSSHTunnel) {
        guard let spec = tunnel.tunnels.first else {
            tunnelProbeStatus[tunnel.id] = "No tunnel spec"
            statusMessage = "Tunnel probe failed: no tunnel spec."
            return
        }
        let profile = profiles.first { $0.kind == .ssh && $0.name == tunnel.profileName }

        do {
            let probe = try SSHTunnelProbeCommand(tunnel: spec, profile: profile)
            tunnelProbeStatus[tunnel.id] = "Checking"
            let command = ([probe.executablePath] + probe.arguments)
                .map(shellQuote)
                .joined(separator: " ")
            let root = projectRoot
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try ShellCommandRunner(workingDirectory: root).run(command) }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let output) where output.exitCode == 0:
                        self.tunnelProbeStatus[tunnel.id] = "Probe OK"
                        self.statusMessage = "Tunnel probe passed for \(tunnel.name)."
                    case .success(let output):
                        self.tunnelProbeStatus[tunnel.id] = "Probe failed (\(output.exitCode))"
                        self.statusMessage = "Tunnel probe failed for \(tunnel.name)."
                    case .failure(let error):
                        self.tunnelProbeStatus[tunnel.id] = "Probe error"
                        self.statusMessage = "Tunnel probe failed: \(error.localizedDescription)"
                    }
                }
            }
        } catch SSHTunnelProbeError.unsupportedRemoteForward {
            tunnelProbeStatus[tunnel.id] = "Remote probe unsupported"
            statusMessage = "Remote forwarding cannot be locally probed."
        } catch SSHTunnelProbeError.missingRemoteProfile {
            tunnelProbeStatus[tunnel.id] = "Profile missing"
            statusMessage = "Tunnel probe failed: saved SSH profile \(tunnel.profileName) is missing."
        } catch {
            tunnelProbeStatus[tunnel.id] = "Probe error"
            statusMessage = "Tunnel probe failed: \(error.localizedDescription)"
        }
    }

    func openSFTPSession(_ profile: ConnectionProfile) {
        do {
            let command = try SFTPLaunchCommand(profile: profile)
            launchToolSession(
                title: "\(profile.name) SFTP",
                executablePath: command.executablePath,
                arguments: command.arguments,
                startMessage: "Starting SFTP via system OpenSSH. Secrets remain in Keychain or ssh-agent."
            )
        } catch {
            statusMessage = "SFTP session failed: \(error.localizedDescription)"
        }
    }

    func openRDPSession(_ profile: ConnectionProfile) {
        do {
            let resolution = RDPResolution(
                width: Int(rdpWidth) ?? 1920,
                height: Int(rdpHeight) ?? 1080
            )
            let descriptor = try RDPSessionDescriptor(
                profile: profile,
                resolution: resolution,
                scale: Double(rdpScale) ?? 1.0,
                localFolderPath: rdpLocalFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let router = RDPTransportEventRouter(descriptor: descriptor)
            let session = TermySession(
                title: profile.name,
                profile: profile,
                lines: [
                    TerminalLine(role: .system, text: "RDP session prepared for \(descriptor.user)@\(descriptor.host)."),
                    TerminalLine(role: .system, text: "Gateway: \(descriptor.gateway ?? "none"), resolution: \(descriptor.resolution.width)x\(descriptor.resolution.height) @ \(descriptor.scale)x."),
                    TerminalLine(role: .system, text: "Network target: \(descriptor.host):3389 via FreeRDP 3.26.0."),
                    TerminalLine(role: .system, text: "Redirections: \(formatRDPRedirections(descriptor.redirections))."),
                    TerminalLine(role: .system, text: "Lifecycle: \(formatRDPSessionState(router.lifecycle.state))."),
                    TerminalLine(role: .system, text: "Reconnect: up to \(descriptor.reconnectPolicy.maxAttempts) attempts, \(descriptor.reconnectPolicy.retryDelaySeconds)s delay, network/transport failures only."),
                    TerminalLine(role: .system, text: "Credential is referenced by Keychain item only.")
                ]
            )
            sessions.append(session)
            rdpRouters[session.id] = router
            selectedSessionID = session.id
            statusMessage = "RDP session connecting."
            startLiveRDPConnection(sessionID: session.id, descriptor: descriptor)
        } catch {
            statusMessage = "RDP session failed: \(error.localizedDescription)"
        }
    }

    func pollLocalRDPClipboard(for sessionID: UUID) -> RDPClipboardMessage? {
        captureLocalRDPClipboardForRouter(for: sessionID)
    }

    func handleRDPTransportEvent(_ event: RDPTransportEvent, for sessionID: UUID) -> RDPTransportEventResult? {
        // Post-cutover, the FreeRDP-driven shim never emits the synthetic
        // handshake/exchange events that the bespoke engine used to surface
        // (those are owned by FreeRDP itself now and never bubble up to
        // Swift). The cases remain in `RDPTransportEvent` so the router
        // contract is byte-stable for unit tests and feed-in callers.
        guard var router = rdpRouters[sessionID] else { return nil }
        do {
            let result = try router.handle(
                event,
                writeClipboard: { [rdpPasteboardAdapter] text in
                    rdpPasteboardAdapter.write(text: text)
                },
                playAudio: { [rdpAudioOutputPlayer] frame in
                    do {
                        try rdpAudioOutputPlayer.play(frame)
                    } catch {
                        statusMessage = "RDP audio playback failed: \(error.localizedDescription)"
                    }
                }
            )
            rdpRouters[sessionID] = router
            if let reconnectPlan = result.reconnectPlan {
                statusMessage = "RDP reconnect scheduled: attempt \(reconnectPlan.attempt) in \(reconnectPlan.delaySeconds)s."
                let profileName = sessions.first { $0.id == sessionID }?.profile.name ?? "RDP session"
                remoteNotificationSink(
                    .rdpReconnectScheduled(
                        profileName: profileName,
                        attempt: reconnectPlan.attempt,
                        delaySeconds: reconnectPlan.delaySeconds
                    )
                )
            }
            return result
        } catch {
            rdpRouters[sessionID] = router
            statusMessage = "RDP transport event failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func captureLocalRDPClipboardForRouter(for sessionID: UUID) -> RDPClipboardMessage? {
        guard var router = rdpRouters[sessionID] else { return nil }
        let message = router.captureLocalClipboard(snapshot: rdpPasteboardAdapter.snapshot())
        rdpRouters[sessionID] = router
        // Push to server via FreeRDP if we captured something local→remote.
        if let message,
           message.direction == .localToRemote,
           let freerdp = rdpSessions[sessionID] {
            _ = freerdp.sendClipboardText(message.text)
        }
        return message
    }

    func applyRemoteRDPClipboard(text: String, sequence: Int, for sessionID: UUID) -> RDPClipboardMessage? {
        handleRDPTransportEvent(.remoteClipboard(text: text, sequence: sequence), for: sessionID)?.clipboardMessage
    }

    func playRemoteRDPAudioFrame(_ frame: RDPAudioOutputFrame, for sessionID: UUID) -> RDPAudioOutputFrame? {
        handleRDPTransportEvent(.audioOutput(frame), for: sessionID)?.audioFrame
    }

    func applyRemoteRDPFrame(_ frame: RDPRemoteDesktopFrame, for sessionID: UUID) -> RDPRemoteDesktopFrame? {
        handleRDPTransportEvent(.desktopFrame(frame), for: sessionID)?.desktopFrame
    }

    func handleLocalRDPInputEvents(_ events: [RDPSlowPathInputEvent], for sessionID: UUID) {
        guard !events.isEmpty,
              sessions.contains(where: { $0.id == sessionID }) else {
            return
        }

        if let freerdp = rdpSessions[sessionID] {
            let sent = freerdp.sendInputEvents(events)
            if sent == events.count {
                appendLine(TerminalLine(
                    role: .system,
                    text: "RDP input sent: \(events.count) slow-path event(s)."
                ), to: sessionID)
                statusMessage = "RDP input sent."
            } else {
                appendLine(TerminalLine(
                    role: .stderr,
                    text: "RDP input partially sent: \(sent)/\(events.count) event(s)."
                ), to: sessionID)
                statusMessage = "RDP input partially sent."
            }
            return
        }

        appendLine(TerminalLine(
            role: .system,
            text: "RDP input mapped: \(events.count) slow-path event(s) prepared for transport."
        ), to: sessionID)
        statusMessage = "RDP input mapped to slow-path event(s)."
    }

    func currentRDPState(for sessionID: UUID) -> RDPSessionState? {
        rdpRouters[sessionID]?.lifecycle.state
    }

    func currentRDPFrame(for sessionID: UUID) -> RDPRemoteDesktopFrame? {
        rdpRouters[sessionID]?.frameBuffer.currentFrame
    }

    func shutdown() {
        rdpConnectionTasks.values.forEach { $0.cancel() }
        rdpSessions.values.forEach { $0.stop() }
        rdpRouters.removeAll()
        rdpSessions.removeAll()
        rdpConnectionTasks.removeAll()
        // Synchronously remove each sidecar's workDir — the willTerminate
        // notification fires on the main thread moments before the process
        // exits, so an `await terminate()` would not finish in time. The
        // workDir is a `nonisolated let`, sync-accessible. Child zsh PIDs
        // are reaped by launchd after Termy exits.
        for sidecar in completionSidecars.values {
            try? FileManager.default.removeItem(at: sidecar.workDir)
        }
        completionSidecars.removeAll()
        completionSidecarTokens.removeAll()
    }

    func captureSessionRestoreSnapshotNow(capturedAt: Date = Date()) throws {
        let entries = sessions.compactMap { session in
            sessionRestoreEntry(for: session, capturedAt: capturedAt)
        }
        guard !entries.isEmpty else {
            try sessionRestoreStore.clear()
            hasRestorableSession = false
            sessionRestoreStatus = nil
            return
        }
        let capturedSessionIDs = Set(entries.map(\.id))
        let capturedSelectedSessionID = selectedSessionID.flatMap {
            capturedSessionIDs.contains($0) ? $0 : nil
        }
        let snapshot = SessionRestoreSnapshot.makeBounded(
            capturedAt: capturedAt,
            selectedSessionID: capturedSelectedSessionID,
            paneTree: paneLayout.paneTree.storageValue,
            focusedPane: paneLayout.focusedPane,
            activePanel: activePanel?.rawValue,
            sessions: entries
        )
        try sessionRestoreStore.save(snapshot)
        hasRestorableSession = true
        sessionRestoreStatus = "Saved previous session context."
    }

    func restoreLastSession() {
        let snapshot: SessionRestoreSnapshot?
        do {
            snapshot = try sessionRestoreStore.load()
        } catch {
            snapshot = nil
        }

        guard let snapshot, !snapshot.sessions.isEmpty else {
            hasRestorableSession = false
            sessionRestoreStatus = nil
            statusMessage = "No previous session to restore."
            return
        }

        var restoredSessions: [TermySession] = []
        var restoredDescriptors: [UUID: TerminalLaunchDescriptor] = [:]
        var restoredTranscriptReplays: [UUID: String] = [:]

        for entry in snapshot.sessions {
            let restored = restoredSession(from: entry)
            restoredSessions.append(restored.session)
            if let descriptor = restored.launchDescriptor {
                restoredDescriptors[entry.id] = descriptor
                restoredTranscriptReplays[entry.id] = terminalTranscriptReplay(from: restored.session.lines)
            }
        }

        clearRuntimeStateForManualSessionRestore()
        sessions = restoredSessions
        terminalLaunchDescriptors = restoredDescriptors
        terminalLaunchGenerations = Dictionary(uniqueKeysWithValues: restoredDescriptors.keys.map { ($0, 0) })
        terminalInitialTranscriptReplays = restoredTranscriptReplays
        spawnRestoredCompletionSidecars(for: snapshot.sessions)
        selectedSessionID = snapshot.selectedSessionID.flatMap { id in
            restoredSessions.contains(where: { $0.id == id }) ? id : nil
        } ?? restoredSessions.first?.id

        if let paneTreeValue = snapshot.paneTree,
           let paneTree = WorkspacePaneTree(storageValue: paneTreeValue) {
            paneLayout = WorkspacePaneLayout(paneTree: paneTree, focusedPane: snapshot.focusedPane)
        }
        activePanel = snapshot.activePanel.flatMap(OverlayPanel.init(rawValue:))
        hasRestorableSession = true
        statusMessage = "Restored previous session context."
    }

    private func clearRuntimeStateForManualSessionRestore() {
        rdpConnectionTasks.values.forEach { $0.cancel() }
        rdpSessions.values.forEach { $0.stop() }
        rdpRouters.removeAll()
        rdpSessions.removeAll()
        rdpConnectionTasks.removeAll()

        terminalSurfacePool.drain()
        terminalLaunchDescriptors = [:]
        terminalLaunchGenerations = [:]
        terminalScreenTextProviders = [:]
        terminalInitialTranscriptReplays = [:]
        tunnelReconnectContexts = [:]
        tunnelReconnectAttempts = [:]
        terminalInputBuffers = [:]
        terminalInputHighlights = [:]
        terminalCaretOriginProviders = [:]
        terminalInputSinks = [:]
        terminalMenuStates = [:]
        commandStartTimes = [:]
        commandDurations = [:]
        pendingCommandPromptIndex = [:]
        terminalLocalClearSinks = [:]
        terminalAltScreen = [:]
        selectedTerminalBlockStartLine = nil
        foldedTerminalBlockStartLines = []
        terminalSearchResults = []
        terminalLinks = []

        sidecarDebounceTasks.values.forEach { $0.cancel() }
        sidecarDebounceTasks.removeAll()
        for sidecar in completionSidecars.values {
            Task { await sidecar.terminate() }
        }
        completionSidecars.removeAll()
        completionSidecarTokens.removeAll()
        sidecarLastAppliedId.removeAll()
        sidecarLastCandidates.removeAll()
        sidecarDebounceElapsed.removeAll()
        sidecarGhosts.removeAll()
        sidecarDisabledSessions.removeAll()
    }

    private func restoredSession(
        from entry: SessionRestoreEntry
    ) -> (session: TermySession, launchDescriptor: TerminalLaunchDescriptor?) {
        let descriptor = restoredLaunchDescriptor(for: entry)
        let profile = restoredConnectionProfile(for: entry)
        var lines = [TerminalLine(role: .system, text: sessionRestoreMarker(for: entry))]
        lines.append(contentsOf: entry.scrollback.map { terminalLine(from: $0) })

        if descriptor == nil {
            if entry.kind == .rdpPlaceholder {
                lines.append(TerminalLine(
                    role: .system,
                    text: "RDP session requires explicit reconnect. Restored transcript/context only."
                ))
            } else if let warning = restoreProfileWarning(for: entry) {
                lines.append(TerminalLine(role: .system, text: warning))
            } else if let executable = restoreExecutable(for: entry.launch) {
                lines.append(TerminalLine(
                    role: .system,
                    text: "Termy could not restart \(entry.title): executable \(executable) is unavailable. Transcript only."
                ))
            }
        }

        return (
            TermySession(
                id: entry.id,
                title: entry.title,
                profile: profile,
                lines: lines,
                currentWorkingDirectory: entry.workingDirectory,
                lastExitCode: entry.lastExitCode.map(Int32.init),
                interactionMode: descriptor == nil ? .commandLine : .rawPTY
            ),
            descriptor
        )
    }

    private func restoredLaunchDescriptor(for entry: SessionRestoreEntry) -> TerminalLaunchDescriptor? {
        switch entry.launch {
        case .localShell(let shellKind, let executable, let arguments):
            guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
            let descriptor = localZshLaunchDescriptor(
                executable: executable,
                arguments: arguments,
                baseEnvironment: ProcessInfo.processInfo.environment,
                theme: terminalTheme,
                syntaxHighlightDir: Bundle.main.resourceURL?
                    .appendingPathComponent("zsh-syntax-highlighting", isDirectory: true).path,
                usesZshIntegration: shellKind == "zsh"
            )
            return descriptor.withWorkingDirectory(entry.workingDirectory)
        case .sshProfile(let profileID, _, let executable, _):
            guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
            guard let uuid = UUID(uuidString: profileID),
                  let profile = profiles.first(where: { $0.id == uuid && $0.kind == .ssh }),
                  let command = try? SSHLaunchCommand(profile: profile, executablePath: executable) else {
                return nil
            }
            return TerminalLaunchDescriptor(
                executable: command.executablePath,
                arguments: command.arguments,
                environment: sshEnvironment(),
                workingDirectory: entry.workingDirectory ?? projectRoot.path,
                usesZshIntegration: false
            )
        case .cliAgent(_, let executable, let arguments):
            guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
            return TerminalLaunchDescriptor(
                executable: executable,
                arguments: arguments,
                environment: sshEnvironment(),
                workingDirectory: entry.workingDirectory ?? projectRoot.path,
                usesZshIntegration: false
            )
        case .rdpPlaceholder:
            return nil
        }
    }

    private func restoredConnectionProfile(for entry: SessionRestoreEntry) -> ConnectionProfile {
        switch entry.profileReference {
        case .local:
            return ConnectionProfile.local(name: entry.title)
        case .tool(_, let displayName):
            return ConnectionProfile.local(name: displayName)
        case .connectionProfile(let id, let name, let host):
            if let uuid = UUID(uuidString: id),
               let profile = profiles.first(where: { $0.id == uuid }) {
                return profile
            }
            let uuid = UUID(uuidString: id) ?? UUID()
            let kind: ConnectionKind = entry.kind == .rdpPlaceholder ? .rdp : .ssh
            return ConnectionProfile(
                id: uuid,
                kind: kind,
                name: name,
                host: host,
                user: nil,
                port: kind == .rdp ? 3389 : 22,
                gateway: nil,
                groupPath: nil,
                sshOptions: [:],
                terminalOutputMode: .stream,
                secretReferences: []
            )
        }
    }

    private func sessionRestoreMarker(for entry: SessionRestoreEntry) -> String {
        let formatter = ISO8601DateFormatter()
        return "Restored local scrollback from \(formatter.string(from: entry.capturedAt)); a new process starts below."
    }

    private func terminalLine(from restoredLine: RestoredTerminalLine) -> TerminalLine {
        TerminalLine(role: terminalLineRole(from: restoredLine.role), text: restoredLine.text)
    }

    private func terminalLineRole(from role: RestoredTerminalLine.Role) -> TerminalLine.Role {
        switch role {
        case .prompt:
            return .prompt
        case .stdout:
            return .stdout
        case .stderr:
            return .stderr
        case .system:
            return .system
        }
    }

    private func restoreExecutable(for launch: SessionRestoreLaunch) -> String? {
        switch launch {
        case .localShell(_, let executable, _),
             .sshProfile(_, _, let executable, _),
             .cliAgent(_, let executable, _):
            return executable
        case .rdpPlaceholder:
            return nil
        }
    }

    private func restoreProfileWarning(for entry: SessionRestoreEntry) -> String? {
        guard case .sshProfile(let profileID, let fallbackName, let executable, _) = entry.launch else {
            return nil
        }
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        guard let uuid = UUID(uuidString: profileID),
              profiles.contains(where: { $0.id == uuid && $0.kind == .ssh }) else {
            return "Termy could not restart \(entry.title): SSH profile \(fallbackName) is unavailable. Transcript only."
        }
        return "Termy could not restart \(entry.title): SSH profile \(fallbackName) is invalid. Transcript only."
    }

    private func terminalTranscriptReplay(from lines: [TerminalLine]) -> String {
        lines.map(\.text).joined(separator: "\r\n") + "\r\n"
    }

    private func spawnRestoredCompletionSidecars(for entries: [SessionRestoreEntry]) {
        for entry in entries where terminalLaunchDescriptors[entry.id] != nil {
            guard case .localShell(let shellKind, let executable, _) = entry.launch,
                  shellKind == "zsh" else {
                continue
            }
            spawnSidecar(for: entry.id, shellPath: executable)
        }
    }

    private func sessionRestoreEntry(
        for session: TermySession,
        capturedAt: Date
    ) -> SessionRestoreEntry? {
        if session.profile.kind == .rdp {
            return SessionRestoreEntry(
                id: session.id,
                title: session.title,
                kind: .rdpPlaceholder,
                profileReference: restoreProfileReference(for: session),
                workingDirectory: nil,
                launch: .rdpPlaceholder(
                    profileID: session.profile.id.uuidString,
                    fallbackName: session.profile.name
                ),
                scrollback: [],
                scrollbackBytes: 0,
                lastExitCode: session.lastExitCode.map(Int.init),
                capturedAt: capturedAt
            )
        }

        guard let descriptor = terminalLaunchDescriptors[session.id] else {
            return nil
        }

        return SessionRestoreEntry(
            id: session.id,
            title: session.title,
            kind: restoreKind(for: session),
            profileReference: restoreProfileReference(for: session),
            workingDirectory: restoreWorkingDirectory(for: session, descriptor: descriptor),
            launch: restoreLaunch(for: session, descriptor: descriptor),
            scrollback: session.lines.map(restoreLine),
            scrollbackBytes: 0,
            lastExitCode: session.lastExitCode.map(Int.init),
            capturedAt: capturedAt
        )
    }

    private func restoreKind(for session: TermySession) -> SessionRestoreKind {
        if session.profile.kind == .ssh {
            return .ssh
        }
        if cliAgentIdentity(for: session) != nil {
            return .cliAgent
        }
        return .localPTY
    }

    private func restoreLaunch(
        for session: TermySession,
        descriptor: TerminalLaunchDescriptor
    ) -> SessionRestoreLaunch {
        if session.profile.kind == .ssh {
            return .sshProfile(
                profileID: session.profile.id.uuidString,
                fallbackName: session.profile.name,
                executable: descriptor.executable,
                arguments: descriptor.arguments
            )
        }
        if let agent = cliAgentIdentity(for: session) {
            return .cliAgent(
                kind: agent.kind,
                executable: descriptor.executable,
                arguments: descriptor.arguments
            )
        }
        return .localShell(
            shellKind: terminalShellKind,
            executable: descriptor.executable,
            arguments: descriptor.arguments
        )
    }

    private func restoreProfileReference(for session: TermySession) -> SessionRestoreProfileReference {
        switch session.profile.kind {
        case .local:
            if let agent = cliAgentIdentity(for: session) {
                return .tool(kind: agent.kind, displayName: agent.displayName)
            }
            return .local
        case .ssh, .rdp:
            return .connectionProfile(
                id: session.profile.id.uuidString,
                name: session.profile.name,
                host: session.profile.host
            )
        }
    }

    private func restoreWorkingDirectory(
        for session: TermySession,
        descriptor: TerminalLaunchDescriptor
    ) -> String? {
        session.currentWorkingDirectory ?? descriptor.workingDirectory
    }

    private func restoreLine(_ line: TerminalLine) -> RestoredTerminalLine {
        RestoredTerminalLine(role: restoreLineRole(line.role), text: line.text)
    }

    private func restoreLineRole(_ role: TerminalLine.Role) -> RestoredTerminalLine.Role {
        switch role {
        case .prompt:
            return .prompt
        case .stdout:
            return .stdout
        case .stderr:
            return .stderr
        case .system:
            return .system
        }
    }

    private func cliAgentIdentity(for session: TermySession) -> (kind: String, displayName: String)? {
        // Prefer the typed source of truth set at launch; the title is only a
        // display string and drifts with format/localization/renames.
        if let agent = session.agentType {
            return (agent.rawValue, agent.displayName)
        }
        // Fallback for sessions lacking a typed agentType (e.g. test-constructed).
        if session.title.localizedCaseInsensitiveContains(CLIAgent.codex.displayName) {
            return (CLIAgent.codex.rawValue, CLIAgent.codex.displayName)
        }
        if session.title.localizedCaseInsensitiveContains(CLIAgent.claudeCode.displayName) {
            return (CLIAgent.claudeCode.rawValue, CLIAgent.claudeCode.displayName)
        }
        return nil
    }

    private func apply(commandResult result: Result<ShellCommandResult, Error>, to sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else { return }

        switch result {
        case .success(let output):
            if !output.stdout.isEmpty {
                appendLine(TerminalLine(role: .stdout, text: output.stdout), to: sessionID)
            }
            if !output.stderr.isEmpty {
                appendLine(TerminalLine(role: .stderr, text: output.stderr), to: sessionID)
            }
            appendLine(TerminalLine(role: .system, text: "Exit \(output.exitCode)"), to: sessionID)
            statusMessage = output.exitCode == 0 ? "Command completed." : "Command failed with exit \(output.exitCode)."
        case .failure(let error):
            appendLine(TerminalLine(role: .stderr, text: error.localizedDescription), to: sessionID)
            statusMessage = "Command failed to launch."
        }
    }

    private func refreshGitBranches() {
        let repository = GitRepository(root: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        DispatchQueue.global(qos: .utility).async {
            let result = Result { (try repository.localBranches(), try? repository.currentBranch()) }
            DispatchQueue.main.async {
                if case .success(let (branches, currentBranch)) = result {
                    self.gitBranches = branches
                    if let currentBranch, !currentBranch.isEmpty {
                        self.selectedGitBranch = currentBranch
                    } else if self.selectedGitBranch == nil {
                        self.selectedGitBranch = branches.first
                    }
                }
            }
        }
    }

    private var projectRoot: URL {
        projectRootURL
    }

    private func localAIClient(endpoint: LocalAIEndpoint) -> LocalAIClient {
        LocalAIClient(endpoint: endpoint, model: aiModel, session: localAISession)
    }

    private func selectedEditorTextForAI() -> String? {
        guard editorVimEnabled,
              let selection = editorVimState.visualSelectionRange,
              selection.lowerBound < selection.upperBound else {
            return nil
        }
        let lowerBound = max(0, min(selection.lowerBound, scratchText.count))
        let upperBound = max(lowerBound, min(selection.upperBound, scratchText.count))
        let startIndex = scratchText.index(scratchText.startIndex, offsetBy: lowerBound)
        let endIndex = scratchText.index(scratchText.startIndex, offsetBy: upperBound)
        let selectedText = String(scratchText[startIndex..<endIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedText.isEmpty ? nil : selectedText
    }

    private func editorCompletionContext() -> (prefix: String, suffix: String) {
        let offset = editorInsertionOffset()
        let cursorIndex = scratchText.index(scratchText.startIndex, offsetBy: offset)
        return (String(scratchText[..<cursorIndex]), String(scratchText[cursorIndex...]))
    }

    private func editorInsertionOffset() -> Int {
        if editorVimEnabled {
            return min(max(0, editorVimState.cursorOffset), scratchText.count)
        }
        return scratchText.count
    }

    private var activePrivateSyncRecordNames: Set<String> {
        Set(workspaceStore.layouts.map { "workspace-\($0.id)" })
    }

    private var hasCloudKitPrivateSyncEntitlement: Bool {
        #if canImport(CloudKit)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.icloud-container-identifiers" as CFString,
                nil
              ) else {
            return false
        }
        return (value as? [String])?.contains("iCloud.pl.kacper.Termy") == true
        #else
        return false
        #endif
    }

    private func currentPrivateSyncTimestamp() -> Int {
        Int(Date().timeIntervalSince1970)
    }

    private func currentAIConversationHistory() -> [String] {
        var entries: [String] = []
        if let promptEntry = aiConversationEntry(label: "prompt", value: aiPrompt) {
            entries.append(promptEntry)
        }
        if let commandEntry = aiConversationEntry(label: "suggested-command", value: aiSuggestedCommand) {
            entries.append(commandEntry)
        }
        if let explanationEntry = aiConversationEntry(label: "explanation", value: aiExplanation) {
            entries.append(explanationEntry)
        }
        entries.append(contentsOf: aiConversationHistory)
        return deduplicatedAIConversationEntries(entries)
    }

    private func appendAIConversationHistoryEntry(_ entry: String, scheduleSync: Bool = true) {
        let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        aiConversationHistory.removeAll { $0 == trimmed }
        aiConversationHistory.append(trimmed)
        if aiConversationHistory.count > 100 {
            aiConversationHistory.removeFirst(aiConversationHistory.count - 100)
        }
        if scheduleSync {
            stagePrivateSyncSnapshot()
        }
    }

    private func aiConversationEntry(label: String, value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(label): \(trimmed)"
    }

    private func deduplicatedAIConversationEntries(_ entries: [String]) -> [String] {
        var seen: Set<String> = []
        return entries.filter { entry in
            if seen.contains(entry) {
                return false
            }
            seen.insert(entry)
            return true
        }
    }

    private func applyRestoredTerminalShell(_ shell: ShellLaunchProfile) {
        switch shell {
        case .zsh:
            terminalShellKind = "zsh"
            terminalCustomShellPath = "/bin/zsh"
            terminalCustomShellArguments = ""
        case .bash:
            terminalShellKind = "bash"
            terminalCustomShellPath = "/bin/bash"
            terminalCustomShellArguments = "--noprofile --norc"
        case .custom(let path, let arguments):
            terminalShellKind = "custom"
            terminalCustomShellPath = path
            terminalCustomShellArguments = arguments.joined(separator: " ")
        }
    }

    private func schedulePrivateSyncChangePush() {
        privateSyncDebounceTask?.cancel()
        let delaySeconds = privateSyncDebounceSeconds
        Task {
            _ = await runPrivateSyncEvent(.localChange)
        }
        privateSyncDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.runPrivateSyncEvent(.timer)
        }
    }

    private func startPrivateSyncEngineRuntime() {
        #if canImport(CloudKit)
        guard privateSyncEngineSession == nil else { return }
        guard #available(macOS 14.0, *) else { return }

        let delegate = CloudKitPrivateSyncEngineDelegate(
            recordsProvider: { [weak self] in
                await MainActor.run {
                    self?.privateSyncRecords ?? []
                }
            },
            pendingDeletionsProvider: { [weak self] in
                await MainActor.run {
                    Array(self?.pendingSyncDeletions ?? [])
                }
            },
            eventHandler: { [weak self] event in
                await self?.handlePrivateSyncEngineEvent(event)
            }
        )
        let database = CKContainer(identifier: "iCloud.pl.kacper.Termy").privateCloudDatabase
        privateSyncEngineSession = CloudKitPrivateSyncEngineSession(
            database: database,
            stateSerialization: nil,
            delegate: delegate
        )
        privateSyncStatus = "CKSyncEngine runtime ready"
        #endif
    }

    private func applyPrivateSyncEventStep(_ step: PrivateSyncAppEventStep) {
        privateSyncRecords = step.records
        privateSyncPendingOperations = step.eventLoopStep.pendingOperations
        privateSyncLastOperationResults = step.eventLoopStep.operationResults

        if let failedResult = step.eventLoopStep.operationResults.first(where: {
            if case .failed = $0.outcome { return true }
            return false
        }) {
            privateSyncStatus = "Sync failed"
            statusMessage = "Private sync \(formatPrivateSyncOperationKind(failedResult.operation.kind)) failed: \(failureMessage(failedResult.outcome))"
        } else if let savedRecordCount = step.savedRecordCount {
            // D2: a successful push has carried the tombstones; re-deleting would be
            // idempotent, but clear them so we don't resend indefinitely.
            pendingSyncDeletions.removeAll()
            privateSyncStatus = "Saved \(savedRecordCount) records"
            statusMessage = "Saved \(savedRecordCount) private CloudKit record(s) and ensured subscription."
        } else if let fetchedRecordCount = step.fetchedRecordCount {
            applyPrivateSyncRecordsToAppState()
            privateSyncStatus = "Fetched \(fetchedRecordCount) records"
            statusMessage = "Fetched \(fetchedRecordCount) private CloudKit record(s)."
        } else if let scheduledOperation = step.eventLoopStep.scheduledOperation {
            privateSyncStatus = "Sync scheduled"
            statusMessage = "Scheduled private sync \(formatPrivateSyncOperationKind(scheduledOperation.kind))."
        } else if privateSyncPendingOperations.isEmpty {
            privateSyncStatus = "Up to date"
        } else {
            privateSyncStatus = "\(privateSyncPendingOperations.count) sync operation(s) pending"
        }
    }

    private func applyPrivateSyncEngineRuntimeStep(_ step: PrivateSyncEngineRuntimeStep) {
        privateSyncChangeToken = step.changeToken
        privateSyncEngineAccountState = step.accountState

        if let appEventStep = step.appEventStep {
            applyPrivateSyncEventStep(appEventStep)
            privateSyncChangeToken = step.changeToken
            privateSyncEngineAccountState = step.accountState
            return
        }

        privateSyncRecords = step.records
        if step.appliedChangeCount > 0 {
            applyPrivateSyncRecordsToAppState()
            privateSyncStatus = "Applied \(step.appliedChangeCount) runtime change(s)"
            statusMessage = "Applied \(step.appliedChangeCount) CloudKit runtime change(s)."
        } else if let accountState = step.accountState {
            privateSyncStatus = formatPrivateSyncEngineAccountState(accountState)
            statusMessage = "CloudKit runtime account state: \(privateSyncStatus)."
        } else {
            privateSyncStatus = "Runtime event processed"
        }
    }

    private func failureMessage(_ outcome: PrivateSyncOperationOutcome) -> String {
        switch outcome {
        case .completed:
            return ""
        case .failed(let message):
            return message
        }
    }

    private func formatPrivateSyncOperationKind(_ kind: PrivateSyncOperationKind) -> String {
        switch kind {
        case .push:
            return "push"
        case .fetch:
            return "fetch"
        }
    }

    private func formatPrivateSyncEngineAccountState(_ state: PrivateSyncEngineAccountState) -> String {
        switch state {
        case .available:
            return "CloudKit runtime available"
        case .noAccount:
            return "No iCloud account"
        case .restricted:
            return "CloudKit restricted"
        case .unavailable:
            return "CloudKit runtime unavailable"
        }
    }

    private func format(_ status: GitStatus) -> String {
        guard !status.entries.isEmpty else {
            return "Working tree clean."
        }
        return status.entries
            .map { "\($0.code.padding(toLength: 2, withPad: " ", startingAt: 0)) \($0.path)" }
            .joined(separator: "\n")
    }

    private func selectFileTreeItem(offset: Int) {
        let items = visibleFileTreeItems.map(\.item.relativePath)
        guard !items.isEmpty else {
            selectedFilePath = nil
            return
        }

        guard let currentSelectedFilePath = selectedFilePath,
              let currentIndex = items.firstIndex(of: currentSelectedFilePath) else {
            selectedFilePath = offset < 0 ? items.last : items.first
            return
        }

        let nextIndex = (currentIndex + offset + items.count) % items.count
        selectedFilePath = items[nextIndex]
    }

    private func selectSFTPRemoteItem(offset: Int) {
        let items = filteredSFTPRemoteItems.map(\.path)
        guard !items.isEmpty else {
            selectedSFTPRemotePath = nil
            return
        }

        guard let selectedSFTPRemotePath,
              let currentIndex = items.firstIndex(of: selectedSFTPRemotePath) else {
            self.selectedSFTPRemotePath = offset < 0 ? items.last : items.first
            return
        }

        let nextIndex = (currentIndex + offset + items.count) % items.count
        self.selectedSFTPRemotePath = items[nextIndex]
    }

    private func mergePrivateSyncRecords(local: [PrivateSyncRecord], remote: [PrivateSyncRecord]) -> [PrivateSyncRecord] {
        PrivateSyncAppEventCoordinator.mergeRecords(
            local: local,
            remote: remote,
            activeLocalSessionRecordNames: activePrivateSyncRecordNames
        )
    }

    private func runSFTPBatch(
        _ batch: SFTPBatchCommand,
        profile: ConnectionProfile,
        successMessage: String,
        refreshLocalFiles: Bool = false,
        refreshRemoteFiles: Bool = false
    ) {
        do {
            let launch = try SFTPLaunchCommand(profile: profile)
            let batchURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("termy-sftp-batch-\(UUID().uuidString).txt")
            try batch.script.write(to: batchURL, atomically: true, encoding: .utf8)
            let command = ([launch.executablePath, "-b", batchURL.path] + launch.arguments)
                .map(shellQuote)
                .joined(separator: " ")
            let root = projectRoot

            DispatchQueue.global(qos: .userInitiated).async {
                defer { try? FileManager.default.removeItem(at: batchURL) }
                let result = Result { try ShellCommandRunner(workingDirectory: root).run(command) }
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.statusMessage = successMessage
                        if refreshLocalFiles {
                            self.refreshFiles()
                        }
                        if refreshRemoteFiles {
                            self.refreshSFTPFiles(profile: profile)
                        }
                    case .failure(let error):
                        self.statusMessage = "SFTP transfer failed: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            statusMessage = "SFTP transfer failed: \(error.localizedDescription)"
        }
    }

    private func formatCloudAccountStatus(_ status: PrivateSyncCloudAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Could not determine"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func tunnelName(profile: ConnectionProfile, spec: SSHTunnelSpec) -> String {
        switch spec {
        case .local(let localPort, let remoteHost, let remotePort):
            return "\(profile.name) L\(localPort)->\(remoteHost):\(remotePort)"
        case .remote(let remotePort, let localHost, let localPort):
            return "\(profile.name) R\(remotePort)->\(localHost):\(localPort)"
        case .dynamic(let localPort):
            return "\(profile.name) SOCKS \(localPort)"
        }
    }

    private func formatRDPRedirections(_ redirections: [RDPRedirection]) -> String {
        redirections.map { redirection in
            switch redirection {
            case .clipboard:
                return "clipboard"
            case .folderDrive(let path):
                return "folder drive \(path)"
            case .audioOutput:
                return "audio output"
            }
        }
        .joined(separator: ", ")
    }

    private func formatRDPSessionState(_ state: RDPSessionState) -> String {
        switch state {
        case .prepared:
            return "prepared"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .reconnecting(let attempt):
            return "reconnecting attempt \(attempt)"
        case .disconnected(let reason):
            return "disconnected (\(formatRDPDisconnectReason(reason)))"
        case .failed(let reason):
            return "failed (\(formatRDPDisconnectReason(reason)))"
        }
    }

    private func formatRDPDisconnectReason(_ reason: RDPDisconnectReason) -> String {
        switch reason {
        case .userInitiated:
            return "user initiated"
        case .networkFailure:
            return "network failure"
        case .transportError(let status):
            return "transport error \(status)"
        }
    }

    private func transcriptRole(for role: TerminalLine.Role) -> TerminalTranscriptRole {
        switch role {
        case .prompt:
            return .prompt
        case .stdout, .stderr:
            return .output
        case .system:
            return .system
        }
    }

    private func addSession(profile: ConnectionProfile) {
        let interactionMode: TermySession.InteractionMode = profile.kind == .local ? .rawPTY : .commandLine
        let session = TermySession(
            title: profile.name,
            profile: profile,
            lines: [
                TerminalLine(role: .system, text: "\(profile.name) created.")
            ],
            interactionMode: interactionMode
        )
        sessions.append(session)
        selectedSessionID = session.id
        if profile.kind == .local {
            startPTY(for: session.id)
        }
    }

    /// Close the session with the given ID, freeing all per-session
    /// bookkeeping (resolves the registry-clear TODO at line 544). A no-op
    /// for unknown IDs.
    ///
    /// The live PTY is owned by `terminalSurfacePool`; this method terminates it
    /// explicitly (Slice 5) — `dismantleNSView` only detaches the view now.
    ///
    /// RDP teardown mirrors `failLiveRDPConnection` (stop the live session,
    /// cancel an in-flight connect task, drop the router).
    func closeSession(sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        cleanupAgentWorktreeIfNeeded(for: sessionID)

        let wasSelected = selectedSessionID == sessionID

        // Stop the live RDP transport for this session (mirrors
        // failLiveRDPConnection). The PTY is reaped explicitly below via
        // terminalSurfacePool.terminate (Slice 5) — dismantleNSView only detaches.
        rdpSessions[sessionID]?.stop()
        rdpSessions[sessionID] = nil
        rdpConnectionTasks[sessionID]?.cancel()
        rdpConnectionTasks[sessionID] = nil
        rdpRouters[sessionID] = nil

        // Slice 5: the PTY is no longer reaped by dismantleNSView — terminate the
        // pooled surface here, BEFORE clearing the generation registry below
        // (so a re-mount can't compute a stale key mid-teardown).
        terminalSurfacePool.terminate(forSession: sessionID)

        // Clear per-session bookkeeping (the 7 registries enumerated by the
        // resolved TODO at line 544).
        terminalLaunchDescriptors[sessionID] = nil
        terminalLaunchGenerations[sessionID] = nil
        terminalScreenTextProviders[sessionID] = nil
        tunnelReconnectContexts[sessionID] = nil
        tunnelReconnectAttempts[sessionID] = nil
        terminalInputBuffers[sessionID] = nil
        terminalInputHighlights[sessionID] = nil
        terminalCaretOriginProviders[sessionID] = nil
        terminalInputSinks[sessionID] = nil

        // F-4: tear down per-session sidecar.
        sidecarDebounceTasks[sessionID]?.cancel()
        sidecarDebounceTasks.removeValue(forKey: sessionID)
        if let sidecar = completionSidecars.removeValue(forKey: sessionID) {
            Task { await sidecar.terminate() }
        }
        completionSidecarTokens.removeValue(forKey: sessionID)
        sidecarLastAppliedId.removeValue(forKey: sessionID)
        sidecarLastCandidates.removeValue(forKey: sessionID)
        sidecarDebounceElapsed.remove(sessionID)
        sidecarGhosts.removeValue(forKey: sessionID)
        sidecarDisabledSessions.remove(sessionID)

        // v3 block terminal: clear per-command timing state.
        commandStartTimes[sessionID] = nil
        commandDurations[sessionID] = nil
        pendingCommandPromptIndex[sessionID] = nil
        terminalLocalClearSinks[sessionID] = nil
        terminalAltScreen[sessionID] = nil

        // FB-3-2: tear down per-session agent state.
        agentQuiescenceTasks[sessionID]?.cancel()
        agentQuiescenceTasks.removeValue(forKey: sessionID)
        agentStateMachines.removeValue(forKey: sessionID)
        agentProgress.removeValue(forKey: sessionID)
        try? FileManager.default.removeItem(
            at: agentStateRoot.appendingPathComponent("\(sessionID.uuidString).state"))

        // Remove the session and advance selection to the previous sibling
        // (or nil when the array is now empty).
        sessions.remove(at: index)
        if wasSelected {
            if sessions.isEmpty {
                selectedSessionID = nil
            } else {
                selectedSessionID = sessions[max(0, index - 1)].id
            }
        }
    }

    private func startSavedTunnel(_ tunnel: SavedSSHTunnel, profile: ConnectionProfile, sessionID: UUID? = nil) {
        do {
            let command = try tunnel.launchCommand(profile: profile)
            tunnelHealth[tunnel.id] = SSHTunnelHealth(tunnelName: tunnel.name)
            let session: TermySession
            if let sessionID, let index = sessions.firstIndex(where: { $0.id == sessionID }) {
                session = sessions[index]
                appendLine(TerminalLine(role: .system, text: "Reconnecting SSH tunnel \(tunnel.name)."), to: sessionID)
            } else {
                session = TermySession(
                    title: "\(tunnel.name) Tunnel",
                    profile: profile,
                    lines: [
                        TerminalLine(role: .system, text: "Starting local tunnel via \(command.executablePath) \(command.arguments.joined(separator: " "))"),
                        TerminalLine(role: .system, text: tunnel.autoReconnect ? "Auto-reconnect enabled." : "Auto-reconnect disabled."),
                        TerminalLine(role: .system, text: "Tunnel uses system SSH and existing Keychain/ssh-agent credentials.")
                    ],
                    interactionMode: .rawPTY
                )
                sessions.append(session)
                selectedSessionID = session.id
            }

            let descriptor = TerminalLaunchDescriptor(
                executable: command.executablePath,
                arguments: command.arguments,
                environment: sshEnvironment(),
                workingDirectory: projectRoot.path,
                usesZshIntegration: false)
            registerTerminalLaunch(descriptor, for: session.id)
            registerTunnelReconnectContext(tunnel: tunnel, profile: profile, for: session.id)
            if sessionID != nil { bumpTerminalLaunchGeneration(for: session.id) }
            markTunnelRunning(tunnel)
            statusMessage = "SSH tunnel started."
        } catch {
            markTunnelFailed(tunnel, status: -1)
            statusMessage = "SSH tunnel failed: \(error.localizedDescription)"
        }
    }

    /// Reconnect-only: the exit line/lastExitCode were already surfaced by
    /// `noteSessionProcessExited` (which dispatches here). Must NOT call
    /// `noteSessionProcessExited` again (double-append / recursion).
    private func handleTunnelReconnect(
        status: Int32,
        tunnel: SavedSSHTunnel,
        profile: ConnectionProfile,
        sessionID: UUID
    ) {
        let attempts = tunnelReconnectAttempts[sessionID, default: 0]
        let policy = SSHTunnelReconnectPolicy()
        let willReconnect = policy.shouldReconnect(
            exitStatus: status,
            completedAttempts: attempts,
            autoReconnect: tunnel.autoReconnect
        )
        markTunnelExited(tunnel, status: status, willReconnect: willReconnect)

        guard willReconnect else {
            tunnelReconnectAttempts[sessionID] = nil
            clearTunnelReconnectContext(for: sessionID)
            return
        }

        tunnelReconnectAttempts[sessionID] = attempts + 1
        markTunnelReconnecting(tunnel, attempt: attempts + 1)
        appendLine(
            TerminalLine(role: .system, text: "Auto-reconnect attempt \(attempts + 1) for \(tunnel.name)."),
            to: sessionID
        )
        startSavedTunnel(tunnel, profile: profile, sessionID: sessionID)
    }

    private func markTunnelRunning(_ tunnel: SavedSSHTunnel) {
        var health = tunnelHealth[tunnel.id] ?? SSHTunnelHealth(tunnelName: tunnel.name)
        health.markRunning()
        tunnelHealth[tunnel.id] = health
    }

    private func markTunnelReconnecting(_ tunnel: SavedSSHTunnel, attempt: Int) {
        var health = tunnelHealth[tunnel.id] ?? SSHTunnelHealth(tunnelName: tunnel.name)
        health.markReconnecting(attempt: attempt)
        tunnelHealth[tunnel.id] = health
    }

    private func markTunnelExited(_ tunnel: SavedSSHTunnel, status: Int32, willReconnect: Bool) {
        var health = tunnelHealth[tunnel.id] ?? SSHTunnelHealth(tunnelName: tunnel.name)
        health.markExited(status: status, willReconnect: willReconnect)
        tunnelHealth[tunnel.id] = health
    }

    private func markTunnelFailed(_ tunnel: SavedSSHTunnel, status: Int32) {
        var health = tunnelHealth[tunnel.id] ?? SSHTunnelHealth(tunnelName: tunnel.name)
        health.markExited(status: status, willReconnect: false)
        tunnelHealth[tunnel.id] = health
    }

    private func addRemotePreview(kind: ConnectionKind) {
        guard let profile = profiles.first(where: { $0.kind == kind }) else { return }
        let session = TermySession(
            title: profile.name,
            profile: profile,
            lines: [
                TerminalLine(role: .system, text: "\(profile.kind.rawValue.uppercased()) profile selected."),
                TerminalLine(role: .system, text: "Secrets are referenced by Keychain item only; no inline credentials are stored.")
            ]
        )
        sessions.append(session)
        selectedSessionID = session.id
    }

    private func openSSHConnection(_ profile: ConnectionProfile) {
        do {
            let command = try SSHLaunchCommand(profile: profile)
            let session = TermySession(
                title: profile.name,
                profile: profile,
                lines: [
                    TerminalLine(role: .system, text: "Starting SSH via \(command.executablePath) \(command.arguments.joined(separator: " "))"),
                    TerminalLine(role: .system, text: "Secrets remain in Keychain or ssh-agent; Termy did not inline credentials.")
                ],
                interactionMode: .rawPTY
            )
            sessions.append(session)
            selectedSessionID = session.id

            let descriptor = TerminalLaunchDescriptor(
                executable: command.executablePath,
                arguments: command.arguments,
                environment: sshEnvironment(),
                workingDirectory: projectRoot.path,
                usesZshIntegration: false)
            registerTerminalLaunch(descriptor, for: session.id)
            statusMessage = "SSH session started."
        } catch {
            statusMessage = "SSH session failed: \(error.localizedDescription)"
        }
    }

    private func launchToolSession(title: String, executablePath: String, arguments: [String], startMessage: String) {
        let profile = ConnectionProfile.local(name: title)
        let session = TermySession(
            title: title,
            profile: profile,
            lines: [
                TerminalLine(role: .system, text: startMessage),
                TerminalLine(role: .system, text: "\(executablePath) \(arguments.joined(separator: " "))")
            ],
            interactionMode: .rawPTY
        )
        sessions.append(session)
        selectedSessionID = session.id

        let descriptor = TerminalLaunchDescriptor(
            executable: executablePath,
            arguments: arguments,
            environment: sshEnvironment(),
            workingDirectory: projectRoot.path,
            usesZshIntegration: false)
        registerTerminalLaunch(descriptor, for: session.id)
        statusMessage = "\(title) started."
    }

    private func startLiveRDPConnection(sessionID: UUID, descriptor: RDPSessionDescriptor) {
        rdpConnectionTasks[sessionID]?.cancel()
        appendLine(
            TerminalLine(role: .system, text: "Starting live RDP transport to \(descriptor.host):3389."),
            to: sessionID
        )
        let connect = rdpConnect
        // Bridges events from the FreeRDPSession's off-main pump thread back
        // to the main actor and through the existing router. Capturing
        // `self` weakly avoids a retain cycle (we own the session); the
        // pump callback is `@Sendable`.
        let dispatch: @Sendable (UUID, RDPTransportEvent) -> Void = { [weak self] sessionID, event in
            Task { @MainActor in
                _ = self?.handleRDPTransportEvent(event, for: sessionID)
            }
        }
        rdpConnectionTasks[sessionID] = Task { [weak self] in
            do {
                // R2: the FreeRDP handshake (`start` → `ctermyrdp_connect`) is a
                // blocking TLS/CredSSP exchange or a multi-second TCP timeout on
                // an unreachable host. Run BOTH the session construction AND
                // `start()` off the main actor so a slow host can never freeze the
                // UI; the event pump already lives on FreeRDPSession's own queue.
                let freerdp = try await Task.detached(priority: .userInitiated) { () -> FreeRDPSession in
                    let session = try await connect(descriptor)
                    do {
                        try session.start { event in dispatch(sessionID, event) }
                    } catch {
                        // Never leak a partially-constructed session/connection.
                        session.stop()
                        throw error
                    }
                    return session
                }.value
                await MainActor.run {
                    self?.activateLiveRDPConnection(freerdp, for: sessionID)
                }
            } catch {
                await MainActor.run {
                    self?.failLiveRDPConnection(error, for: sessionID)
                }
            }
        }
    }

    private func activateLiveRDPConnection(_ freerdp: FreeRDPSession, for sessionID: UUID) {
        // S2: the connect + handshake ran off-main, so the user may have closed
        // the session during that window. `closeSession` cancels our task and
        // removes the session, but it cannot reach `freerdp` — a task-local until
        // this line — so without this guard the off-main pump thread AND the live
        // outbound RDP connection would leak (privacy: an unwanted connection
        // stays up). If the session is gone, tear the transport down and bail.
        guard sessions.contains(where: { $0.id == sessionID }) else {
            freerdp.stop()
            rdpConnectionTasks[sessionID] = nil
            return
        }
        rdpSessions[sessionID] = freerdp
        rdpConnectionTasks[sessionID] = nil
        // Mark the router as connected so the lifecycle transitions out of
        // `.connecting` — the FreeRDP pump produces no synthetic "connected"
        // event (it implicitly signals success by the start() call returning
        // without throwing); the bespoke `.connected` step had to be
        // synthesised by the bootstrap, here we synthesise it ourselves.
        if var router = rdpRouters[sessionID] {
            router.markConnected()
            rdpRouters[sessionID] = router
        }
        appendLine(
            TerminalLine(
                role: .system,
                text: "RDP transport connected via FreeRDP 3.26.0."
            ),
            to: sessionID
        )
        statusMessage = "RDP session connected."
    }

    private func failLiveRDPConnection(_ error: Error, for sessionID: UUID) {
        // S2 (symmetry): if the session was closed during the off-main connect
        // window, closeSession already tore everything down — don't write a stray
        // status/line for a session the user dropped.
        guard sessions.contains(where: { $0.id == sessionID }) else {
            rdpConnectionTasks[sessionID] = nil
            return
        }
        rdpSessions[sessionID]?.stop()
        rdpSessions[sessionID] = nil
        rdpConnectionTasks[sessionID] = nil
        if var router = rdpRouters[sessionID] {
            _ = try? router.handle(
                .disconnected(.networkFailure),
                writeClipboard: { _ in },
                playAudio: { _ in }
            )
            rdpRouters[sessionID] = router
        }
        appendLine(
            TerminalLine(role: .stderr, text: "RDP connection failed: \(error.localizedDescription)"),
            to: sessionID
        )
        statusMessage = "RDP session failed: \(error.localizedDescription)"
    }

    private func toggle(_ panel: OverlayPanel) {
        activePanel = activePanel == panel ? nil : panel
    }

    private func tile(_ pane: WorkspacePaneKind, edge: WorkspaceSplitEdge) {
        paneLayout.split(pane, edge: edge)
        activePanel = nil
        statusMessage = "Tiled \(pane.rawValue) pane."
    }

    @discardableResult
    private func persistSelectedWorkspacePaneTree() -> Bool {
        guard let selectedWorkspaceID,
              let layout = workspaceStore.restore(id: selectedWorkspaceID) else {
            return false
        }
        workspaceStore.save(WorkspaceLayout(
            id: layout.id,
            name: layout.name,
            sessionProfileIDs: layout.sessionProfileIDs,
            activeSessionProfileID: layout.activeSessionProfileID,
            panelIDs: paneLayout.visiblePanes.map(\.rawValue),
            splitRatio: layout.splitRatio,
            paneTree: paneLayout.paneTree
        ))
        return true
    }

    private func overlayPanel(for pane: WorkspacePaneKind?) -> OverlayPanel? {
        switch pane {
        case .ai:
            return .ai
        case .files:
            return .files
        case .git:
            return .git
        case .editor:
            return .editor
        case .terminal, .rdp, nil:
            return nil
        }
    }

    /// FB-1: builds the local-zsh launch descriptor with shell-syntax-highlighting wiring.
    /// Spec-HL: also threads `specDir` + `SpecHighlightPalette.default` styles block.
    /// Extracted so the theme->styles + resource-dir env mapping is unit-testable without
    /// spawning a PTY.
    func localZshLaunchDescriptor(
        executable: String,
        arguments: [String],
        baseEnvironment: [String: String],
        theme: TerminalTheme,
        syntaxHighlightDir: String?,
        specDir: String? = nil,
        usesZshIntegration: Bool
    ) -> TerminalLaunchDescriptor {
        var environment = baseEnvironment
        environment["TERM"] = "xterm-256color"
        var styles: [String] = []
        var specStylesBlock = ""
        if usesZshIntegration {
            styles = SyntaxHighlightStyleMap.styles(for: theme)
            if let dir = syntaxHighlightDir {
                environment["TERMY_SYNTAX_HL_DIR"] = dir
            }
            // $TERMY_SPEC_DIR is carried env-only (mirrors TERMY_SYNTAX_HL_DIR). The palette
            // block is emitted only when the dir resolved — without the dir the highlighter
            // file is never sourced, so TERMY_SPEC_STYLES would be dead.
            if let dir = specDir {
                environment["TERMY_SPEC_DIR"] = dir
                specStylesBlock = SpecHighlightPalette.default.zshStylesBlock()
            }
        }
        return TerminalLaunchDescriptor(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: nil,
            usesZshIntegration: usesZshIntegration,
            highlightStyles: styles,
            specStylesBlock: specStylesBlock)
    }

    private func startPTY(for sessionID: UUID) {
        let hadDescriptor = terminalLaunchDescriptor(for: sessionID) != nil
        guard !hadDescriptor else { return }
        let shellCommand = terminalShellProfile.command
        let hlDir = Bundle.main.resourceURL?
            .appendingPathComponent("zsh-syntax-highlighting", isDirectory: true).path
        let specDir = Bundle.main.resourceURL?
            .appendingPathComponent("specs", isDirectory: true).path
        let descriptor = localZshLaunchDescriptor(
            executable: shellCommand.shellPath,
            arguments: shellCommand.arguments,
            baseEnvironment: ProcessInfo.processInfo.environment,
            theme: terminalTheme,
            syntaxHighlightDir: hlDir,
            specDir: specDir,
            usesZshIntegration: terminalShellProfile.usesZshIntegration)
        registerTerminalLaunch(descriptor, for: sessionID)
        appendLine(
            TerminalLine(role: .system,
                text: "Native PTY attached with \(shellCommand.shellPath) \(shellCommand.arguments.joined(separator: " "))."),
            to: sessionID)
        // F-4: spawn sidecar for local PTY sessions.
        spawnSidecar(for: sessionID, shellPath: shellCommand.shellPath)
        // v3 Shell §6.1: probe shell version once per shell path (idempotent).
        warmShellVersionIfNeeded(forShellPath: shellCommand.shellPath)
    }

    private func spawnSidecar(for sessionID: UUID, shellPath: String) {
        let workDir = makeSidecarWorkDir(sessionID: sessionID)
        let token = UUID()
        let cwd = sessions.first(where: { $0.id == sessionID })?.currentWorkingDirectory ?? FileManager.default.currentDirectoryPath
        let sidecar = try? CompletionSidecar.spawn(
            shellPath: shellPath,
            zdotdir: nil,
            extraEnvironment: [:],
            cwd: cwd,
            workDir: workDir,
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.applySidecarEvent(event, sessionID: sessionID, sidecarToken: token)
                }
            },
            onStateChange: { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.applySidecarStateChange(state, sessionID: sessionID, sidecarToken: token)
                }
            }
        )
        if let sidecar {
            completionSidecars[sessionID] = sidecar
            completionSidecarTokens[sessionID] = token
            // Handle the immediately-disabled case: makeImmediatelyDisabled sets
            // initialState: .disabled but setState won't fire on init. Check the
            // initial state synchronously (actor isolation is separate — use Task).
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.isCurrentSidecarToken(token, for: sessionID) else { return }
                let initialState = await sidecar.state
                if initialState == .disabled {
                    self.sidecarDisabledSessions.insert(sessionID)
                }
            }
        }
    }

    @MainActor
    private func applySidecarStateChange(
        _ state: CompletionSidecar.State,
        sessionID: UUID,
        sidecarToken: UUID? = nil
    ) {
        guard isCurrentSidecarToken(sidecarToken, for: sessionID) else { return }
        if state == .disabled {
            sidecarDisabledSessions.insert(sessionID)
        } else {
            sidecarDisabledSessions.remove(sessionID)
        }
    }

    static func sidecarWorkDirParent() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Termy/Sidecar")
    }

    private func makeSidecarWorkDir(sessionID: UUID) -> URL {
        let base = Self.sidecarWorkDirParent()
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    @MainActor
    private func applySidecarEvent(
        _ event: CompletionSidecarResultWatcher.Event,
        sessionID: UUID,
        sidecarToken: UUID? = nil
    ) {
        guard isCurrentSidecarToken(sidecarToken, for: sessionID) else { return }
        switch event {
        case .boot:
            Task { @MainActor in refreshSidecarDisabled(sessionID: sessionID) }
        case .result(let id, let items):
            applyCompletionResponse(sessionID: sessionID, id: id, items: items)
        case .error(let id, _):
            applyCompletionResponse(sessionID: sessionID, id: id, items: [])
        }
    }

    private func isCurrentSidecarToken(_ token: UUID?, for sessionID: UUID) -> Bool {
        guard let token else { return true }
        return completionSidecarTokens[sessionID] == token
    }

    private func applyCompletionResponse(sessionID: UUID, id: Int, items: [CompletionCandidate]) {
        let last = sidecarLastAppliedId[sessionID] ?? -1
        guard id >= last else { return }   // stale; drop
        sidecarLastAppliedId[sessionID] = id

        // Always cache the latest items so recomputeSidecarGhost has them even
        // when the menu is closed (debounce not yet elapsed).
        sidecarLastCandidates[sessionID] = items

        if items.isEmpty {
            // Zero items: close menu if open.
            if terminalMenuStates[sessionID] != nil {
                terminalMenuStates[sessionID] = nil
                objectWillChange.send()
            }
        } else {
            let debounceReady = sidecarDebounceElapsed.contains(sessionID)
            if let prev = terminalMenuStates[sessionID] {
                // Refresh an already-open menu.
                let clamped = max(0, min(prev.selection, items.count - 1))
                terminalMenuStates[sessionID] = MenuState(items: items, selection: clamped)
                objectWillChange.send()
            } else if debounceReady {
                // Auto-open when debounce elapsed.
                terminalMenuStates[sessionID] = MenuState(items: items, selection: 0)
                objectWillChange.send()
            }
            // If debounce not yet elapsed, items cached above; menu opens on next debounce.
        }
        recomputeSidecarGhost(sessionID: sessionID)
    }

    private func scheduleSidecarQuery(sessionID: UUID, buffer: String, cursor: Int) {
        sidecarDebounceTasks[sessionID]?.cancel()
        sidecarDebounceElapsed.remove(sessionID)
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: TermyStore.sidecarDebounceNs)
            if Task.isCancelled { return }
            guard let self else { return }
            self.fireSidecarQuery(sessionID: sessionID, buffer: buffer, cursor: cursor)
        }
        sidecarDebounceTasks[sessionID] = task
    }

    @MainActor
    private func fireSidecarQuery(sessionID: UUID, buffer: String, cursor: Int) {
        sidecarDebounceElapsed.insert(sessionID)
        guard let sidecar = completionSidecars[sessionID] else { return }
        let cwd = sessions.first(where: { $0.id == sessionID })?.currentWorkingDirectory ?? "/"
        Task { await sidecar.query(buffer: buffer, cursor: cursor, cwd: cwd) }
    }

    private func recomputeSidecarGhost(sessionID: UUID) {
        // History ghost takes priority.
        let historyGhost = terminalInlineSuggestionSuffix(for: sessionID)
        if historyGhost != nil {
            sidecarGhosts[sessionID] = nil
            return
        }
        // Menu open suppresses ghost.
        if terminalMenuStates[sessionID] != nil {
            sidecarGhosts[sessionID] = nil
            return
        }
        let items = sidecarLastItems(sessionID: sessionID)
        guard let top = items.first else {
            sidecarGhosts[sessionID] = nil
            return
        }
        let lastBuffer = terminalInputBuffers[sessionID]?.text ?? ""
        let tokenPrefix = lastBuffer.split(separator: " ").last.map(String.init) ?? ""
        if top.replacement.hasPrefix(tokenPrefix) {
            let suffix = String(top.replacement.dropFirst(tokenPrefix.count))
            sidecarGhosts[sessionID] = suffix.isEmpty ? nil : suffix
        } else {
            sidecarGhosts[sessionID] = nil
        }
    }

    /// Last known sidecar candidates for a session (from the cache, independent
    /// of menu open/closed state).
    private func sidecarLastItems(sessionID: UUID) -> [CompletionCandidate] {
        sidecarLastCandidates[sessionID] ?? []
    }

    func terminalSidecarGhost(for sessionID: UUID) -> String? {
        sidecarGhosts[sessionID]
    }

    @MainActor
    private func refreshSidecarDisabled(sessionID: UUID) {
        guard let sidecar = completionSidecars[sessionID] else {
            sidecarDisabledSessions.remove(sessionID)
            return
        }
        Task { @MainActor in
            let st = await sidecar.state
            if st == .disabled {
                sidecarDisabledSessions.insert(sessionID)
            } else {
                sidecarDisabledSessions.remove(sessionID)
            }
        }
    }

    private func sshEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        return environment
    }

    private func sshKeyURL() -> URL {
        URL(fileURLWithPath: (sshKeyPath as NSString).expandingTildeInPath)
    }

    private func appendLine(_ line: TerminalLine, to sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].lines.append(line)
        trimTerminalTranscriptIfNeeded(at: index)
        if sessionID == selectedSessionID {
            refreshTerminalIndex()
        }
    }

    private func trimTerminalTranscriptIfNeeded(at index: Int) {
        let overflow = sessions[index].lines.count - Self.maxTerminalTranscriptLines
        guard overflow > 0 else { return }

        let sessionID = sessions[index].id
        sessions[index].lines.removeFirst(overflow)

        // v3 block terminal: the timing registries are line-index-keyed for THIS
        // session regardless of selection, so remap them for any trimmed session
        // (before the selected-only block below). Same shift-and-drop semantics
        // as selectedTerminalBlockStartLine / foldedTerminalBlockStartLines.
        if let starts = commandStartTimes[sessionID] {
            commandStartTimes[sessionID] = Self.shiftLineKeys(starts, by: overflow)
        }
        if let durations = commandDurations[sessionID] {
            commandDurations[sessionID] = Self.shiftLineKeys(durations, by: overflow)
        }
        if let pending = pendingCommandPromptIndex[sessionID] {
            pendingCommandPromptIndex[sessionID] = pending >= overflow ? pending - overflow : nil
        }

        guard sessionID == selectedSessionID else { return }
        if let selectedTerminalBlockStartLine {
            self.selectedTerminalBlockStartLine = selectedTerminalBlockStartLine >= overflow
                ? selectedTerminalBlockStartLine - overflow
                : nil
        }
        foldedTerminalBlockStartLines = Set(
            foldedTerminalBlockStartLines.compactMap { line in
                line >= overflow ? line - overflow : nil
            }
        )
    }

    private func applyShellIntegration(events: [ShellIntegrationEvent], to sessionID: UUID) {
        if !events.isEmpty,
           sessions.first(where: { $0.id == sessionID })?.agentType != nil {
            noteAgentActivity(for: sessionID)
        }
        for event in events {
            switch event {
            case .output(let text):
                appendLine(TerminalLine(role: .stdout, text: text), to: sessionID)
            case .commandStarted(let command):
                appendLine(TerminalLine(role: .prompt, text: "$ \(command)"), to: sessionID)
                // v3 block terminal: record the prompt line index as timing key.
                // The prompt was just appended, so it's the last line in the session.
                if let si = sessions.firstIndex(where: { $0.id == sessionID }) {
                    let promptIndex = sessions[si].lines.count - 1
                    pendingCommandPromptIndex[sessionID] = promptIndex
                    commandStartTimes[sessionID, default: [:]][promptIndex] = Date()
                }
                statusMessage = "Running \(command)"
                // F-2: history is now the persistent HistoryStore; cwd is the
                // session's currentWorkingDirectory at command-start time (last
                // D mark, or the descriptor seed for the first command).
                let cwd = sessions.first(where: { $0.id == sessionID })?.currentWorkingDirectory
                historyStore.record(command: command, cwd: cwd)
                commandActivityLog.record(at: Date())
                objectWillChange.send()
                terminalInputBuffers[sessionID] = nil   // F-1: drop pending suggestion
                terminalInputHighlights[sessionID] = nil // FB-1: drop live highlight spans
                // F-3: a command starting means the user accepted (Enter at prompt) —
                // any open menu is now stale; close it defensively.
                terminalMenuStates[sessionID] = nil
                // F-4: clear sidecar caches so stale ghosts don't survive the
                // prompt-to-prompt transition.
                sidecarLastCandidates.removeValue(forKey: sessionID)
                sidecarGhosts.removeValue(forKey: sessionID)
                sidecarDebounceElapsed.remove(sessionID)
                sidecarDebounceTasks[sessionID]?.cancel()
                sidecarDebounceTasks.removeValue(forKey: sessionID)
            case .commandFinished(let exitCode, let workingDirectory):
                guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
                sessions[index].lastExitCode = exitCode
                sessions[index].currentWorkingDirectory = workingDirectory
                // v3 block terminal: finalize duration for the pending prompt index.
                if let promptIndex = pendingCommandPromptIndex[sessionID],
                   let start = commandStartTimes[sessionID]?[promptIndex] {
                    commandDurations[sessionID, default: [:]][promptIndex] = Date().timeIntervalSince(start)
                    // Prune the now-sealed start time (bounds memory, shrinks the
                    // trim-remap surface — only commandDurations needs to survive).
                    commandStartTimes[sessionID]?[promptIndex] = nil
                    pendingCommandPromptIndex[sessionID] = nil
                }
                appendLine(TerminalLine(role: .system, text: "Exit \(exitCode)"), to: sessionID)
                statusMessage = exitCode == 0 ? "Command completed." : "Command failed with exit \(exitCode)."
                // v3 block terminal: clear the live SwiftTerm VIEW (not the PTY) so it
                // shows only the next prompt — this finished command is now a frozen
                // card above. Selected, local, non-agent rawPTY, blocks-mode only.
                if sessionID == selectedSessionID,
                   selectedTerminalOutputModeValue == .blocks,
                   sessions[index].agentType == nil,
                   sessions[index].interactionMode == .rawPTY {
                    terminalLocalClearSinks[sessionID]?()
                }
                // F-4: propagate cwd to sidecar.
                if let cwd = workingDirectory, let sidecar = completionSidecars[sessionID] {
                    Task { await sidecar.notifyCwd(cwd) }
                }
            case .inputBufferChanged(let text, let cursor, let length):
                // F-1: set buffer state only. The view refresh is pushed by
                // `terminalRenderChanged` from SwiftTerm's post-render
                // `rangeChanged`, so the overlay re-reads `caretFrame` after
                // SwiftTerm updated it (no pull-side render-cycle staleness).
                // Ordering invariant: the keystroke echo and its OSC `T`
                // normally co-arrive in one `dataReceived` chunk, so this
                // buffer set runs before SwiftTerm's render → `rangeChanged`.
                // If the PTY ever splits them, the worst case is one
                // `rangeChanged` with the prior buffer (sub-tick, coalesced
                // by SwiftUI) — self-correcting, never wrong-then-stuck.
                terminalInputBuffers[sessionID] = (text, cursor, length)
                // F-4: debounced sidecar query for .rawPTY sessions with a live sidecar.
                // Engine live-narrow is skipped when a sidecar is driving results.
                if completionSidecars[sessionID] != nil {
                    scheduleSidecarQuery(sessionID: sessionID, buffer: text, cursor: cursor)
                } else {
                    // F-3: live narrow — when the menu is open, recompute items for
                    // the new buffer; if 0, close. Selection is clamped to the new
                    // count (preserving index when in range).
                    if let prev = terminalMenuStates[sessionID] {
                        let fresh = completionSuggestionsForMenu(text: text, sessionID: sessionID)
                        if fresh.isEmpty {
                            terminalMenuStates[sessionID] = nil
                        } else {
                            let clamped = max(0, min(prev.selection, fresh.count - 1))
                            terminalMenuStates[sessionID] = MenuState(items: fresh, selection: clamped)
                        }
                        objectWillChange.send()
                    }
                }
            case .inputHighlightsChanged(let spans):
                // FB-1: store the live-input highlight spans for the live block.
                terminalInputHighlights[sessionID] = spans
                objectWillChange.send()
            }
        }
    }

    /// M3-2 live-path entry point: the SwiftTerm byte-tap (SwiftTermStreamBridge
    /// -> ShellIntegrationParser) calls this with already-parsed events; this
    /// is the sole shell-integration ingest path. Reuses the unchanged
    /// applyShellIntegration/appendLine seam.
    func ingestShellIntegrationEvents(_ events: [ShellIntegrationEvent], for sessionID: UUID) {
        applyShellIntegration(events: events, to: sessionID)
    }

    /// Per-session launch registry: the five PTY launch sites hand the
    /// SwiftTerm-owned view a `TerminalLaunchDescriptor` (+ a relaunch
    /// generation, bumped on tunnel reconnect so the view restarts).
    func initialTerminalTranscriptReplay(for id: UUID) -> String? {
        terminalInitialTranscriptReplays[id]
    }
    func clearInitialTerminalTranscriptReplay(for id: UUID) {
        terminalInitialTranscriptReplays[id] = nil
    }
    func terminalLaunchDescriptor(for id: UUID) -> TerminalLaunchDescriptor? {
        terminalLaunchDescriptors[id]
    }
    func terminalLaunchGeneration(for id: UUID) -> Int {
        terminalLaunchGenerations[id] ?? 0
    }
    func registerTerminalLaunch(_ descriptor: TerminalLaunchDescriptor, for id: UUID) {
        terminalLaunchDescriptors[id] = descriptor
        if terminalLaunchGenerations[id] == nil {
            terminalLaunchGenerations[id] = 0
        }
        // F-2: seed currentWorkingDirectory so the first command in this
        // session has a non-nil cwd before any OSC 133 D mark arrives.
        // OSC 133 A is intentionally NOT consumed (parser §17), so this is
        // the only pre-D opportunity to know the launch directory. If the
        // descriptor's workingDirectory is nil (e.g. local zsh inheriting
        // FileManager.currentDirectoryPath), the session's cwd stays nil
        // and HistoryStore.record(cwd: nil) records without cwd until D fires.
        if let index = sessions.firstIndex(where: { $0.id == id }),
           sessions[index].currentWorkingDirectory == nil {
            sessions[index].currentWorkingDirectory = descriptor.workingDirectory
        }
    }
    func bumpTerminalLaunchGeneration(for id: UUID) {
        terminalLaunchGenerations[id, default: 0] += 1
    }

    /// SwiftTerm-owned screen text for the "Copy Visible Terminal Screen"
    /// command (read from SwiftTerm's own render state via the screen-text
    /// provider). The provider weak-captures the SwiftTerm view, so a stale
    /// entry for a dismantled view safely returns "" (copyVisibleTerminalScreen
    /// then reports nothing to copy). Pruned with the other per-session
    /// registries by Task 13 Step 3b.
    func registerTerminalScreenTextProvider(_ provider: @escaping () -> String, for id: UUID) {
        terminalScreenTextProviders[id] = provider
    }
    func clearTerminalScreenTextProvider(for id: UUID) {
        terminalScreenTextProviders[id] = nil
    }

    /// F-1: live SwiftTerm caret origin (SwiftUI top-left space) for the
    /// inline-ghost-text overlay, derived from SwiftTerm's public `caretFrame`.
    /// Mirrors the screen-text provider: weak-captures the view, so a stale
    /// entry for a dismantled view safely returns nil.
    /// Stored directly (not appModel-backed, no objectWillChange on register):
    /// provider registration is not display-relevant state; the overlay
    /// refreshes off the OSC 133 `T` ingest, not off registration.
    /// FB-3-6: store→view push channel for sending raw bytes to a session's PTY
    /// (interrupt = ^C). Registered by the view, mirrors the pull-providers.
    /// Runtime-only, not synced. Cleared on closeSession / runtime-state reset.
    private var terminalInputSinks: [UUID: (String) -> Void] = [:]

    /// Slice 5: model-owned live terminal surfaces, keyed "<sessionID>#<gen>".
    /// Runtime-only; holds AppKit views so it is NOT @Observable and never synced.
    let terminalSurfacePool = TerminalSurfacePool<TerminalSurfaceController>()

    /// Slice 5: true only while a bulk drain (app quit) is tearing surfaces down,
    /// so the drain's SIGTERMs do not delete agent worktrees (quitting ≠ closing).
    private var suppressAgentWorktreeCleanup = false

    func registerTerminalInputSink(_ sink: @escaping (String) -> Void, for id: UUID) {
        terminalInputSinks[id] = sink
    }

    private var terminalCaretOriginProviders: [UUID: () -> (x: CGFloat, y: CGFloat)?] = [:]
    func registerTerminalCaretOriginProvider(
        _ provider: @escaping () -> (x: CGFloat, y: CGFloat)?, for id: UUID) {
        terminalCaretOriginProviders[id] = provider
    }
    func clearTerminalCaretOriginProvider(for id: UUID) {
        terminalCaretOriginProviders[id] = nil
    }
    func terminalCaretOrigin(for id: UUID) -> (x: CGFloat, y: CGFloat)? {
        terminalCaretOriginProviders[id]?()
    }

    /// F-1: SwiftTerm finished rendering a visual change. Refresh the ghost
    /// overlay so it re-reads the now-fresh `caretFrame`. Gated on an active
    /// prompt buffer so heavy command output (suggestion already cleared on
    /// `.commandStarted`) triggers zero work — no redraw storm.
    func terminalRenderChanged(for sessionID: UUID) {
        guard terminalInputBuffers[sessionID] != nil else { return }
        objectWillChange.send()
    }

    /// OSC-2 window title from SwiftTerm's delegate (replaces the deleted
    /// applyTerminalScreenMetadata title path).
    func setSessionTerminalTitle(_ title: String, for sessionID: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].title = String(trimmed.prefix(120))
    }

    /// OSC-7 cwd from SwiftTerm's delegate (OSC 133 `pwd=` still also sets this
    /// via applyShellIntegration .commandFinished).
    func setSessionWorkingDirectory(_ directory: String, for sessionID: UUID) {
        guard !directory.isEmpty,
              let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].currentWorkingDirectory = directory
    }

    /// Records the tunnel/profile needed to auto-reconnect this session's
    /// `ssh -L` if its process exits (consumed by `noteSessionProcessExited`).
    func registerTunnelReconnectContext(tunnel: SavedSSHTunnel, profile: ConnectionProfile, for sessionID: UUID) {
        tunnelReconnectContexts[sessionID] = TunnelReconnectContext(tunnel: tunnel, profile: profile)
    }
    func clearTunnelReconnectContext(for sessionID: UUID) {
        tunnelReconnectContexts[sessionID] = nil
    }

    /// SwiftTerm processTerminated (replaces appendPTYExit). exitCode nil = IO
    /// error, not a clean exit. For a tunnel session it then dispatches to the
    /// reconnect policy via the registered reconnect context.
    func noteSessionProcessExited(exitCode: Int32?, for sessionID: UUID, generation: Int? = nil) {
        // Restart re-spawns by bumping the launch generation, which tears down
        // the prior view and SIGTERMs its child — that exit arrives tagged with
        // the OLD generation. Ignoring it prevents a spurious .exited transition
        // (and notification) and, critically, the worktree cleanup that would
        // delete the directory the new process just started in. (After close the
        // generation entry is cleared, so a late stale exit there is absorbed by
        // the session-lookup guard below instead, not by this check.)
        if let generation, generation < (terminalLaunchGenerations[sessionID] ?? 0) {
            return
        }
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        if let exitCode { sessions[index].lastExitCode = exitCode }
        let detail = exitCode.map { "status \($0)" } ?? "I/O error"
        appendLine(TerminalLine(role: .system, text: "Process exited (\(detail))."), to: sessionID)
        if let context = tunnelReconnectContexts[sessionID] {
            // nil exitCode (I/O error / abnormal) -> -1 so the policy treats it
            // as a failure exit eligible for auto-reconnect.
            handleTunnelReconnect(
                status: exitCode ?? -1,
                tunnel: context.tunnel, profile: context.profile, sessionID: sessionID)
        }
        feedAgentEvent(.processExited, to: sessionID)
        agentQuiescenceTasks[sessionID]?.cancel()
        agentQuiescenceTasks.removeValue(forKey: sessionID)
        try? FileManager.default.removeItem(
            at: agentStateRoot.appendingPathComponent("\(sessionID.uuidString).state"))
        cleanupAgentWorktreeIfNeeded(for: sessionID)
        // Slice 5: the child is already gone — evict its surface (frees the launch
        // temp; the processIsDead guard skips a re-kill). No-op for non-pooled
        // (.commandLine SSH/tunnel) sessions, and a no-op in the restart case
        // (the generation guard above returns before reaching here).
        let exitedGeneration = generation ?? (terminalLaunchGenerations[sessionID] ?? 0)
        terminalSurfacePool.terminate(forKey: "\(sessionID.uuidString)#\(exitedGeneration)")
    }

    // MARK: - FB-3-2 agent state machine driving

    private func feedAgentEvent(_ event: AgentStateEvent, to sessionID: UUID) {
        guard var machine = agentStateMachines[sessionID],
              let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let changed = machine.handle(event)
        agentStateMachines[sessionID] = machine
        if changed {
            sessions[index].agentActivity = machine.state
            sessions[index].stateChangedAt = Date()
            maybeNotifyAgentTransition(newState: machine.state, sessionID: sessionID)
            refreshAgentVitals()
        }
    }

    /// FB-3-3: route an actionable agent transition to the notification sink,
    /// suppressing the banner for the agent the user is already viewing.
    private func maybeNotifyAgentTransition(newState: AgentActivityState, sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }),
              let agent = sessions[index].agentType else { return }
        let cwdBasename = sessions[index].currentWorkingDirectory
            .map { URL(fileURLWithPath: $0).lastPathComponent }
        let suppressed = appIsActive() && selectedSessionID == sessionID
        let context = AgentNotificationPolicy.Context(
            agent: agent,
            cwdBasename: cwdBasename,
            lastExitCode: sessions[index].lastExitCode,
            suppressed: suppressed
        )
        if let notification = AgentNotificationPolicy.notification(
            for: newState, sessionID: sessionID, context: context) {
            remoteNotificationSink(notification)
        }
    }

    /// FB-3-3: bring Termy forward with the agent's tab focused (notification
    /// click). No-op if the session has since closed.
    func focusAgentSession(_ sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else { return }
        selectedSessionID = sessionID
        openModuleTab(.agents)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    /// Called from `applyShellIntegration` for agent sessions on any byte-tap
    /// event: marks `.working` and (re)arms the quiescence timer.
    func noteAgentActivity(for sessionID: UUID) {
        // Don't re-arm the silence timer for an exited (or non-agent) session.
        guard let state = agentStateMachines[sessionID]?.state, state != .exited else { return }
        feedAgentEvent(.activityTick, to: sessionID)
        agentQuiescenceTasks[sessionID]?.cancel()
        let task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: TermyStore.agentQuiescenceNs)
            if Task.isCancelled { return }
            self?.agentQuiescenceFired(for: sessionID)
        }
        agentQuiescenceTasks[sessionID] = task
    }

    func agentQuiescenceFired(for sessionID: UUID) {
        feedAgentEvent(.quiescenceElapsed, to: sessionID)
    }

    func applyAgentHookSignal(_ signal: AgentHookSignal, for sessionID: UUID) {
        feedAgentEvent(.hook(signal), to: sessionID)
    }

    /// Drains the agent-state directory and routes each one-shot signal to its
    /// live agent session (invoked by `AgentStateWatcher`).
    private func consumeAgentStateFiles() {
        for entry in AgentStateFiles.consume(in: agentStateRoot) {
            guard sessions.contains(where: { $0.id == entry.sessionID && $0.agentType != nil })
            else { continue }
            applyAgentHookSignal(entry.signal, for: entry.sessionID)
        }
    }

    /// FB-3-5: drains `*.tool.json` payloads and folds each into the owning live
    /// agent session's accumulated progress (invoked by `AgentStateWatcher`).
    func consumeAgentProgressFiles() {
        for entry in AgentProgressFiles.consume(in: agentStateRoot) {
            guard sessions.contains(where: { $0.id == entry.sessionID && $0.agentType != nil })
            else { continue }
            agentProgress[entry.sessionID] = reduceAgentProgress(
                agentProgress[entry.sessionID] ?? .empty, applying: entry.event)
        }
        refreshAgentVitals()
    }

    private func ensureAgentStateWatcherStarted() {
        guard agentStateWatcher == nil else { return }
        let watcher = AgentStateWatcher(directory: agentStateRoot) { [weak self] in
            Task { @MainActor in
                self?.consumeAgentStateFiles()
                self?.consumeAgentProgressFiles()
            }
        }
        // Only retain on a successful fd open, so a failure is retried next launch.
        if watcher.start() { agentStateWatcher = watcher }
    }

}

private extension ShortcutDescriptor {
    var modifierName: String {
        switch self {
        case .command:
            return "command"
        case .commandShift:
            return "commandShift"
        case .commandOption:
            return "commandOption"
        case .controlCommand:
            return "controlCommand"
        }
    }

    var key: String {
        switch self {
        case .command(let key), .commandShift(let key), .commandOption(let key), .controlCommand(let key):
            return key
        }
    }

    init?(modifierName: String, key: String) {
        switch modifierName {
        case "command":
            self = .command(key)
        case "commandShift":
            self = .commandShift(key)
        case "commandOption":
            self = .commandOption(key)
        case "controlCommand":
            self = .controlCommand(key)
        default:
            return nil
        }
    }
}

private func customThemeID(for name: String) -> String {
    let slug = name
        .lowercased()
        .map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .reduce(into: "") { partial, character in
            if character == "-", partial.last == "-" {
                return
            }
            partial.append(character)
        }
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return "custom-\(slug.isEmpty ? "theme" : slug)"
}

private func normalizedHex(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
}

private func promptSnippetID(for title: String) -> String {
    let slug = title
        .lowercased()
        .map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .reduce(into: "") { partial, character in
            if character == "-", partial.last == "-" {
                return
            }
            partial.append(character)
        }
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return slug.isEmpty ? UUID().uuidString : slug
}

private func shellArguments(from text: String) -> [String] {
    text
        .split(separator: " ")
        .map(String.init)
        .filter { !$0.isEmpty }
}

private extension TerminalLaunchDescriptor {
    func withWorkingDirectory(_ workingDirectory: String?) -> TerminalLaunchDescriptor {
        TerminalLaunchDescriptor(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            usesZshIntegration: usesZshIntegration,
            highlightStyles: highlightStyles
        )
    }
}

// MARK: - F-4 Test seams

#if DEBUG
extension TermyStore {
    /// Creates a synthetic `.rawPTY` session record for testing sidecar wiring.
    /// Does NOT start a real PTY. Returns the session UUID.
    func testAddRawPtySession(cwd: String = "/tmp") -> UUID {
        let session = TermySession(
            title: "Test PTY",
            profile: .local(),
            currentWorkingDirectory: cwd,
            interactionMode: .rawPTY
        )
        sessions.append(session)
        return session.id
    }

    /// Installs a fake `CompletionSidecar` (no real Process) for testing.
    /// The fake sidecar wires its `onEvent` back to `applySidecarEvent` and
    /// its `onStateChange` back to `applySidecarStateChange`.
    func testInstallFakeSidecar(for sessionID: UUID) async -> CompletionSidecar {
        let workDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("termy-store-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let token = UUID()
        let sidecar = CompletionSidecar(
            workDir: workDir,
            writer: { _ in },
            onEvent: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.applySidecarEvent(event, sessionID: sessionID, sidecarToken: token)
                }
            },
            onStateChange: { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.applySidecarStateChange(state, sessionID: sessionID, sidecarToken: token)
                }
            }
        )
        completionSidecars[sessionID] = sidecar
        completionSidecarTokens[sessionID] = token
        // Manually drop a __boot__.flag so the actor transitions .booting → .ready.
        let bootFlag = workDir.appendingPathComponent("__boot__.flag")
        try? "".write(to: bootFlag, atomically: true, encoding: .utf8)
        await sidecar.pollResultsOnce()
        return sidecar
    }

    func testHasCompletionSidecar(for sessionID: UUID) -> Bool {
        completionSidecars[sessionID] != nil
    }

    func testCompletionSidecarWorkDir(for sessionID: UUID) -> URL? {
        completionSidecars[sessionID]?.workDir
    }

    func testCompletionSidecarToken(for sessionID: UUID) -> UUID? {
        completionSidecarTokens[sessionID]
    }

    /// Exposes `applySidecarEvent` for direct injection in tests.
    func applySidecarEventForTesting(
        _ event: CompletionSidecarResultWatcher.Event,
        sessionID: UUID,
        sidecarToken: UUID? = nil
    ) {
        applySidecarEvent(event, sessionID: sessionID, sidecarToken: sidecarToken)
    }

    /// True when the 80 ms debounce has elapsed for `sessionID`.
    func testDebounceElapsed(_ sid: UUID) -> Bool {
        sidecarDebounceElapsed.contains(sid)
    }

    /// Force-sets debounce-elapsed for `sessionID` (simulates the 80 ms timer firing).
    func testMarkDebounceElapsed(_ sid: UUID) {
        sidecarDebounceElapsed.insert(sid)
    }

    /// True when a menu is open (non-nil state entry) for `sessionID`.
    func testMenuIsOpen(for sid: UUID) -> Bool {
        terminalMenuStates[sid] != nil
    }

    /// Opens the menu with synthetic items for testing.
    func testOpenMenu(_ sid: UUID, items: [CompletionCandidate] = []) {
        terminalMenuStates[sid] = MenuState(items: items, selection: 0)
    }

    /// Sets the raw input buffer for testing (simulates OSC 133 T events).
    func testSetInputBuffer(_ sid: UUID, text: String, cursor: Int) {
        terminalInputBuffers[sid] = (text, cursor, text.count)
    }
}
#endif
