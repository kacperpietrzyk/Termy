import Foundation

public enum TerminalANSIColor: Equatable, Sendable {
    case standardColor(Int)
    case trueColor(red: Int, green: Int, blue: Int)
}

public typealias TerminalANSIForeground = TerminalANSIColor

public enum TerminalANSIStyle: Equatable, Sendable {
    case plain
    case standardColor(Int)
    case trueColor(red: Int, green: Int, blue: Int)
    case styled(
        foreground: TerminalANSIColor?,
        background: TerminalANSIColor?,
        isBold: Bool,
        isUnderlined: Bool,
        isInverted: Bool,
        isDim: Bool = false,
        isItalic: Bool = false,
        isStrikethrough: Bool = false,
        isConcealed: Bool = false,
        isBlinking: Bool = false,
        isOverlined: Bool = false
    )
}

public extension TerminalANSIStyle {
    var foreground: TerminalANSIColor? {
        components.foreground
    }

    var background: TerminalANSIColor? {
        components.background
    }

    var isBold: Bool {
        components.isBold
    }

    var isDim: Bool {
        components.isDim
    }

    var isUnderlined: Bool {
        components.isUnderlined
    }

    var isInverted: Bool {
        components.isInverted
    }

    var isItalic: Bool {
        components.isItalic
    }

    var isStrikethrough: Bool {
        components.isStrikethrough
    }

    var isConcealed: Bool {
        components.isConcealed
    }

    var isBlinking: Bool {
        components.isBlinking
    }

    var isOverlined: Bool {
        components.isOverlined
    }

    var components: (
        foreground: TerminalANSIColor?,
        background: TerminalANSIColor?,
        isBold: Bool,
        isUnderlined: Bool,
        isInverted: Bool,
        isDim: Bool,
        isItalic: Bool,
        isStrikethrough: Bool,
        isConcealed: Bool,
        isBlinking: Bool,
        isOverlined: Bool
    ) {
        switch self {
        case .plain:
            return (nil, nil, false, false, false, false, false, false, false, false, false)
        case .standardColor(let code):
            return (.standardColor(code), nil, false, false, false, false, false, false, false, false, false)
        case .trueColor(let red, let green, let blue):
            return (.trueColor(red: red, green: green, blue: blue), nil, false, false, false, false, false, false, false, false, false)
        case .styled(
            let foreground,
            let background,
            let isBold,
            let isUnderlined,
            let isInverted,
            let isDim,
            let isItalic,
            let isStrikethrough,
            let isConcealed,
            let isBlinking,
            let isOverlined
        ):
            return (foreground, background, isBold, isUnderlined, isInverted, isDim, isItalic, isStrikethrough, isConcealed, isBlinking, isOverlined)
        }
    }

    static func from(
        foreground: TerminalANSIColor?,
        background: TerminalANSIColor?,
        isBold: Bool,
        isUnderlined: Bool,
        isInverted: Bool,
        isDim: Bool = false,
        isItalic: Bool = false,
        isStrikethrough: Bool = false,
        isConcealed: Bool = false,
        isBlinking: Bool = false,
        isOverlined: Bool = false
    ) -> TerminalANSIStyle {
        guard background == nil, !isBold, !isUnderlined, !isInverted, !isDim, !isItalic, !isStrikethrough, !isConcealed, !isBlinking, !isOverlined else {
            return .styled(
                foreground: foreground,
                background: background,
                isBold: isBold,
                isUnderlined: isUnderlined,
                isInverted: isInverted,
                isDim: isDim,
                isItalic: isItalic,
                isStrikethrough: isStrikethrough,
                isConcealed: isConcealed,
                isBlinking: isBlinking,
                isOverlined: isOverlined
            )
        }

        switch foreground {
        case .none:
            return .plain
        case .standardColor(let code):
            return .standardColor(code)
        case .trueColor(let red, let green, let blue):
            return .trueColor(red: red, green: green, blue: blue)
        }
    }
}

public struct TerminalANSIRun: Equatable, Sendable {
    public let text: String
    public let style: TerminalANSIStyle

    public init(text: String, style: TerminalANSIStyle) {
        self.text = text
        self.style = style
    }
}

public struct TerminalANSIParser: Sendable {
    public init() {}

