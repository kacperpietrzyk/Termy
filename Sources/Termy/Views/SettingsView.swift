import SwiftUI
import TermyCore

/// Settings rendered in the app's card/section language (DESIGN.md §148 +
/// the Home/Shell `TermyDetailCard` kit), replacing the transitional macOS
/// `Form`. Presentation-only: every control keeps its EXACT existing binding
/// and action — no store/logic changes. Stays the breadcrumb-less body of the
/// generic `.module` path inside `ModulePageView`'s GeometryReader, so the
/// content scrolls in place and the column is centered, not edge-to-edge.
struct SettingsView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        ScrollView {
            SettingsContent(store: store)
                .frame(maxWidth: 600)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
        }
    }
}

/// The stacked settings cards. Extracted so the visual gate can rasterize the
/// full column at a tall frame (ScrollView content does not rasterize under
/// ImageRenderer).
struct SettingsContent: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        VStack(spacing: 16) {
            privacyCard
            keyboardCard
            aliasesCard
            terminalCard
            privateSyncCard
            updatesCard
            workspacesCard
        }
    }

    // MARK: Command Aliases (CK-S8)

    /// Strict-prefix ⌘K aliases: a short literal prefix → an action title, a
    /// connection name, or a shell command. Typing the exact prefix in ⌘K jumps
    /// straight to the target (ahead of fuzzy). Persisted + synced via the same
    /// private-sync planner as snippets.
    private var aliasesCard: some View {
        TermyDetailCard(title: "Command Aliases", systemImage: "arrow.right.square") {
            VStack(spacing: 12) {
                SettingsRow("Prefix") {
                    TextField("gs", text: $store.aliasPrefixDraft)
                        .textFieldStyle(GlassTextFieldStyle())
                        .frame(width: 120)
                }
                SettingsRow("Expansion", description: "Action title, connection name, or shell command") {
                    TextField("git status", text: $store.aliasExpansionDraft)
                        .textFieldStyle(GlassTextFieldStyle())
                        .frame(width: 200)
                }
                HStack {
                    Button("Add Alias") { store.addAlias() }
                        .buttonStyle(TermyCompactButtonStyle())
                    Spacer()
                }
                if !store.paletteAliases.isEmpty {
                    Divider().overlay(Color(DesignTokens.hair))
                    ForEach(store.paletteAliases) { alias in
                        HStack(spacing: 8) {
                            Text(alias.prefix)
                                .font(Typography.mono(12, weight: .semibold))
                            Text("→")
                                .foregroundStyle(Color(DesignTokens.fg4))
                            Text(alias.expansion)
                                .font(Typography.mono(12))
                                .foregroundStyle(Color(DesignTokens.fg3))
                                .lineLimit(1)
                            Spacer()
                            Button("Remove") { store.removeAlias(alias) }
                                .buttonStyle(TermyCompactButtonStyle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: Privacy

    private var privacyCard: some View {
        TermyDetailCard(title: "Privacy", systemImage: "lock.shield") {
            VStack(spacing: 12) {
                SettingsRow("Telemetry") { readonlyValue(store.privacyPolicy.allowsTelemetry ? "Allowed" : "Disabled") }
                SettingsRow("Termy Account") { readonlyValue(store.privacyPolicy.allowsTermyAccount ? "Required" : "Not used") }
                SettingsRow("Built-in AI") { readonlyValue(store.privacyPolicy.requiresLocalBuiltInAI ? "Local models only" : "Remote allowed") }
            }
        }
    }

    // MARK: Keyboard

    private var keyboardCard: some View {
        TermyDetailCard(title: "Keyboard", systemImage: "keyboard") {
            VStack(spacing: 12) {
                SettingsRow("Action") {
                    Picker("Action", selection: $store.selectedKeymapActionID) {
                        ForEach(store.keymapActions) { action in
                            Text(action.title).tag(action.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: store.selectedKeymapActionID) {
                        store.loadSelectedKeymapAction()
                    }
                }
                SettingsRow("Modifier") {
                    Picker("Modifier", selection: $store.keymapModifier) {
                        Text("Command").tag("command")
                        Text("Command-Shift").tag("commandShift")
                        Text("Command-Option").tag("commandOption")
                        Text("Control-Command").tag("controlCommand")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                SettingsRow("Key") {
                    TextField("Key", text: $store.keymapKey)
                        .textFieldStyle(GlassTextFieldStyle())
                        .frame(width: 120)
                }
                SettingsRow("Active", description: store.shortcut(for: store.selectedKeymapActionID)?.displayValue ?? "None") {
                    Button("Apply Shortcut") {
                        store.applyKeymapDraft()
                    }
                    .buttonStyle(TermyCompactButtonStyle())
                }

                if !store.keymapConflicts.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.keymapConflicts, id: \.shortcut) { conflict in
                            Text("Conflict \(conflict.shortcut.displayValue): \(conflict.actionIDs.joined(separator: ", "))")
                                .font(Typography.ui(12))
                                .foregroundStyle(Color(DesignTokens.error.base))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DisclosureGroup("Shortcut Cheat Sheet") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.shortcutCheatSheet) { entry in
                            ShortcutCheatSheetRow(entry: entry)
                        }
                    }
                    .padding(.top, 4)
                }
                .font(Typography.ui(12))
            }
        }
    }

    // MARK: Terminal

    private var terminalCard: some View {
        TermyDetailCard(title: "Terminal", systemImage: "terminal") {
            VStack(spacing: 12) {
                SettingsRow("Theme") {
                    Picker("Theme", selection: $store.selectedTerminalThemeID) {
                        ForEach(store.terminalThemeCatalog.themes) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                SettingsRow("Font Size") {
                    Stepper(
                        "\(Int(store.terminalFontPreferences.size))",
                        value: $store.terminalFontSize,
                        in: 9...32
                    )
                    .fixedSize()
                }
                SettingsRow("Font Family") {
                    TextField("Font Family", text: $store.terminalFontFamily)
                        .textFieldStyle(GlassTextFieldStyle())
                        .frame(width: 180)
                }
                SettingsRow("Ligatures") {
                    Toggle("", isOn: $store.terminalUsesLigatures).labelsHidden()
                }
                SettingsRow("Increased Contrast") {
                    Toggle("", isOn: $store.terminalIncreasedContrast).labelsHidden()
                }
                SettingsRow("Interface Text") {
                    Picker("Interface Text", selection: $store.interfaceTextScaleRawValue) {
                        ForEach(InterfaceTextScale.allCases, id: \.rawValue) { scale in
                            Text(scale.title).tag(scale.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                SettingsRow("Output") {
                    Picker(
                        "Output",
                        selection: Binding(
                            get: { store.selectedTerminalOutputModeRawValue },
                            set: { rawValue in
                                store.setSelectedTerminalOutputMode(TerminalOutputMode(rawValue: rawValue) ?? .stream)
                            }
                        )
                    ) {
                        Text("Stream").tag(TerminalOutputMode.stream.rawValue)
                        Text("Blocks").tag(TerminalOutputMode.blocks.rawValue)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                SettingsRow("Shell") {
                    Picker("Shell", selection: $store.terminalShellKind) {
                        Text("zsh").tag("zsh")
                        Text("bash").tag("bash")
                        Text("Custom").tag("custom")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                if store.terminalShellKind == "custom" {
                    SettingsRow("Shell Path") {
                        TextField("Shell Path", text: $store.terminalCustomShellPath)
                            .textFieldStyle(GlassTextFieldStyle())
                            .frame(width: 200)
                    }
                    SettingsRow("Arguments") {
                        TextField("Arguments", text: $store.terminalCustomShellArguments)
                            .textFieldStyle(GlassTextFieldStyle())
                            .frame(width: 200)
                    }
                }

                customThemeSubGroup
            }
        }
    }

    private var customThemeSubGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(Color(DesignTokens.hair))
            Text("Custom Theme")
                .font(Typography.ui(10.5, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color(DesignTokens.fg4))
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Custom Theme Name", text: $store.customThemeName)
                .textFieldStyle(GlassTextFieldStyle())
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    TextField("Background", text: $store.customThemeBackgroundHex)
                    TextField("Foreground", text: $store.customThemeForegroundHex)
                }
                GridRow {
                    TextField("Prompt", text: $store.customThemePromptHex)
                    TextField("Error", text: $store.customThemeErrorHex)
                }
                GridRow {
                    TextField("Muted", text: $store.customThemeMutedHex)
                    Button("Add Theme") {
                        store.addCustomTerminalTheme()
                    }
                    .buttonStyle(TermyCompactButtonStyle())
                }
            }
            .textFieldStyle(GlassTextFieldStyle())
        }
    }

    // MARK: Private Sync

    private var privateSyncCard: some View {
        TermyDetailCard(title: "Private Sync", systemImage: "icloud") {
            VStack(spacing: 12) {
                SettingsRow("CloudKit private records") { readonlyValue("\(store.privateSyncRecords.count) staged") }
                SettingsRow("iCloud account") { readonlyValue(store.privateSyncStatus) }
                SettingsRow("Sync queue") { readonlyValue("\(store.privateSyncPendingOperations.count) pending") }
                SettingsRow("Secrets") { readonlyValue("iCloud Keychain only") }
                HStack(spacing: 8) {
                    Button("Check Account") {
                        store.checkPrivateSyncAccount()
                    }
                    Button("Stage Current") {
                        store.stagePrivateSyncSnapshot()
                    }
                    Button("Push") {
                        store.pushPrivateSyncRecords()
                    }
                    Button("Fetch") {
                        store.fetchPrivateSyncWorkspaceRecords()
                    }
                    Spacer()
                }
                .buttonStyle(TermyCompactButtonStyle())
            }
        }
    }

    // MARK: Updates

    private var updatesCard: some View {
        TermyDetailCard(title: "Updates", systemImage: "arrow.triangle.2.circlepath") {
            VStack(spacing: 12) {
                SettingsRow("Check Automatically") {
                    Toggle("", isOn: Binding(
                        get: { store.appModel.update.automaticallyChecksForUpdates },
                        set: { store.appModel.update.automaticallyChecksForUpdates = $0 }
                    ))
                    .labelsHidden()
                }
                HStack {
                    Button("Check for Updates…") {
                        store.appModel.update.checkForUpdates()
                    }
                    .buttonStyle(TermyCompactButtonStyle())
                    .disabled(!store.appModel.update.canCheckForUpdates)
                    Spacer()
                }
            }
        }
    }

    // MARK: Workspaces

    private var workspacesCard: some View {
        TermyDetailCard(title: "Workspaces", systemImage: "rectangle.split.3x1") {
            VStack(spacing: 12) {
                SettingsRow("Saved Layout") {
                    Picker("Saved Layout", selection: $store.selectedWorkspaceID) {
                        ForEach(store.workspaceStore.layouts) { layout in
                            Text(layout.name).tag(Optional(layout.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                HStack(spacing: 8) {
                    Button("Save Current") {
                        store.saveCurrentWorkspaceLayout()
                    }
                    Button("Restore") {
                        store.restoreSelectedWorkspace()
                    }
                    .disabled(store.selectedWorkspaceID == nil)
                    Spacer()
                }
                .buttonStyle(TermyCompactButtonStyle())
            }
        }
    }

    // MARK: Helpers

    private func readonlyValue(_ value: String) -> some View {
        Text(value)
            .font(Typography.mono(12))
            .foregroundStyle(Color(DesignTokens.fg3))
    }
}

/// A label (+ optional secondary description) on the left, a control on the
/// right. The card-language analogue of the old `Form` `LabeledContent` rows.
private struct SettingsRow<Control: View>: View {
    let label: String
    var description: String?
    @ViewBuilder let control: () -> Control

    init(_ label: String, description: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.label = label
        self.description = description
        self.control = control
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.ui(12))
                    .foregroundStyle(Color(DesignTokens.fg2))
                if let description {
                    Text(description)
                        .font(Typography.mono(11))
                        .foregroundStyle(Color(DesignTokens.fg4))
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShortcutCheatSheetRow: View {
    let entry: ShortcutCheatSheetEntry

    var body: some View {
        HStack {
            Text(entry.title)
            Spacer()
            Text(entry.shortcut.displayValue)
                .monospaced()
                .foregroundStyle(entry.conflictingActionIDs.isEmpty ? Color(DesignTokens.fg3) : Color(DesignTokens.error.base))
        }
    }
}

private extension ShortcutDescriptor {
    var displayValue: String {
        switch self {
        case .command(let key): "Command-\(key.uppercased())"
        case .commandShift(let key): "Command-Shift-\(key.uppercased())"
        case .commandOption(let key): "Command-Option-\(key.uppercased())"
        case .controlCommand(let key): "Control-Command-\(key.uppercased())"
        }
    }
}
