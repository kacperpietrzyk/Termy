import Foundation

/// One row of the commit graph: the node's column plus the line segments to draw
/// in that row's cell. Pure, derived from each commit's parent hashes — a real
/// multi-lane graph (branches/merges), not a decorative single spine.
public struct GitGraphRow: Equatable, Sendable, Identifiable {
    public var id: String { commit.id }
    public let commit: GitLogEntry
    public let node: Int                       // column of this commit's node
    public let mergeIntoNode: [Int]            // top-edge columns flowing INTO the node
    public let branchFromNode: [Int]           // bottom-edge columns flowing OUT of the node
    public let passThrough: [PassThrough]       // lanes that bypass this commit
    public let laneCount: Int                   // lanes occupied in this row (top∪bottom)

    public struct PassThrough: Equatable, Sendable {
        public let top: Int
        public let bottom: Int
        public init(top: Int, bottom: Int) { self.top = top; self.bottom = bottom }
    }

    public init(commit: GitLogEntry, node: Int, mergeIntoNode: [Int],
                branchFromNode: [Int], passThrough: [PassThrough], laneCount: Int) {
        self.commit = commit
        self.node = node
        self.mergeIntoNode = mergeIntoNode
        self.branchFromNode = branchFromNode
        self.passThrough = passThrough
        self.laneCount = laneCount
    }
}

public struct GitGraphLayout: Equatable, Sendable {
    public let rows: [GitGraphRow]
    public let maxLanes: Int    // global lane ceiling → stable rail width across rows

    public init(rows: [GitGraphRow], maxLanes: Int) {
        self.rows = rows
        self.maxLanes = maxLanes
    }

    /// Assign each commit (newest-first, as `git log` returns them) a lane and
    /// compute the edges connecting it to the rows above/below. Lanes track the
    /// hash each column is currently "waiting for"; a commit sits in the lane
    /// waiting for its hash, then hands that lane to its first parent and opens
    /// lanes for any merge parents. Parents outside the window dangle off the
    /// bottom (harmless).
    public static func compute(_ commits: [GitLogEntry]) -> GitGraphLayout {
        var lanes: [String?] = []   // column → hash it expects next
        var rows: [GitGraphRow] = []
        var maxLanes = 0

        func firstFree() -> Int {
            if let i = lanes.firstIndex(where: { $0 == nil }) { return i }
            lanes.append(nil)
            return lanes.count - 1
        }

        for commit in commits {
            // Column for this commit: an existing lane waiting for it, else a new one.
            let nodeCol: Int
            if let existing = lanes.firstIndex(where: { $0 == commit.hash }) {
                nodeCol = existing
            } else {
                nodeCol = firstFree()
            }
            lanes[nodeCol] = commit.hash

            let before = lanes
            // Every lane currently waiting for this hash converges into the node.
            let mergeIntoNode = before.indices.filter { before[$0] == commit.hash }

            // Free the converged child lanes (the node now owns them); nodeCol is
            // reassigned to the first parent below.
            for i in mergeIntoNode where i != nodeCol { lanes[i] = nil }
            lanes[nodeCol] = nil

            // Place parents and record the bottom columns the node branches to.
            var branchFromNode: [Int] = []
            for (index, parent) in commit.parents.enumerated() {
                if let existing = lanes.firstIndex(where: { $0 == parent }) {
                    branchFromNode.append(existing)          // parent already has a lane → merge edge
                } else if index == 0 {
                    lanes[nodeCol] = parent                  // first parent keeps the node's lane
                    branchFromNode.append(nodeCol)
                } else {
                    let col = firstFree()
                    lanes[col] = parent
                    branchFromNode.append(col)
                }
            }

            // Lanes that bypass this commit: matched top→bottom by hash.
            var passThrough: [GitGraphRow.PassThrough] = []
            for i in before.indices where before[i] != nil && before[i] != commit.hash {
                if let j = lanes.firstIndex(where: { $0 == before[i] }) {
                    passThrough.append(.init(top: i, bottom: j))
                }
            }

            let laneCount = max(before.count, lanes.count)
            maxLanes = max(maxLanes, laneCount)
            rows.append(GitGraphRow(
                commit: commit, node: nodeCol,
                mergeIntoNode: mergeIntoNode.sorted(),
                branchFromNode: branchFromNode.sorted(),
                passThrough: passThrough, laneCount: laneCount
            ))

            // Trim trailing free lanes so width doesn't grow unbounded.
            while let last = lanes.last, last == nil { lanes.removeLast() }
        }

        return GitGraphLayout(rows: rows, maxLanes: max(maxLanes, 1))
    }
}
