import XCTest
@testable import Termy

private final class FakeSurface: PooledSurface {
    private(set) var terminateCount = 0
    func terminateSurface() { terminateCount += 1 }
}

final class TerminalSurfacePoolTests: XCTestCase {
    private func key(_ id: UUID, _ gen: Int) -> String { "\(id.uuidString)#\(gen)" }

    func testStoreAndRetrieveByKey() {
        let pool = TerminalSurfacePool<FakeSurface>()
        let s = FakeSurface()
        let k = key(UUID(), 0)
        pool.store(s, forKey: k)
        XCTAssertTrue(pool.surface(forKey: k) === s)
        XCTAssertEqual(pool.count, 1)
    }

    func testRetrieveMissingKeyReturnsNil() {
        let pool = TerminalSurfacePool<FakeSurface>()
        XCTAssertNil(pool.surface(forKey: key(UUID(), 0)))
    }

    func testTerminateForKeyTerminatesAndEvicts() {
        let pool = TerminalSurfacePool<FakeSurface>()
        let s = FakeSurface()
        let k = key(UUID(), 0)
        pool.store(s, forKey: k)
        pool.terminate(forKey: k)
        XCTAssertEqual(s.terminateCount, 1)
        XCTAssertNil(pool.surface(forKey: k))
        XCTAssertEqual(pool.count, 0)
    }

    func testTerminateForKeyMissingIsNoOp() {
        let pool = TerminalSurfacePool<FakeSurface>()
        pool.terminate(forKey: key(UUID(), 9))   // must not crash
        XCTAssertEqual(pool.count, 0)
    }

    func testTerminateForSessionTerminatesAllGenerationsOnly() {
        let pool = TerminalSurfacePool<FakeSurface>()
        let target = UUID()
        let other = UUID()
        let g0 = FakeSurface(), g1 = FakeSurface(), otherG0 = FakeSurface()
        pool.store(g0, forKey: key(target, 0))
        pool.store(g1, forKey: key(target, 1))
        pool.store(otherG0, forKey: key(other, 0))
        pool.terminate(forSession: target)
        XCTAssertEqual(g0.terminateCount, 1)
        XCTAssertEqual(g1.terminateCount, 1)
        XCTAssertEqual(otherG0.terminateCount, 0)
        XCTAssertNil(pool.surface(forKey: key(target, 0)))
        XCTAssertNil(pool.surface(forKey: key(target, 1)))
        XCTAssertTrue(pool.surface(forKey: key(other, 0)) === otherG0)
        XCTAssertEqual(pool.count, 1)
    }

    func testDrainTerminatesAndEvictsAll() {
        let pool = TerminalSurfacePool<FakeSurface>()
        let a = FakeSurface(), b = FakeSurface()
        pool.store(a, forKey: key(UUID(), 0))
        pool.store(b, forKey: key(UUID(), 0))
        pool.drain()
        XCTAssertEqual(a.terminateCount, 1)
        XCTAssertEqual(b.terminateCount, 1)
        XCTAssertEqual(pool.count, 0)
    }
}
