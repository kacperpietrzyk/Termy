import Foundation

public struct KeymapConflict: Equatable, Sendable {
    public let shortcut: ShortcutDescriptor
    public let actionIDs: [String]

    public init(shortcut: ShortcutDescriptor, actionIDs: [String]) {
        self.shortcut = shortcut
        self.actionIDs = actionIDs
    }
}

public struct ShortcutCheatSheetEntry: Equatable, Identifiable, Sendable {
    public var id: String { actionID }

    public let actionID: String
    public let title: String
    public let subtitle: String
    public let area: ProductArea
    public let shortcut: ShortcutDescriptor
    public let conflictingActionIDs: [String]

    public init(
        actionID: String,
        title: String,
        subtitle: String,
        area: ProductArea,
        shortcut: ShortcutDescriptor,
        conflictingActionIDs: [String] = []
    ) {
        self.actionID = actionID
        self.title = title
        self.subtitle = subtitle
        self.area = area
        self.shortcut = shortcut
        self.conflictingActionIDs = conflictingActionIDs
    }
}

public struct KeymapProfile: Equatable, Sendable {
    public let bindings: [String: ShortcutDescriptor]

    public init(bindings: [String: ShortcutDescriptor] = [:]) {
        self.bindings = bindings
    }

    public static func defaults(for actions: [CommandAction]) -> KeymapProfile {
        KeymapProfile(
            bindings: Dictionary(
                uniqueKeysWithValues: actions.compactMap { action in
                    action.shortcut.map { (action.id, $0) }
                }
            )
        )
    }

    public func shortcut(for action: CommandAction) -> ShortcutDescriptor? {
        bindings[action.id] ?? action.shortcut
    }

    public func apply(to actions: [CommandAction]) -> [CommandAction] {
        actions.map { action in
            CommandAction(
                id: action.id,
                title: action.title,
                subtitle: action.subtitle,
                area: action.area,
                keywords: action.keywords,
                shortcut: shortcut(for: action)
            )
        }
    }

    public func conflicts(in actions: [CommandAction]) -> [KeymapConflict] {
        var actionIDsByShortcut: [ShortcutDescriptor: [String]] = [:]

        for action in actions {
            guard let shortcut = shortcut(for: action) else { continue }
            actionIDsByShortcut[shortcut, default: []].append(action.id)
        }

        return actionIDsByShortcut
            .filter { $0.value.count > 1 }
            .map { KeymapConflict(shortcut: $0.key, actionIDs: $0.value) }
            .sorted { $0.shortcut.storageValue < $1.shortcut.storageValue }
    }

    public func shortcutCheatSheet(for actions: [CommandAction]) -> [ShortcutCheatSheetEntry] {
        let conflictIDsByShortcut = Dictionary(
            uniqueKeysWithValues: conflicts(in: actions).map { ($0.shortcut, $0.actionIDs) }
        )

        return actions.compactMap { action in
            guard let shortcut = shortcut(for: action) else { return nil }
            return ShortcutCheatSheetEntry(
                actionID: action.id,
                title: action.title,
                subtitle: action.subtitle,
                area: action.area,
                shortcut: shortcut,
                conflictingActionIDs: conflictIDsByShortcut[shortcut] ?? []
            )
        }
    }
}

public extension ShortcutDescriptor {
    init?(storageValue: String) {
        let parts = storageValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[1].isEmpty else { return nil }
        switch parts[0] {
        case "command":
            self = .command(parts[1])
        case "commandShift":
            self = .commandShift(parts[1])
        case "commandOption":
            self = .commandOption(parts[1])
        case "controlCommand":
            self = .controlCommand(parts[1])
        default:
            return nil
        }
    }

    var storageValue: String {
        switch self {
        case .command(let key):
            return "command:\(key)"
        case .commandShift(let key):
            return "commandShift:\(key)"
        case .commandOption(let key):
            return "commandOption:\(key)"
        case .controlCommand(let key):
            return "controlCommand:\(key)"
        }
    }
}
