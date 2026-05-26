import Foundation
import Observation
import TermyCore

/// Terminal-session / search / theming / shell-domain state, extracted from
/// the `TermyStore` god-object as part of the strangler-facade decomposition
/// (M2c-3). `@Observable` + `@MainActor`: the future state is views observing
/// this model directly via `@Environment(AppModel.self)`; until then
/// `TermyStore` forwards to it. `sessions` defaults to `[]`; the real seed
/// session is written by `TermyStore.init` (see the M2c-3 init note).
@MainActor
@Observable
final class TerminalModel {
    var sessions: [TermySession] = []
    var selectedSessionID: UUID?
    var terminalLaunchDescriptors: [UUID: TerminalLaunchDescriptor] = [:]
    var terminalLaunchGenerations: [UUID: Int] = [:]
    var terminalScreenTextProviders: [UUID: () -> String] = [:]
    var hasRestorableSession = false
    var sessionRestoreStatus: String?
    var isCommandCenterPresented = false
    var commandQuery = ""
    var terminalSearchQuery = ""
    var terminalSearchResults: [TerminalSearchMatch] = []
    var terminalLinks: [TerminalLink] = []
    var selectedTerminalBlockStartLine: Int?
    var foldedTerminalBlockStartLines: Set<Int> = []
    var terminalScrollTargetLineID: UUID?
    var selectedTerminalThemeID = TerminalThemeCatalog.builtIn.defaultTheme.id
    var customTerminalThemes: [TerminalTheme] = []
    var customThemeName = "Forest"
    var customThemeBackgroundHex = "#101A14"
    var customThemeForegroundHex = "#E6F2E8"
    var customThemePromptHex = "#7DD87D"
    var customThemeErrorHex = "#FF6B6B"
    var customThemeMutedHex = "#78917D"
    var terminalFontSize = 13.0
    var terminalFontFamily = "SF Mono"
    var terminalUsesLigatures = true
    var terminalIncreasedContrast = false
    var terminalShellKind = "zsh"
    var terminalCustomShellPath = "/opt/homebrew/bin/fish"
    var terminalCustomShellArguments = "--login"
    var terminalOutputMode = TerminalOutputMode.stream.rawValue

    init() {}
}
