import XCTest
@testable import Termy
import TermyCore

@MainActor
final class ShellNavigationModelTests: XCTestCase {
    func testStartsOnDesktopWithNoOpenTabs() {
        let nav = ShellNavigationModel()
        XCTAssertEqual(nav.activeTab, .desktop)
        XCTAssertTrue(nav.openTabs.isEmpty)
    }

    func testOpenAppendsAndActivates() {
        let nav = ShellNavigationModel()
        nav.open(.git)
        XCTAssertEqual(nav.openTabs, [.git])
        XCTAssertEqual(nav.activeTab, .module(.git))
    }

    func testReopenDoesNotDuplicateButActivates() {
        let nav = ShellNavigationModel()
        nav.open(.git)
        nav.open(.files)
        nav.open(.git)
        XCTAssertEqual(nav.openTabs, [.git, .files])   // no duplicate
        XCTAssertEqual(nav.activeTab, .module(.git))     // re-activated
    }

    func testCloseActiveFallsBackToDesktop() {
        let nav = ShellNavigationModel()
        nav.open(.git)
        nav.close(.git)
        XCTAssertTrue(nav.openTabs.isEmpty)
        XCTAssertEqual(nav.activeTab, .desktop)
    }

    func testCloseBackgroundTabPreservesActive() {
        let nav = ShellNavigationModel()
        nav.open(.git)
        nav.open(.files)              // files now active
        nav.close(.git)               // close the background one
        XCTAssertEqual(nav.openTabs, [.files])
        XCTAssertEqual(nav.activeTab, .module(.files))
    }

    func testTabAtIsOneBased() {
        let nav = ShellNavigationModel()
        nav.open(.shell)
        nav.open(.git)
        XCTAssertEqual(nav.tab(at: 1), .shell)
        XCTAssertEqual(nav.tab(at: 2), .git)
        XCTAssertNil(nav.tab(at: 3))
        XCTAssertNil(nav.tab(at: 0))
    }

    func testCloseNonOpenModuleIsNoop() {
        let nav = ShellNavigationModel()
        nav.close(.editor)
        XCTAssertTrue(nav.openTabs.isEmpty)
        XCTAssertEqual(nav.activeTab, .desktop)
    }

    func testModuleCarriesTitleIconArea() {
        XCTAssertEqual(ShellNavigationModel.Module.git.area, .git)
        XCTAssertEqual(ShellNavigationModel.Module.allCases.count, 8)
        XCTAssertEqual(ShellNavigationModel.Module.git.title, "Git")
        XCTAssertEqual(ShellNavigationModel.Module.shell.title, "Shell")
        XCTAssertFalse(ShellNavigationModel.Module.git.systemImage.isEmpty)
        XCTAssertFalse(ShellNavigationModel.Module.shell.systemImage.isEmpty)
    }

    func testStoreForwardersReflectShellNav() {
        let store = TermyStore(startInitialPTY: false)
        XCTAssertEqual(store.activeTab, .desktop)
        XCTAssertTrue(store.openTabs.isEmpty)

        store.openModuleTab(.git)
        XCTAssertEqual(store.openTabs, [.git])
        XCTAssertEqual(store.activeTab, .module(.git))
        XCTAssertEqual(store.activeTabKey, "git")

        store.openModuleTab(.files)
        store.goToTab(index: 1)                       // 1-based → .git
        XCTAssertEqual(store.activeTab, .module(.git))

        store.closeModuleTab(.files)                  // close the background tab
        XCTAssertEqual(store.openTabs, [.git])        // .files removed
        XCTAssertEqual(store.activeTab, .module(.git))// active preserved

        store.goToDesktop()
        XCTAssertEqual(store.activeTab, .desktop)

        store.openModuleTab(.git)
        store.closeActiveTab()
        XCTAssertEqual(store.activeTab, .desktop)
    }
}
