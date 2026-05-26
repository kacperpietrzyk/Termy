// RDPInputMapping — engine-agnostic input seam value types and mappers.
//
// M5 Task 6: extracted from the bespoke `RDPSessionDescriptor.swift` during
// the cutover so the post-cutover module no longer mixes input-seam value
// types with deleted bespoke transport code. These types are pure data /
// pure functions: they describe RDP slow-path input events as the views
// produce them and translate macOS-side gestures/keyboard input into the
// `[RDPSlowPathInputEvent]` sequence the engine writes onto the wire.
//
// Consumers are entirely in `Sources/Termy/Views/TerminalStageView.swift`
// (and `Sources/Termy/Stores/TermyStore.swift`'s `handleLocalRDPInputEvents`
// dispatcher). The engine consumer is `FreeRDPSession.sendInputEvents`
// (Task 6), which marshals these into `ctermyrdp_send_key` /
// `ctermyrdp_send_pointer` calls on the C shim.

import Foundation
import TermyCore

public struct RDPPointerFlags: OptionSet, Equatable, Sendable {
    public let rawValue: UInt16

    public static let wheelNegative = RDPPointerFlags(rawValue: 0x0100)
    public static let wheel = RDPPointerFlags(rawValue: 0x0200)
    public static let horizontalWheel = RDPPointerFlags(rawValue: 0x0400)
    public static let move = RDPPointerFlags(rawValue: 0x0800)
    public static let button1 = RDPPointerFlags(rawValue: 0x1000)
    public static let button2 = RDPPointerFlags(rawValue: 0x2000)
    public static let button3 = RDPPointerFlags(rawValue: 0x4000)
    public static let down = RDPPointerFlags(rawValue: 0x8000)

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

public enum RDPSlowPathInputEvent: Equatable, Sendable {
    case keyboard(scancode: UInt16, isDown: Bool, isExtended: Bool)
    case pointer(flags: RDPPointerFlags, x: UInt16, y: UInt16)
}

public enum RDPKeyboardSpecialKey: Equatable, Sendable {
    case enter
    case backspace
    case tab
    case escape
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
}

public enum RDPKeyboardInput: Equatable, Sendable {
    case character(Character)
    case special(RDPKeyboardSpecialKey)
}

public enum RDPKeyboardInputMapper {
    public static func keyPressEvents(_ input: RDPKeyboardInput) -> [RDPSlowPathInputEvent] {
        guard let mapping = keyMapping(for: input) else { return [] }
        var events: [RDPSlowPathInputEvent] = []
        if mapping.requiresShift {
            events.append(.keyboard(scancode: 0x2a, isDown: true, isExtended: false))
        }
        events.append(.keyboard(scancode: mapping.scancode, isDown: true, isExtended: mapping.isExtended))
        events.append(.keyboard(scancode: mapping.scancode, isDown: false, isExtended: mapping.isExtended))
        if mapping.requiresShift {
            events.append(.keyboard(scancode: 0x2a, isDown: false, isExtended: false))
        }
        return events
    }

    private static func keyMapping(for input: RDPKeyboardInput) -> RDPKeyboardMapping? {
        switch input {
        case .special(let key):
            return specialKeyMap[key]
        case .character(let character):
            return printableKeyMap[character]
        }
    }

    private static let specialKeyMap: [RDPKeyboardSpecialKey: RDPKeyboardMapping] = [
        .enter: RDPKeyboardMapping(scancode: 0x1c),
        .backspace: RDPKeyboardMapping(scancode: 0x0e),
        .tab: RDPKeyboardMapping(scancode: 0x0f),
        .escape: RDPKeyboardMapping(scancode: 0x01),
        .upArrow: RDPKeyboardMapping(scancode: 0x48, isExtended: true),
        .downArrow: RDPKeyboardMapping(scancode: 0x50, isExtended: true),
        .leftArrow: RDPKeyboardMapping(scancode: 0x4b, isExtended: true),
        .rightArrow: RDPKeyboardMapping(scancode: 0x4d, isExtended: true)
    ]

