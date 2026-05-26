import SwiftUI
import TermyCore

struct SettingsView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        Form {
            Section("Privacy") {
                LabeledContent("Telemetry", value: store.privacyPolicy.allowsTelemetry ? "Allowed" : "Disabled")
                LabeledContent("Termy Account", value: store.privacyPolicy.allowsTermyAccount ? "Required" : "Not used")
                LabeledContent("Built-in AI", value: store.privacyPolicy.requiresLocalBuiltInAI ? "Local models only" : "Remote allowed")
            }

            Section("Keyboard") {
                Picker("Action", selection: $store.selectedKeymapActionID) {
                    ForEach(store.keymapActions) { action in
                        Text(action.title).tag(action.id)
                    }
                }
                .onChange(of: store.selectedKeymapActionID) {
                    store.loadSelectedKeymapAction()
                }

                Picker("Modifier", selection: $store.keymapModifier) {
                    Text("Command").tag("command")
                    Text("Command-Shift").tag("commandShift")
                    Text("Command-Option").tag("commandOption")
                    Text("Control-Command").tag("controlCommand")
                }

                TextField("Key", text: $store.keymapKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Apply Shortcut") {
                        store.applyKeymapDraft()
                    }
                    LabeledContent("Active", value: store.shortcut(for: store.selectedKeymapActionID)?.displayValue ?? "None")
                }

                if !store.keymapConflicts.isEmpty {
                    ForEach(store.keymapConflicts, id: \.shortcut) { conflict in
                        Text("Conflict \(conflict.shortcut.displayValue): \(conflict.actionIDs.joined(separator: ", "))")
                            .font(Typography.ui(12))
                            .foregroundStyle(Color(DesignTokens.error.base))
                    }
                }

                DisclosureGroup("Shortcut Cheat Sheet") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.shortcutCheatSheet.indices, id: \.self) { index in
                            ShortcutCheatSheetRow(entry: store.shortcutCheatSheet[index])
                        }
                    }
                }
            }

            Section("Terminal") {
                Picker("Theme", selection: $store.selectedTerminalThemeID) {
                    ForEach(store.terminalThemeCatalog.themes) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                Stepper(
                    "Font Size: \(Int(store.terminalFontPreferences.size))",
                    value: $store.terminalFontSize,
                    in: 9...32
                )
                TextField("Font Family", text: $store.terminalFontFamily)
                    .textFieldStyle(.roundedBorder)
                Toggle("Ligatures", isOn: $store.terminalUsesLigatures)
                Toggle("Increased Contrast", isOn: $store.terminalIncreasedContrast)
                Picker("Interface Text", selection: $store.interfaceTextScaleRawValue) {
                    ForEach(InterfaceTextScale.allCases, id: \.rawValue) { scale in
                        Text(scale.title).tag(scale.rawValue)
                    }
                }
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
                Picker("Shell", selection: $store.terminalShellKind) {
                    Text("zsh").tag("zsh")
                    Text("bash").tag("bash")
                    Text("Custom").tag("custom")
                }
                if store.terminalShellKind == "custom" {
                    TextField("Shell Path", text: $store.terminalCustomShellPath)
                        .textFieldStyle(.roundedBorder)
                    TextField("Arguments", text: $store.terminalCustomShellArguments)
                        .textFieldStyle(.roundedBorder)
                }
                Divider()
                TextField("Custom Theme Name", text: $store.customThemeName)
                    .textFieldStyle(.roundedBorder)
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
                    }
                }
                .textFieldStyle(.roundedBorder)
            }

            Section("Private Sync") {
                LabeledContent("CloudKit private records", value: "\(store.privateSyncRecords.count) staged")
                LabeledContent("iCloud account", value: store.privateSyncStatus)
                LabeledContent("Sync queue", value: "\(store.privateSyncPendingOperations.count) pending")
                LabeledContent("Secrets", value: "iCloud Keychain only")
                HStack {
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
                }
            }

            Section("Updates") {
                Button("Check for Updates…") {
                    store.appModel.update.checkForUpdates()
                }
                .disabled(!store.appModel.update.canCheckForUpdates)
                Toggle("Check Automatically", isOn: Binding(
                    get: { store.appModel.update.automaticallyChecksForUpdates },
                    set: { store.appModel.update.automaticallyChecksForUpdates = $0 }
                ))
            }

            Section("Workspaces") {
                Picker("Saved Layout", selection: $store.selectedWorkspaceID) {
                    ForEach(store.workspaceStore.layouts) { layout in
                        Text(layout.name).tag(Optional(layout.id))
                    }
                }
                HStack {
                    Button("Save Current") {
                        store.saveCurrentWorkspaceLayout()
                    }
                    Button("Restore") {
                        store.restoreSelectedWorkspace()
                    }
                    .disabled(store.selectedWorkspaceID == nil)
                }
            }
        }
        .padding()
        .frame(width: 460)
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
