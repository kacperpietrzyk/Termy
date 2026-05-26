import XCTest
@testable import Termy
import TermyCore

final class WorkspacesModuleModelTests: XCTestCase {
    func testLayoutShapeSinglePane() {
        XCTAssertEqual(WorkspacesModuleModel.layoutShape(.leaf(.terminal)), "single pane")
    }

    func testLayoutShapeSimpleSplit() {
        let tree: WorkspacePaneTree = .split(axis: .horizontal, ratio: 0.5,
                                             first: .leaf(.terminal), second: .leaf(.git))
        XCTAssertEqual(WorkspacesModuleModel.layoutShape(tree), "h")
    }

    func testLayoutShapeTwoChildSplitsSameAxis() {
        let row: WorkspacePaneTree = .split(axis: .horizontal, ratio: 0.5,
                                            first: .leaf(.terminal), second: .leaf(.editor))
        let tree: WorkspacePaneTree = .split(axis: .vertical, ratio: 0.5, first: row, second: row)
        XCTAssertEqual(WorkspacesModuleModel.layoutShape(tree), "v ↳ (h × 2)")
    }

    func testLayoutShapeMixedChildren() {
        // root v-split: one leaf child + one h-split child → "v ↳ mixed"
        let row: WorkspacePaneTree = .split(axis: .horizontal, ratio: 0.5,
                                            first: .leaf(.terminal), second: .leaf(.git))
        let tree: WorkspacePaneTree = .split(axis: .vertical, ratio: 0.5,
                                             first: .leaf(.ai), second: row)
        XCTAssertEqual(WorkspacesModuleModel.layoutShape(tree), "v ↳ mixed")
    }

    func testLeafAndSplitCounts() {
        let row: WorkspacePaneTree = .split(axis: .horizontal, ratio: 0.5,
                                            first: .leaf(.terminal), second: .leaf(.editor))
        let tree: WorkspacePaneTree = .split(axis: .vertical, ratio: 0.5, first: row, second: row)
        XCTAssertEqual(WorkspacesModuleModel.leafCount(tree), 4)
        XCTAssertEqual(WorkspacesModuleModel.splitCount(tree), 3)
    }

    func testAddablePaneKindsExcludesPresent() {
        let addable = WorkspacesModuleModel.addablePaneKinds(present: [.terminal, .git])
        XCTAssertFalse(addable.contains(.terminal))
        XCTAssertFalse(addable.contains(.git))
        XCTAssertTrue(addable.contains(.ai))
        XCTAssertEqual(addable.count, WorkspacePaneKind.allCases.count - 2)
    }

    func testMetaLabelsAndIcons() {
        XCTAssertEqual(WorkspacesModuleModel.meta(for: .git).label, "Git")
        XCTAssertEqual(WorkspacesModuleModel.meta(for: .terminal).label, "Shell")
        XCTAssertEqual(WorkspacesModuleModel.meta(for: .ai).icon, "sparkles")
    }
}
