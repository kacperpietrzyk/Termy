import XCTest
@testable import TermyCore

final class GitGraphLayoutTests: XCTestCase {
    private func commit(_ hash: String, parents: [String], subject: String = "x") -> GitLogEntry {
        GitLogEntry(hash: hash, shortHash: String(hash.prefix(7)), parents: parents,
                    refNames: [], author: "a", relativeDate: "now", subject: subject)
    }

    func test_linearHistory_singleLane() {
        // c -> b -> a (each parent is the next commit in the list)
        let layout = GitGraphLayout.compute([
            commit("c", parents: ["b"]),
            commit("b", parents: ["a"]),
            commit("a", parents: []),
        ])
        XCTAssertEqual(layout.maxLanes, 1)
        XCTAssertEqual(layout.rows.map(\.node), [0, 0, 0])
        // Every commit continues straight in lane 0 (merge-in from top + branch-out
        // to bottom on the same column), except the root which has no parent.
        XCTAssertEqual(layout.rows[0].branchFromNode, [0])   // c → b in lane 0
        XCTAssertEqual(layout.rows[1].mergeIntoNode, [0])    // b receives lane 0 from c
        XCTAssertEqual(layout.rows[2].branchFromNode, [])    // root: no parent
        XCTAssertTrue(layout.rows.allSatisfy { $0.passThrough.isEmpty })
    }

    func test_branchAndMerge_usesTwoLanes() {
        // m is a merge of mainline `b` (first parent) and feature `f` (second).
        //   m (parents b, f)
        //   f (parent a)        <- feature commit
        //   b (parent a)        <- mainline commit
        //   a (root)
        let layout = GitGraphLayout.compute([
            commit("m", parents: ["b", "f"]),
            commit("f", parents: ["a"]),
            commit("b", parents: ["a"]),
            commit("a", parents: []),
        ])
        XCTAssertGreaterThanOrEqual(layout.maxLanes, 2, "a merge must open a second lane")

        let m = layout.rows[0]
        XCTAssertEqual(m.node, 0)
        // The merge node branches to two distinct bottom columns (b and f lanes).
        XCTAssertEqual(Set(m.branchFromNode).count, 2, "merge node should fork to two lanes")

        // The two lanes collapse back to the shared ancestor `a`: some row must
        // carry a diagonal — a node whose parent edge lands in a different column
        // (the side branch merging into the mainline lane).
        let hasDiagonal = layout.rows.contains { row in
            row.branchFromNode.contains { $0 != row.node }
                || row.passThrough.contains { $0.top != $0.bottom }
        }
        XCTAssertTrue(hasDiagonal, "branch+merge history must produce a converging diagonal")

        // Final row is the root ancestor `a`, in bounds and with no parent edge.
        let a = layout.rows[3]
        XCTAssertEqual(a.commit.hash, "a")
        XCTAssertEqual(a.branchFromNode, [])
    }

    func test_parentOutsideWindow_doesNotCrash_andDangles() {
        // Only one commit in the window; its parent is not present.
        let layout = GitGraphLayout.compute([commit("z", parents: ["offscreen"])])
        XCTAssertEqual(layout.rows.count, 1)
        XCTAssertEqual(layout.rows[0].node, 0)
        XCTAssertEqual(layout.rows[0].branchFromNode, [0])   // lane continues off the bottom
    }

    func test_empty() {
        let layout = GitGraphLayout.compute([])
        XCTAssertTrue(layout.rows.isEmpty)
        XCTAssertEqual(layout.maxLanes, 1)
    }

    func test_node_alwaysWithinLaneCount() {
        let layout = GitGraphLayout.compute([
            commit("m", parents: ["b", "f"]),
            commit("f", parents: ["a"]),
            commit("b", parents: ["a"]),
            commit("a", parents: []),
        ])
        for row in layout.rows {
            XCTAssertLessThan(row.node, max(row.laneCount, 1))
            XCTAssertLessThanOrEqual(row.laneCount, layout.maxLanes)
        }
    }
}
