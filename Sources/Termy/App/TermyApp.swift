import AppKit
import SwiftUI
import TermyCore
import TermySync

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NativeRemoteNotificationCenter.shared.requestAuthorization()
    }
}

@main
struct TermyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TermyStore(
        remoteNotificationSink: {
            NativeRemoteNotificationCenter.shared.deliver($0)
        },
        appIsActive: { NSApp.isActive }
    )
    private let privateSyncBackgroundScheduler = PrivateSyncBackgroundScheduler()

    var body: some Scene {
        WindowGroup("Termy", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1180, minHeight: 720)
                .task {
                    NativeRemoteNotificationCenter.shared.onAgentNotificationActivated = { [store] sessionID in
                        store.focusAgentSession(sessionID)
                    }
                    privateSyncBackgroundScheduler.register(store: store)
                    privateSyncBackgroundScheduler.scheduleAppRefresh()
                    store.startPrivateSyncAppLaunch()
                    store.appModel.update.activateLiveUpdater()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.shutdown()
                }
        }
        .defaultSize(width: 1480, height: 940)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Local Terminal") {
                    store.perform("new-local-terminal")
                }
                .termyKeyboardShortcut(store.shortcut(for: "new-local-terminal") ?? .command("n"))
            }

            CommandMenu("Sessions") {
                Button("Connect SSH") {
                    store.perform("connect-ssh")
                }
                .termyKeyboardShortcut(store.shortcut(for: "connect-ssh") ?? .commandShift("s"))

                Button("Connect RDP") {
                    store.perform("connect-rdp")
                }
                .termyKeyboardShortcut(store.shortcut(for: "connect-rdp") ?? .commandShift("r"))

                Divider()

                Button("Close Session") {
                    store.perform("close-session")
                }
            }

            CommandMenu("Panels") {
                Button("Command Center") {
                    store.perform("open-command-center")
                }
                .termyKeyboardShortcut(store.shortcut(for: "open-command-center") ?? .command("k"))

                Divider()

                Button("AI Panel") {
                    store.perform("toggle-ai-panel")
                }
                .termyKeyboardShortcut(store.shortcut(for: "toggle-ai-panel") ?? .commandShift("a"))

                Button("File Explorer") {
                    store.perform("toggle-file-explorer")
                }
                .termyKeyboardShortcut(store.shortcut(for: "toggle-file-explorer") ?? .commandShift("f"))

                Button("Git Panel") {
                    store.perform("toggle-git-panel")
                }
                .termyKeyboardShortcut(store.shortcut(for: "toggle-git-panel") ?? .commandShift("g"))

                Button("Editor") {
                    store.perform("toggle-editor")
                }
                .termyKeyboardShortcut(store.shortcut(for: "toggle-editor") ?? .commandShift("e"))
            }

            CommandMenu("Tabs") {
                Button("Desktop") { store.goToDesktop() }
                    .keyboardShortcut("0", modifiers: .command)

                ForEach(1...9, id: \.self) { n in
                    Button("Tab \(n)") { store.goToTab(index: n) }
                        .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                }

                Divider()

                Button(store.activeTab == .module(.shell) ? "New Shell Session" : "New Tab") {
                    store.handleNewTabShortcut()
                }
                .keyboardShortcut("t", modifiers: .command)
                Button("Quick Switcher") { store.perform("open-command-center") }
                    .keyboardShortcut("p", modifiers: .command)
                Button("Close Tab") { store.closeActiveTab() }
                    .keyboardShortcut("w", modifiers: .command)
            }

            CommandMenu("Tiling") {
                Button("Tile Editor Right") {
                    store.perform("tile-editor-right")
                }
                .termyKeyboardShortcut(store.shortcut(for: "tile-editor-right") ?? .controlCommand("e"))

                Button("Tile AI Bottom") {
                    store.perform("tile-ai-bottom")
                }
                .termyKeyboardShortcut(store.shortcut(for: "tile-ai-bottom") ?? .controlCommand("a"))

                Button("Focus Next Pane") {
                    store.perform("focus-next-pane")
                }
                .termyKeyboardShortcut(store.shortcut(for: "focus-next-pane") ?? .controlCommand("]"))

                Button("Increase Focused Pane") {
                    store.perform("resize-focused-pane-larger")
                }
                .termyKeyboardShortcut(store.shortcut(for: "resize-focused-pane-larger") ?? .controlCommand("="))

                Button("Decrease Focused Pane") {
                    store.perform("resize-focused-pane-smaller")
                }
                .termyKeyboardShortcut(store.shortcut(for: "resize-focused-pane-smaller") ?? .controlCommand("-"))

                Button("Close Focused Pane") {
                    store.perform("close-focused-pane")
                }
                .termyKeyboardShortcut(store.shortcut(for: "close-focused-pane") ?? .controlCommand("w"))
            }

            CommandMenu("Workspace") {
                Button("Save Workspace") {
                    store.perform("save-workspace")
                }
                .termyKeyboardShortcut(store.shortcut(for: "save-workspace") ?? .command("s"))

                Button("New Pane Right") { store.perform("split-pane-trailing") }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Split Down") { store.perform("split-pane-bottom") }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Focus Next Pane") { store.perform("focus-next-pane") }
                    .keyboardShortcut("'", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    store.appModel.update.checkForUpdates()
                }
                .disabled(!store.appModel.update.canCheckForUpdates)
            }

            // v3: Settings is an in-shell module tab (DESIGN.md §3.2 orb), not a
            // separate macOS Settings window. Route ⌘, to the Settings tab so the
            // user lands inside the shell (with the tab bar / Desktop back) instead
            // of a chrome-less standalone window they can't navigate out of.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { store.openModuleTab(.settings) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

private extension View {
    func termyKeyboardShortcut(_ shortcut: ShortcutDescriptor) -> some View {
        keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.eventModifiers)
    }
}

private extension ShortcutDescriptor {
    var keyEquivalent: KeyEquivalent {
        let rawKey: String
        switch self {
        case .command(let key), .commandShift(let key), .commandOption(let key), .controlCommand(let key):
            rawKey = key
        }
        return KeyEquivalent(Character(String(rawKey.lowercased().prefix(1))))
    }

    var eventModifiers: EventModifiers {
        switch self {
        case .command:
            return .command
        case .commandShift:
            return [.command, .shift]
        case .commandOption:
            return [.command, .option]
        case .controlCommand:
            return [.control, .command]
        }
    }
}
