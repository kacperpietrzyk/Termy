import XCTest
@testable import Termy

@MainActor
final class SparkleUpdateControllerTests: XCTestCase {
    private final class FakeUpdaterDriver: UpdaterDriving {
        var canCheckForUpdates = true
        var automaticallyChecksForUpdates = false
        private(set) var checkCount = 0
        func checkForUpdates() { checkCount += 1 }
    }

    // activateLiveUpdater() is intentionally not unit-tested: SPUStandardUpdater
    // Controller needs a signed host bundle; it is exercised via the live app
    // (build_and_run --verify) in later M4 tasks.

    func testForwardsCanCheck() {
        let fake = FakeUpdaterDriver()
        fake.canCheckForUpdates = false
        let controller = SparkleUpdateController(driver: fake)
        XCTAssertFalse(controller.canCheckForUpdates)
    }

    func testCheckForUpdatesDelegatesToDriver() {
        let fake = FakeUpdaterDriver()
        let controller = SparkleUpdateController(driver: fake)
        controller.checkForUpdates()
        XCTAssertEqual(fake.checkCount, 1)
    }

    func testAutomaticallyChecksRoundTripsThroughDriverWithNoShadowState() {
        let fake = FakeUpdaterDriver()
        let controller = SparkleUpdateController(driver: fake)
        controller.automaticallyChecksForUpdates = true
        XCTAssertTrue(fake.automaticallyChecksForUpdates)
        fake.automaticallyChecksForUpdates = false
        XCTAssertFalse(controller.automaticallyChecksForUpdates)
    }

    func testDefaultInitUsesHarmlessInMemoryDriver() {
        let controller = SparkleUpdateController()
        XCTAssertTrue(controller.canCheckForUpdates)
        controller.automaticallyChecksForUpdates = true
        XCTAssertTrue(controller.automaticallyChecksForUpdates)
        controller.checkForUpdates()
    }
}