    private static let printableKeyMap: [Character: RDPKeyboardMapping] = {
        let base: [(Character, UInt16)] = [
            ("`", 0x29), ("1", 0x02), ("2", 0x03), ("3", 0x04), ("4", 0x05), ("5", 0x06),
            ("6", 0x07), ("7", 0x08), ("8", 0x09), ("9", 0x0a), ("0", 0x0b), ("-", 0x0c),
            ("=", 0x0d), ("q", 0x10), ("w", 0x11), ("e", 0x12), ("r", 0x13), ("t", 0x14),
            ("y", 0x15), ("u", 0x16), ("i", 0x17), ("o", 0x18), ("p", 0x19), ("[", 0x1a),
            ("]", 0x1b), ("a", 0x1e), ("s", 0x1f), ("d", 0x20), ("f", 0x21), ("g", 0x22),
            ("h", 0x23), ("j", 0x24), ("k", 0x25), ("l", 0x26), (";", 0x27), ("'", 0x28),
            ("\\", 0x2b), ("z", 0x2c), ("x", 0x2d), ("c", 0x2e), ("v", 0x2f), ("b", 0x30),
            ("n", 0x31), ("m", 0x32), (",", 0x33), (".", 0x34), ("/", 0x35), (" ", 0x39)
        ]
        let shifted: [(Character, Character)] = [
            ("~", "`"), ("!", "1"), ("@", "2"), ("#", "3"), ("$", "4"), ("%", "5"),
            ("^", "6"), ("&", "7"), ("*", "8"), ("(", "9"), (")", "0"), ("_", "-"),
            ("+", "="), ("{", "["), ("}", "]"), (":", ";"), ("\"", "'"), ("|", "\\"),
            ("<", ","), (">", "."), ("?", "/")
        ]

        var map: [Character: RDPKeyboardMapping] = [:]
        for (character, scancode) in base {
            map[character] = RDPKeyboardMapping(scancode: scancode)
            if character >= "a", character <= "z" {
                map[Character(String(character).uppercased())] = RDPKeyboardMapping(
                    scancode: scancode,
                    requiresShift: true
                )
            }
        }
        for (character, baseCharacter) in shifted {
            if let baseMapping = map[baseCharacter] {
                map[character] = RDPKeyboardMapping(scancode: baseMapping.scancode, requiresShift: true)
            }
        }
        return map
    }()
}

private struct RDPKeyboardMapping: Equatable, Sendable {
    let scancode: UInt16
    var isExtended = false
    var requiresShift = false
}

public struct RDPInputPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct RDPInputViewportSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum RDPPointerButton: Equatable, Sendable {
    case left
    case right
    case middle

    var flag: RDPPointerFlags {
        switch self {
        case .left:
            return .button1
        case .right:
            return .button2
        case .middle:
            return .button3
        }
    }
}

public enum RDPInputEventMapper {
    public static func pointerClickEvents(
        at point: RDPInputPoint,
        viewport: RDPInputViewportSize,
        frame: RDPRemoteDesktopFrame,
        button: RDPPointerButton
    ) -> [RDPSlowPathInputEvent] {
        guard let desktopPoint = desktopPoint(at: point, viewport: viewport, frame: frame) else {
            return []
        }
        let baseFlags: RDPPointerFlags = [.move, button.flag]
        return [
            .pointer(flags: baseFlags.union(.down), x: desktopPoint.x, y: desktopPoint.y),
            .pointer(flags: baseFlags, x: desktopPoint.x, y: desktopPoint.y)
        ]
    }

    private static func desktopPoint(
        at point: RDPInputPoint,
        viewport: RDPInputViewportSize,
        frame: RDPRemoteDesktopFrame
    ) -> (x: UInt16, y: UInt16)? {
        guard frame.width > 0,
              frame.height > 0,
              viewport.width > 0,
              viewport.height > 0 else {
            return nil
        }

        let scale = min(viewport.width / Double(frame.width), viewport.height / Double(frame.height))
        let fittedWidth = Double(frame.width) * scale
        let fittedHeight = Double(frame.height) * scale
        let originX = (viewport.width - fittedWidth) / 2
        let originY = (viewport.height - fittedHeight) / 2
        let relativeX = point.x - originX
        let relativeY = point.y - originY

        guard relativeX >= 0,
              relativeY >= 0,
              relativeX <= fittedWidth,
              relativeY <= fittedHeight else {
            return nil
        }

        let x = UInt16(clamping: Int((relativeX / scale).rounded(.down)))
        let y = UInt16(clamping: Int((relativeY / scale).rounded(.down)))
        return (
            x: min(x, UInt16(clamping: frame.width - 1)),
            y: min(y, UInt16(clamping: frame.height - 1))
        )
    }
}