    public func parse(_ text: String) -> [TerminalANSIRun] {
        var runs: [TerminalANSIRun] = []
        var buffer = ""
        var style = TerminalANSIStyle.plain
        var isG0DECSpecialGraphicsEnabled = false
        var isG1DECSpecialGraphicsEnabled = false
        var usesG1CharacterSet = false
        var index = text.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            if let last = runs.last, last.style == style {
                runs[runs.count - 1] = TerminalANSIRun(text: last.text + buffer, style: style)
            } else {
                runs.append(TerminalANSIRun(text: buffer, style: style))
            }
            buffer = ""
        }

        while index < text.endIndex {
            if isCSIStart(text[index]),
               let parsed = parseEscape(in: text, from: index) {
                flush()
                style = applySGR(parsed.parameters, to: style)
                index = parsed.endIndex
            } else if isOSCStart(text[index]),
                      let endIndex = parseOSC(in: text, from: index) {
                index = endIndex
            } else if isStringControlStart(text[index]),
                      let endIndex = parseStringControl(in: text, from: index) {
                index = endIndex
            } else if isCSIStart(text[index]),
                      let endIndex = parseCSI(in: text, from: index) {
                index = endIndex
            } else if let designation = parseCharsetDesignation(in: text, from: index) {
                if designation.slot == "(" {
                    isG0DECSpecialGraphicsEnabled = designation.final == "0"
                } else if designation.slot == ")" {
                    isG1DECSpecialGraphicsEnabled = designation.final == "0"
                }
                index = designation.endIndex
            } else if text[index] == "\u{001B}",
                      let endIndex = parseSimpleEscape(in: text, from: index) {
                index = endIndex
            } else if text[index] == "\u{000E}" {
                usesG1CharacterSet = true
                index = text.index(after: index)
            } else if text[index] == "\u{000F}" {
                usesG1CharacterSet = false
                index = text.index(after: index)
            } else if isNonPrintingC1Control(text[index]) {
                index = text.index(after: index)
            } else if isNonPrintingC0Control(text[index]) {
                index = text.index(after: index)
            } else {
                let useDECSpecialGraphics = usesG1CharacterSet
                    ? isG1DECSpecialGraphicsEnabled
                    : isG0DECSpecialGraphicsEnabled
                buffer.append(translatePrintableCharacter(text[index], useDECSpecialGraphics: useDECSpecialGraphics))
                index = text.index(after: index)
            }
        }
        flush()
        return runs
    }

    private func parseEscape(in text: String, from start: String.Index) -> (parameters: [Int], endIndex: String.Index)? {
        guard var index = csiParameterStart(in: text, from: start) else { return nil }

        let parametersStart = index
        while index < text.endIndex, text[index] != "m" {
            guard text[index].isNumber || text[index] == ";" || text[index] == ":" else { return nil }
            index = text.index(after: index)
        }
        guard index < text.endIndex else { return nil }

        let raw = String(text[parametersStart..<index])
        let parameters = normalizedSGRParameters(from: raw)
        return (parameters, text.index(after: index))
    }

    private func normalizedSGRParameters(from raw: String) -> [Int] {
        guard !raw.isEmpty else { return [0] }

        var parameters: [Int] = []
        for segment in raw.split(separator: ";", omittingEmptySubsequences: false).map(String.init) {
            let parts = segment.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) ?? 0 }

            if (parts.first == 38 || parts.first == 48),
               parts.count >= 6,
               parts[1] == 2 {
                parameters.append(contentsOf: [parts[0], parts[1], parts[3], parts[4], parts[5]])
            } else if parts.first == 4, parts.count > 1 {
                switch parts[1] {
                case 0:
                    parameters.append(24)
                default:
                    parameters.append(4)
                }
            } else {
                parameters.append(contentsOf: parts)
            }
        }
        return parameters
    }

    private func parseOSC(in text: String, from start: String.Index) -> String.Index? {
        var index: String.Index
        if text[start] == "\u{009D}" {
            index = text.index(after: start)
        } else {
            index = text.index(after: start)
            guard index < text.endIndex, text[index] == "]" else { return nil }
            index = text.index(after: index)
        }

        while index < text.endIndex {
            if text[index] == "\u{0007}" {
                return text.index(after: index)
            }
            if text[index] == "\u{009C}" {
                return text.index(after: index)
            }

            if text[index] == "\u{001B}" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\\" {
                    return text.index(after: nextIndex)
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    private func parseStringControl(in text: String, from start: String.Index) -> String.Index? {
        var index: String.Index
        if isC1StringControlStart(text[start]) {
            index = text.index(after: start)
        } else {
            index = text.index(after: start)
            guard index < text.endIndex else { return nil }
            guard text[index] == "P" || text[index] == "_" || text[index] == "^" || text[index] == "X" else {
                return nil
            }
            index = text.index(after: index)
        }

        while index < text.endIndex {
            if text[index] == "\u{009C}" {
                return text.index(after: index)
            }

            if text[index] == "\u{001B}" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\\" {
                    return text.index(after: nextIndex)
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    private func parseCSI(in text: String, from start: String.Index) -> String.Index? {
        guard var index = csiParameterStart(in: text, from: start) else { return nil }

        while index < text.endIndex {
            guard let value = asciiValue(of: text[index]) else { return nil }
            if (0x40...0x7E).contains(value) {
                return text.index(after: index)
            }
            guard (0x20...0x3F).contains(value) else { return nil }
            index = text.index(after: index)
        }

        return nil
    }

    private func parseCharsetDesignation(in text: String, from start: String.Index) -> (slot: Character, final: Character, endIndex: String.Index)? {
        guard text[start] == "\u{001B}" else { return nil }

        let commandIndex = text.index(after: start)
        guard commandIndex < text.endIndex else { return nil }
        guard text[commandIndex] == "(" || text[commandIndex] == ")" else { return nil }

        let finalIndex = text.index(after: commandIndex)
        guard finalIndex < text.endIndex else { return nil }
        return (text[commandIndex], text[finalIndex], text.index(after: finalIndex))
    }

    private func csiParameterStart(in text: String, from start: String.Index) -> String.Index? {
        guard text[start] != "\u{009B}" else {
            return text.index(after: start)
        }

        let index = text.index(after: start)
        guard index < text.endIndex, text[index] == "[" else { return nil }
        return text.index(after: index)
    }

    private func parseSimpleEscape(in text: String, from start: String.Index) -> String.Index? {
        let commandIndex = text.index(after: start)
        guard commandIndex < text.endIndex else { return nil }

        switch text[commandIndex] {
        case "6", "7", "8", "9", "=", ">", "D", "E", "H", "M", "N", "O", "V", "W", "c":
            return text.index(after: commandIndex)
        case "(", ")", "*", "+", "-", ".", "/", "#", "%", " ":
            let finalIndex = text.index(after: commandIndex)
            guard finalIndex < text.endIndex else { return nil }
            return text.index(after: finalIndex)
        default:
            return nil
        }
    }

    private func isNonPrintingC0Control(_ character: Character) -> Bool {
        character == "\u{0000}"
            || character == "\u{0001}"
            || character == "\u{0005}"
            || character == "\u{0006}"
            || character == "\u{0007}"
            || character == "\u{000B}"
            || character == "\u{000C}"
            || character == "\u{000E}"
            || character == "\u{000F}"
            || character == "\u{0010}"
            || character == "\u{0011}"
            || character == "\u{0013}"
            || character == "\u{0018}"
            || character == "\u{0019}"
            || character == "\u{001A}"
            || character == "\u{001C}"
            || character == "\u{001D}"
            || character == "\u{001E}"
            || character == "\u{001F}"
    }

    private func isNonPrintingC1Control(_ character: Character) -> Bool {
        character == "\u{0080}"
            || character == "\u{0081}"
            || character == "\u{0082}"
            || character == "\u{0083}"
            || character == "\u{0084}"
            || character == "\u{0085}"
            || character == "\u{0086}"
            || character == "\u{0087}"
            || character == "\u{0088}"
            || character == "\u{0089}"
            || character == "\u{008A}"
            || character == "\u{008B}"
            || character == "\u{008C}"
            || character == "\u{008D}"
            || character == "\u{008E}"
            || character == "\u{008F}"
            || character == "\u{0091}"
            || character == "\u{0092}"
            || character == "\u{0093}"
            || character == "\u{0094}"
            || character == "\u{0095}"
            || character == "\u{0096}"
            || character == "\u{0097}"
            || character == "\u{0099}"
            || character == "\u{009A}"
            || character == "\u{009C}"
    }

    private func isCSIStart(_ character: Character) -> Bool {
        character == "\u{001B}" || character == "\u{009B}"
    }

    private func isOSCStart(_ character: Character) -> Bool {
        character == "\u{001B}" || character == "\u{009D}"
    }

    private func isStringControlStart(_ character: Character) -> Bool {
        character == "\u{001B}" || isC1StringControlStart(character)
    }

    private func isC1StringControlStart(_ character: Character) -> Bool {
        character == "\u{0090}" || character == "\u{009F}" || character == "\u{009E}" || character == "\u{0098}"
    }

    private func translatePrintableCharacter(_ character: Character, useDECSpecialGraphics: Bool) -> Character {
        guard useDECSpecialGraphics else { return character }
        return TerminalDECSpecialGraphics.map(character)
    }

    private func asciiValue(of character: Character) -> UInt32? {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else { return nil }
        guard scalar.value <= 0x7F else { return nil }
        return scalar.value
    }

    private func applySGR(_ parameters: [Int], to current: TerminalANSIStyle) -> TerminalANSIStyle {
        var index = 0
        var components = current.components

        while index < parameters.count {
            let parameter = parameters[index]
            switch parameter {
            case 0:
                components = (nil, nil, false, false, false, false, false, false, false, false, false)
                index += 1
            case 1:
                components.isBold = true
                index += 1
            case 2:
                components.isDim = true
                index += 1
            case 3:
                components.isItalic = true
                index += 1
            case 4:
                components.isUnderlined = true
                index += 1
            case 5:
                components.isBlinking = true
                index += 1
            case 7:
                components.isInverted = true
                index += 1
            case 8:
                components.isConcealed = true
                index += 1
            case 9:
                components.isStrikethrough = true
                index += 1
            case 21:
                components.isUnderlined = true
                index += 1
            case 22:
                components.isBold = false
                components.isDim = false
                index += 1
            case 23:
                components.isItalic = false
                index += 1
            case 24:
                components.isUnderlined = false
                index += 1
            case 25:
                components.isBlinking = false
                index += 1
            case 27:
                components.isInverted = false
                index += 1
            case 28:
                components.isConcealed = false
                index += 1
            case 29:
                components.isStrikethrough = false
                index += 1
            case 53:
                components.isOverlined = true
                index += 1
            case 55:
                components.isOverlined = false
                index += 1
            case 39:
                components.foreground = nil
                index += 1
            case 40...47, 100...107:
                components.background = .standardColor(parameter)
                index += 1
            case 49:
                components.background = nil
                index += 1
            case 30...37, 90...97:
                components.foreground = .standardColor(parameter)
                index += 1
            case 38 where index + 2 < parameters.count && parameters[index + 1] == 5:
                if let indexedStyle = TerminalANSIColorPalette.indexedStyle(for: parameters[index + 2]) {
                    components.foreground = indexedStyle.foreground
                }
                index += 3
            case 48 where index + 2 < parameters.count && parameters[index + 1] == 5:
                if let indexedStyle = TerminalANSIColorPalette.indexedStyle(for: parameters[index + 2]) {
                    components.background = indexedStyle.foreground
                }
                index += 3
            case 38 where index + 4 < parameters.count && parameters[index + 1] == 2:
                components.foreground = .trueColor(
                    red: clampColor(parameters[index + 2]),
                    green: clampColor(parameters[index + 3]),
                    blue: clampColor(parameters[index + 4])
                )
                index += 5
            case 48 where index + 4 < parameters.count && parameters[index + 1] == 2:
                components.background = .trueColor(
                    red: clampColor(parameters[index + 2]),
                    green: clampColor(parameters[index + 3]),
                    blue: clampColor(parameters[index + 4])
                )
                index += 5
            default:
                index += 1
            }
        }

        return TerminalANSIStyle.from(
            foreground: components.foreground,
            background: components.background,
            isBold: components.isBold,
            isUnderlined: components.isUnderlined,
            isInverted: components.isInverted,
            isDim: components.isDim,
            isItalic: components.isItalic,
            isStrikethrough: components.isStrikethrough,
            isConcealed: components.isConcealed,
            isBlinking: components.isBlinking,
            isOverlined: components.isOverlined
        )
    }

    private func clampColor(_ value: Int) -> Int {
        min(255, max(0, value))
    }
}
