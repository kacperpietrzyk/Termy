import XCTest
import Combine
@testable import Termy
import TermyCore

final class AppModelTerminalKeymapCoordinatorTests: XCTestCase {
    @MainActor
    func testTerminalModelDefaultsMatchLegacyPublishedDefaults() {
        let model = TerminalModel()
        XCTAssertTrue(model.sessions.isEmpty)
        XCTAssertNil(model.selectedSessionID)
        XCTAssertFalse(model.isCommandCenterPresented)
        XCTAssertEqual(model.commandQuery, "")
        XCTAssertEqual(model.terminalSearchQuery, "")
        XCTAssertEqual(model.terminalSearchResults, [])
        XCTAssertEqual(model.terminalLinks, [])
        XCTAssertNil(model.selectedTerminalBlockStartLine)
        XCTAssertEqual(model.foldedTerminalBlockStartLines, [])
        XCTAssertNil(model.terminalScrollTargetLineID)
        XCTAssertEqual(model.selectedTerminalThemeID, TerminalThemeCatalog.builtIn.defaultTheme.id)
        XCTAssertEqual(model.customTerminalThemes, [])
        XCTAssertEqual(model.customThemeName, "Forest")
        XCTAssertEqual(model.customThemeBackgroundHex, "#101A14")
        XCTAssertEqual(model.customThemeForegroundHex, "#E6F2E8")
        XCTAssertEqual(model.customThemePromptHex, "#7DD87D")
        XCTAssertEqual(model.customThemeErrorHex, "#FF6B6B")
        XCTAssertEqual(model.customThemeMutedHex, "#78917D")
        XCTAssertEqual(model.terminalFontSize, 13.0)
        XCTAssertEqual(model.terminalFontFamily, "SF Mono")
        XCTAssertTrue(model.terminalUsesLigatures)
        XCTAssertFalse(model.terminalIncreasedContrast)
        XCTAssertEqual(model.terminalShellKind, "zsh")
        XCTAssertEqual(model.terminalCustomShellPath, "/opt/homebrew/bin/fish")
        XCTAssertEqual(model.terminalCustomShellArguments, "--login")
        XCTAssertEqual(model.terminalOutputMode, TerminalOutputMode.stream.rawValue)
    }

    @MainActor
    func testKeymapModelDefaultsMatchLegacyPublishedDefaults() {
        let model = KeymapModel()
        XCTAssertEqual(model.keymapProfile, KeymapProfile())
        XCTAssertEqual(model.selectedKeymapActionID, "open-command-center")
        XCTAssertEqual(model.keymapModifier, "command")
        XCTAssertEqual(model.keymapKey, "k")
    }

    @MainActor
    func testCoordinatorModelDefaultsMatchLegacyPublishedDefaults() {
        let model = CoordinatorModel()
        XCTAssertNil(model.activePanel)
        XCTAssertEqual(model.statusMessage, "Ready")
        XCTAssertEqual(model.interfaceTextScaleRawValue, InterfaceTextScale.regular.rawValue)
        XCTAssertEqual(model.projectGuidance, ProjectGuidance(documents: []))
    }

    @MainActor
    func testAppModelExposesTerminalKeymapCoordinatorModels() {
        let app = AppModel()
        app.terminal.commandQuery = "term-changed"
        app.keymap.keymapKey = "j"
        app.coordinator.statusMessage = "coord-changed"
        XCTAssertEqual(app.terminal.commandQuery, "term-changed")
        XCTAssertEqual(app.keymap.keymapKey, "j")
        XCTAssertEqual(app.coordinator.statusMessage, "coord-changed")
    }

    @MainActor
    func testStoreTerminalForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.commandQuery = "q"
        store.historyStore.record(command: "a", cwd: nil)
        store.historyStore.record(command: "b", cwd: nil)
        store.terminalSearchQuery = "find"
        store.selectedTerminalThemeID = "theme-x"
        store.customThemeName = "Ocean"
        store.terminalFontSize = 18.0
        store.terminalShellKind = "fish"
        store.terminalOutputMode = "blocks"

        XCTAssertEqual(store.appModel.terminal.commandQuery, "q")
        let snapshot = store.historyStore.rankedSnapshot(forCwd: nil)
        XCTAssertTrue(snapshot.contains("a"), "historyStore should contain recorded command 'a'")
        XCTAssertTrue(snapshot.contains("b"), "historyStore should contain recorded command 'b'")
        XCTAssertEqual(store.appModel.terminal.terminalSearchQuery, "find")
        XCTAssertEqual(store.appModel.terminal.selectedTerminalThemeID, "theme-x")
        XCTAssertEqual(store.appModel.terminal.customThemeName, "Ocean")
        XCTAssertEqual(store.appModel.terminal.terminalFontSize, 18.0)
        XCTAssertEqual(store.appModel.terminal.terminalShellKind, "fish")
        XCTAssertEqual(store.appModel.terminal.terminalOutputMode, "blocks")

