import XCTest
@testable import Termy
import TermyCore

@MainActor
final class ShellNavigationModelTests: XCTestCase {
    func testStartsOnHome() {
        let nav = ShellNavigationModel()
        XCTAssertEqual(nav.activeTab, .home)
        XCTAssertNil(nav.activeModule)
    }

    func testOpenActivatesModule() {
        let nav = ShellNavigationModel()
        nav.open(.git)
        XCTAssertEqual(nav.activeTab, .module(.git))
        XCTAssertEqual(nav.activeModule, .git)
    }

    func testGoHomeReturnsToHome() {
        let nav = ShellNavigationModel()
        nav.open(.git)
        nav.goHome()
        XCTAssertEqual(nav.activeTab, .home)
        XCTAssertNil(nav.activeModule)
    }

    func testModuleAtIsOneBasedFixedRailOrder() {
        let nav = ShellNavigationModel()
        XCTAssertEqual(nav.module(at: 1), .shell)     // fixed rail order, not insertion order
        XCTAssertEqual(nav.module(at: 2), .agents)
        XCTAssertEqual(nav.module(at: 8), .settings)
        XCTAssertNil(nav.module(at: 9))
        XCTAssertNil(nav.module(at: 0))
    }

    func testActiveTabKey() {
        let nav = ShellNavigationModel()
        XCTAssertEqual(nav.activeTabKey, "home")
        nav.open(.files)
        XCTAssertEqual(nav.activeTabKey, "files")
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
        XCTAssertEqual(store.activeTab, .home)
        XCTAssertNil(store.activeModule)

        store.openModuleTab(.git)
        XCTAssertEqual(store.activeTab, .module(.git))
        XCTAssertEqual(store.activeModule, .git)
        XCTAssertEqual(store.activeTabKey, "git")

        store.goToTab(index: 1)                        // 1-based fixed rail → .shell
        XCTAssertEqual(store.activeTab, .module(.shell))

        store.goToHome()
        XCTAssertEqual(store.activeTab, .home)
    }
}
