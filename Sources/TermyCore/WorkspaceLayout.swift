import Foundation

public struct WorkspaceLayout: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let sessionProfileIDs: [String]
    public let activeSessionProfileID: String?
    public let panelIDs: [String]
    public let splitRatio: Double
    public let paneTree: WorkspacePaneTree?

    public init(
        id: String,
        name: String,
        sessionProfileIDs: [String],
        activeSessionProfileID: String?,
        panelIDs: [String],
        splitRatio: Double,
        paneTree: WorkspacePaneTree? = nil
    ) {
        self.id = id
        self.name = name
        self.sessionProfileIDs = sessionProfileIDs
        self.activeSessionProfileID = activeSessionProfileID
        self.panelIDs = panelIDs
        self.splitRatio = min(0.85, max(0.15, splitRatio))
        self.paneTree = paneTree
    }
}

public struct WorkspaceStore: Equatable, Sendable {
    public private(set) var layouts: [WorkspaceLayout]

    public init(layouts: [WorkspaceLayout] = []) {
        self.layouts = layouts
    }

    public mutating func save(_ layout: WorkspaceLayout) {
        if let index = layouts.firstIndex(where: { $0.id == layout.id }) {
            layouts[index] = layout
        } else {
            layouts.append(layout)
        }
        layouts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func restore(id: String) -> WorkspaceLayout? {
        layouts.first { $0.id == id }
    }
}

public enum WorkspacePaneKind: String, CaseIterable, Equatable, Sendable {
    case terminal
    case ai
    case files
    case git
    case editor
    case rdp
}

public enum WorkspaceSplitEdge: Equatable, Sendable {
    case leading
    case trailing
    case top
    case bottom
}

public enum WorkspaceSplitAxis: Equatable, Sendable {
    case horizontal
    case vertical
}

public enum WorkspacePaneTreeBranch: Equatable, Sendable {
    case first
    case second
}

public indirect enum WorkspacePaneTree: Equatable, Sendable {
    case leaf(WorkspacePaneKind)
    case split(axis: WorkspaceSplitAxis, ratio: Double, first: WorkspacePaneTree, second: WorkspacePaneTree)

    public init?(storageValue: String) {
        var parser = WorkspacePaneTreeStorageParser(storageValue.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let tree = parser.parseTree(), parser.isAtEnd else {
            return nil
        }
        self = tree
    }

    public var panes: [WorkspacePaneKind] {
        switch self {
        case let .leaf(pane):
            return [pane]
        case let .split(_, _, first, second):
            return first.panes + second.panes
        }
    }

    public var storageValue: String {
        switch self {
        case let .leaf(pane):
            return pane.rawValue
        case let .split(axis, ratio, first, second):
            let prefix = axis == .horizontal ? "h" : "v"
            return "\(prefix):\(WorkspacePaneTree.formatRatio(ratio))(\(first.storageValue)|\(second.storageValue))"
        }
    }

    fileprivate func contains(_ pane: WorkspacePaneKind) -> Bool {
        panes.contains(pane)
    }

    private static func formatRatio(_ ratio: Double) -> String {
        let percentage = Int((ratio * 100).rounded())
        let whole = percentage / 100
        let fraction = abs(percentage % 100)
        return "\(whole).\(fraction < 10 ? "0" : "")\(fraction)"
    }
}

private struct WorkspacePaneTreeStorageParser {
    private let text: String
    private var index: String.Index

    init(_ text: String) {
        self.text = text
        self.index = text.startIndex
    }

    var isAtEnd: Bool {
        index == text.endIndex
    }

    mutating func parseTree() -> WorkspacePaneTree? {
        if let split = parseSplit() {
            return split
        }
        return parseLeaf()
    }

    private mutating func parseSplit() -> WorkspacePaneTree? {
        let start = index
        guard let axis = parseAxis(),
              consume(":"),
              let ratio = parseRatio(),
              consume("("),
              let first = parseTree(),
              consume("|"),
              let second = parseTree(),
              consume(")") else {
            index = start
            return nil
        }
        return .split(axis: axis, ratio: ratio, first: first, second: second)
    }

    private mutating func parseAxis() -> WorkspaceSplitAxis? {
        guard index < text.endIndex else { return nil }
        switch text[index] {
        case "h":
            index = text.index(after: index)
            return .horizontal
        case "v":
            index = text.index(after: index)
            return .vertical
        default:
            return nil
        }
    }

    private mutating func parseRatio() -> Double? {
        let start = index
        while index < text.endIndex {
            let character = text[index]
            guard character.isNumber || character == "." else { break }
            index = text.index(after: index)
        }
        guard start != index,
              let ratio = Double(text[start..<index]),
              ratio > 0,
              ratio < 1 else {
            index = start
            return nil
        }
        return ratio
    }

    private mutating func parseLeaf() -> WorkspacePaneTree? {
        let start = index
        while index < text.endIndex {
            let character = text[index]
            guard character.isLetter else { break }
            index = text.index(after: index)
        }
        guard start != index,
              let pane = WorkspacePaneKind(rawValue: String(text[start..<index])) else {
            index = start
            return nil
        }
        return .leaf(pane)
    }

    private mutating func consume(_ character: Character) -> Bool {
        guard index < text.endIndex, text[index] == character else {
            return false
        }
        index = text.index(after: index)
        return true
    }
}

public struct WorkspacePaneRenderPlan: Equatable, Sendable {
    public let root: WorkspacePaneTree
    public let focusedPane: WorkspacePaneKind

    public init(root: WorkspacePaneTree, focusedPane: WorkspacePaneKind) {
        self.root = root
        self.focusedPane = root.contains(focusedPane) ? focusedPane : root.panes.first ?? .terminal
    }

    public var leafPanes: [WorkspacePaneKind] {
        root.panes
    }
}

public struct WorkspacePaneLayout: Equatable, Sendable {
    public private(set) var leadingPane: WorkspacePaneKind?
    public private(set) var trailingPane: WorkspacePaneKind?
    public private(set) var topPane: WorkspacePaneKind?
    public private(set) var bottomPane: WorkspacePaneKind?
    public private(set) var paneTree: WorkspacePaneTree
    public private(set) var focusedPane: WorkspacePaneKind
    public private(set) var leadingRatio: Double
    public private(set) var trailingRatio: Double
    public private(set) var topRatio: Double
    public private(set) var bottomRatio: Double

    public init(
        leadingPane: WorkspacePaneKind? = nil,
        trailingPane: WorkspacePaneKind? = nil,
        topPane: WorkspacePaneKind? = nil,
        bottomPane: WorkspacePaneKind? = nil,
        focusedPane: WorkspacePaneKind = .terminal,
        leadingRatio: Double = 0.24,
        trailingRatio: Double = 0.34,
        topRatio: Double = 0.24,
        bottomRatio: Double = 0.30
    ) {
        self.leadingPane = leadingPane
        self.trailingPane = trailingPane
        self.topPane = topPane
        self.bottomPane = bottomPane
        self.focusedPane = focusedPane
        self.leadingRatio = WorkspacePaneLayout.clamp(leadingRatio, min: 0.18, max: 0.45)
        self.trailingRatio = WorkspacePaneLayout.clamp(trailingRatio, min: 0.25, max: 0.75)
        self.topRatio = WorkspacePaneLayout.clamp(topRatio, min: 0.15, max: 0.45)
        self.bottomRatio = WorkspacePaneLayout.clamp(bottomRatio, min: 0.20, max: 0.65)
        self.paneTree = WorkspacePaneLayout.initialTree(
            leadingPane: leadingPane,
            trailingPane: trailingPane,
            topPane: topPane,
            bottomPane: bottomPane,
            leadingRatio: self.leadingRatio,
            trailingRatio: self.trailingRatio,
            topRatio: self.topRatio,
            bottomRatio: self.bottomRatio
        )
    }

    public init(paneTree: WorkspacePaneTree, focusedPane: WorkspacePaneKind = .terminal) {
        self.leadingPane = nil
        self.trailingPane = nil
        self.topPane = nil
        self.bottomPane = nil
        self.paneTree = paneTree
        self.focusedPane = paneTree.contains(focusedPane) ? focusedPane : paneTree.panes.first ?? .terminal
        self.leadingRatio = 0.24
        self.trailingRatio = 0.34
        self.topRatio = 0.24
        self.bottomRatio = 0.30
    }

    public var visiblePanes: [WorkspacePaneKind] {
        paneTree.panes
    }

    public var renderPlan: WorkspacePaneRenderPlan {
        WorkspacePaneRenderPlan(root: paneTree, focusedPane: focusedPane)
    }

    public mutating func split(_ pane: WorkspacePaneKind, edge: WorkspaceSplitEdge) {
        guard pane != .terminal else {
            focusedPane = .terminal
            return
        }

        switch edge {
        case .leading:
            leadingPane = pane
        case .trailing:
            trailingPane = pane
        case .top:
            topPane = pane
        case .bottom:
            bottomPane = pane
        }
        paneTree = WorkspacePaneLayout.splitTree(paneTree, focusedPane: focusedPane, newPane: pane, edge: edge)
        focusedPane = pane
    }

    public mutating func resizeFocusedPane(by delta: Double) {
        if focusedPane == leadingPane {
            leadingRatio = WorkspacePaneLayout.clamp(leadingRatio + delta, min: 0.18, max: 0.45)
        } else if focusedPane == trailingPane {
            trailingRatio = WorkspacePaneLayout.clamp(trailingRatio + delta, min: 0.25, max: 0.75)
        } else if focusedPane == topPane {
            topRatio = WorkspacePaneLayout.clamp(topRatio + delta, min: 0.15, max: 0.45)
        } else if focusedPane == bottomPane {
            bottomRatio = WorkspacePaneLayout.clamp(bottomRatio + delta, min: 0.20, max: 0.65)
        }
        paneTree = WorkspacePaneLayout.resizeTree(paneTree, focusedPane: focusedPane, delta: delta)
    }

    public mutating func resizeSplit(
        at path: [WorkspacePaneTreeBranch],
        byDraggingPixels pixels: Double,
        inContainerLength containerLength: Double
    ) {
        guard containerLength > 0 else { return }
        let delta = pixels / containerLength
        paneTree = WorkspacePaneLayout.resizeSplitTree(paneTree, path: path, delta: delta)
    }

    public mutating func focusNextPane() {
        let panes = visiblePanes
        guard let index = panes.firstIndex(of: focusedPane) else {
            focusedPane = .terminal
            return
        }
        focusedPane = panes[(index + 1) % panes.count]
    }

    /// Focus a specific pane kind directly (no-op if it isn't visible). Used by
    /// the Workspaces viz where a pane is clicked, vs. the cycling focusNextPane.
    public mutating func focus(_ pane: WorkspacePaneKind) {
        guard paneTree.panes.contains(pane) else { return }
        focusedPane = pane
    }

    /// Close a specific pane kind directly (focus then close). Closing the base
    /// `.terminal` pane is a no-op, matching closeFocusedPane.
    public mutating func close(_ pane: WorkspacePaneKind) {
        guard paneTree.panes.contains(pane) else { return }
        focus(pane)
        closeFocusedPane()
    }

    public mutating func closeFocusedPane() {
        let paneToClose = focusedPane
        guard paneToClose != .terminal else {
            focusedPane = .terminal
            return
        }

        if paneToClose == leadingPane {
            leadingPane = nil
        } else if paneToClose == trailingPane {
            trailingPane = nil
        } else if paneToClose == topPane {
            topPane = nil
        } else if paneToClose == bottomPane {
            bottomPane = nil
        }
        paneTree = WorkspacePaneLayout.removing(paneToClose, from: paneTree) ?? .leaf(.terminal)
        focusedPane = visiblePanes.first ?? .terminal
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(max, Swift.max(min, value))
    }

    private static func initialTree(
        leadingPane: WorkspacePaneKind?,
        trailingPane: WorkspacePaneKind?,
        topPane: WorkspacePaneKind?,
        bottomPane: WorkspacePaneKind?,
        leadingRatio: Double,
        trailingRatio: Double,
        topRatio: Double,
        bottomRatio: Double
    ) -> WorkspacePaneTree {
        var tree: WorkspacePaneTree = .leaf(.terminal)
        if let leadingPane {
            tree = .split(axis: .horizontal, ratio: leadingRatio, first: .leaf(leadingPane), second: tree)
        }
        if let trailingPane {
            tree = .split(axis: .horizontal, ratio: trailingRatio, first: tree, second: .leaf(trailingPane))
        }
        if let topPane {
            tree = .split(axis: .vertical, ratio: topRatio, first: .leaf(topPane), second: tree)
        }
        if let bottomPane {
            tree = .split(axis: .vertical, ratio: bottomRatio, first: tree, second: .leaf(bottomPane))
        }
        return tree
    }

    private static func splitTree(
        _ tree: WorkspacePaneTree,
        focusedPane: WorkspacePaneKind,
        newPane: WorkspacePaneKind,
        edge: WorkspaceSplitEdge
    ) -> WorkspacePaneTree {
        switch tree {
        case let .leaf(pane):
            guard pane == focusedPane else { return tree }
            let axis: WorkspaceSplitAxis = edge == .leading || edge == .trailing ? .horizontal : .vertical
            let ratio = defaultRatio(for: edge)
            switch edge {
            case .leading, .top:
                return .split(axis: axis, ratio: ratio, first: .leaf(newPane), second: .leaf(pane))
            case .trailing, .bottom:
                return .split(axis: axis, ratio: ratio, first: .leaf(pane), second: .leaf(newPane))
            }
        case let .split(axis, ratio, first, second):
            if first.contains(focusedPane) {
                return .split(
                    axis: axis,
                    ratio: ratio,
                    first: splitTree(first, focusedPane: focusedPane, newPane: newPane, edge: edge),
                    second: second
                )
            }
            if second.contains(focusedPane) {
                return .split(
                    axis: axis,
                    ratio: ratio,
                    first: first,
                    second: splitTree(second, focusedPane: focusedPane, newPane: newPane, edge: edge)
                )
            }
            return tree
        }
    }

    private static func resizeTree(
        _ tree: WorkspacePaneTree,
        focusedPane: WorkspacePaneKind,
        delta: Double
    ) -> WorkspacePaneTree {
        switch tree {
        case .leaf:
            return tree
        case let .split(axis, ratio, first, second):
            if first.contains(focusedPane) {
                if firstIsLeaf(first, focusedPane: focusedPane) {
                    return .split(axis: axis, ratio: normalizedRatio(clamp(ratio + delta, min: 0.15, max: 0.85)), first: first, second: second)
                }
                return .split(axis: axis, ratio: ratio, first: resizeTree(first, focusedPane: focusedPane, delta: delta), second: second)
            }
            if second.contains(focusedPane) {
                if firstIsLeaf(second, focusedPane: focusedPane) {
                    return .split(axis: axis, ratio: normalizedRatio(clamp(ratio + delta, min: 0.15, max: 0.85)), first: first, second: second)
                }
                return .split(axis: axis, ratio: ratio, first: first, second: resizeTree(second, focusedPane: focusedPane, delta: delta))
            }
            return tree
        }
    }

    private static func resizeSplitTree(
        _ tree: WorkspacePaneTree,
        path: [WorkspacePaneTreeBranch],
        delta: Double
    ) -> WorkspacePaneTree {
        switch tree {
        case .leaf:
            return tree
        case let .split(axis, ratio, first, second):
            guard let branch = path.first else {
                return .split(
                    axis: axis,
                    ratio: normalizedRatio(clamp(ratio + delta, min: 0.15, max: 0.85)),
                    first: first,
                    second: second
                )
            }
            let remainingPath = Array(path.dropFirst())
            switch branch {
            case .first:
                return .split(
                    axis: axis,
                    ratio: ratio,
                    first: resizeSplitTree(first, path: remainingPath, delta: delta),
                    second: second
                )
            case .second:
                return .split(
                    axis: axis,
                    ratio: ratio,
                    first: first,
                    second: resizeSplitTree(second, path: remainingPath, delta: delta)
                )
            }
        }
    }

    private static func removing(_ pane: WorkspacePaneKind, from tree: WorkspacePaneTree) -> WorkspacePaneTree? {
        switch tree {
        case let .leaf(current):
            return current == pane ? nil : tree
        case let .split(_, _, first, second):
            let updatedFirst = removing(pane, from: first)
            let updatedSecond = removing(pane, from: second)
            switch (updatedFirst, updatedSecond) {
            case let (.some(first), .some(second)):
                return .split(axis: axis(of: tree), ratio: ratio(of: tree), first: first, second: second)
            case let (.some(first), .none):
                return first
            case let (.none, .some(second)):
                return second
            case (.none, .none):
                return nil
            }
        }
    }

    private static func axis(of tree: WorkspacePaneTree) -> WorkspaceSplitAxis {
        guard case let .split(axis, _, _, _) = tree else {
            return .horizontal
        }
        return axis
    }

    private static func ratio(of tree: WorkspacePaneTree) -> Double {
        guard case let .split(_, ratio, _, _) = tree else {
            return 0.5
        }
        return ratio
    }

    private static func firstIsLeaf(_ tree: WorkspacePaneTree, focusedPane: WorkspacePaneKind) -> Bool {
        tree == .leaf(focusedPane)
    }

    private static func defaultRatio(for edge: WorkspaceSplitEdge) -> Double {
        switch edge {
        case .leading:
            return 0.24
        case .trailing:
            return 0.34
        case .top:
            return 0.24
        case .bottom:
            return 0.30
        }
    }

    private static func normalizedRatio(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