        store.appModel.terminal.commandQuery = "back-prop"
        XCTAssertEqual(store.commandQuery, "back-prop")
    }

    @MainActor
    func testStoreKeymapForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.selectedKeymapActionID = "act-1"
        store.keymapModifier = "control"
        store.keymapKey = "p"

        XCTAssertEqual(store.appModel.keymap.selectedKeymapActionID, "act-1")
        XCTAssertEqual(store.appModel.keymap.keymapModifier, "control")
        XCTAssertEqual(store.appModel.keymap.keymapKey, "p")

        store.appModel.keymap.keymapKey = "back-prop"
        XCTAssertEqual(store.keymapKey, "back-prop")
    }

    @MainActor
    func testStoreCoordinatorForwardersReadAndWriteAppModel() {
        let store = TermyStore(startInitialPTY: false)

        store.statusMessage = "Working"
        store.interfaceTextScaleRawValue = InterfaceTextScale.large.rawValue
        store.activePanel = .files

        XCTAssertEqual(store.appModel.coordinator.statusMessage, "Working")
        XCTAssertEqual(store.appModel.coordinator.interfaceTextScaleRawValue, InterfaceTextScale.large.rawValue)
        XCTAssertEqual(store.appModel.coordinator.activePanel, .files)

        store.appModel.coordinator.statusMessage = "back-prop"
        XCTAssertEqual(store.statusMessage, "back-prop")
    }

    @MainActor
    func testStoreTerminalForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("sessions") { store.sessions = [] }
        assertOneFire("selectedSessionID") { store.selectedSessionID = UUID() }
        assertOneFire("isCommandCenterPresented") { store.isCommandCenterPresented = true }
        assertOneFire("commandQuery") { store.commandQuery = "q" }
        assertOneFire("terminalSearchQuery") { store.terminalSearchQuery = "s" }
        assertOneFire("terminalSearchResults") { store.terminalSearchResults = [] }
        assertOneFire("terminalLinks") { store.terminalLinks = [] }
        assertOneFire("selectedTerminalBlockStartLine") { store.selectedTerminalBlockStartLine = 3 }
        assertOneFire("foldedTerminalBlockStartLines") { store.foldedTerminalBlockStartLines = [1] }
        assertOneFire("terminalScrollTargetLineID") { store.terminalScrollTargetLineID = UUID() }
        assertOneFire("selectedTerminalThemeID") { store.selectedTerminalThemeID = "t" }
        assertOneFire("customTerminalThemes") { store.customTerminalThemes = [] }
        assertOneFire("customThemeName") { store.customThemeName = "n" }
        assertOneFire("customThemeBackgroundHex") { store.customThemeBackgroundHex = "#000000" }
        assertOneFire("customThemeForegroundHex") { store.customThemeForegroundHex = "#ffffff" }
        assertOneFire("customThemePromptHex") { store.customThemePromptHex = "#111111" }
        assertOneFire("customThemeErrorHex") { store.customThemeErrorHex = "#222222" }
        assertOneFire("customThemeMutedHex") { store.customThemeMutedHex = "#333333" }
        assertOneFire("terminalFontSize") { store.terminalFontSize = 15.0 }
        assertOneFire("terminalFontFamily") { store.terminalFontFamily = "Menlo" }
        assertOneFire("terminalUsesLigatures") { store.terminalUsesLigatures = false }
        assertOneFire("terminalIncreasedContrast") { store.terminalIncreasedContrast = true }
        assertOneFire("terminalShellKind") { store.terminalShellKind = "bash" }
        assertOneFire("terminalCustomShellPath") { store.terminalCustomShellPath = "/bin/sh" }
        assertOneFire("terminalCustomShellArguments") { store.terminalCustomShellArguments = "-l" }
        assertOneFire("terminalOutputMode") { store.terminalOutputMode = "blocks" }
    }

    @MainActor
    func testStoreKeymapForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("keymapProfile") { store.keymapProfile = KeymapProfile() }
        assertOneFire("selectedKeymapActionID") { store.selectedKeymapActionID = "a" }
        assertOneFire("keymapModifier") { store.keymapModifier = "control" }
        assertOneFire("keymapKey") { store.keymapKey = "j" }
    }

    @MainActor
    func testStoreCoordinatorForwardersFireObjectWillChangePerProperty() {
        let store = TermyStore(startInitialPTY: false)
        var fireCount = 0
        let cancellable = store.objectWillChange.sink { fireCount += 1 }
        defer { cancellable.cancel() }

        func assertOneFire(_ label: String, _ mutate: () -> Void) {
            fireCount = 0
            mutate()
            XCTAssertEqual(fireCount, 1, "\(label): exactly one objectWillChange must fire so @ObservedObject views re-render")
        }

        assertOneFire("activePanel") { store.activePanel = .files }
        assertOneFire("statusMessage") { store.statusMessage = "s" }
        assertOneFire("interfaceTextScaleRawValue") { store.interfaceTextScaleRawValue = InterfaceTextScale.large.rawValue }
        assertOneFire("projectGuidance") { store.projectGuidance = ProjectGuidance(documents: []) }
    }
}
