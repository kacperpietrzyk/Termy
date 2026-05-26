enum TerminalDECSpecialGraphics {
    static func map(_ character: Character) -> Character {
        switch character {
        case "`": return "◆"
        case "a": return "▒"
        case "f": return "°"
        case "g": return "±"
        case "j": return "┘"
        case "k": return "┐"
        case "l": return "┌"
        case "m": return "└"
        case "n": return "┼"
        case "o": return "⎺"
        case "p": return "⎻"
        case "q": return "─"
        case "r": return "⎼"
        case "s": return "⎽"
        case "t": return "├"
        case "u": return "┤"
        case "v": return "┴"
        case "w": return "┬"
        case "x": return "│"
        case "y": return "≤"
        case "z": return "≥"
        case "{": return "π"
        case "|": return "≠"
        case "}": return "£"
        case "~": return "·"
        default: return character
        }
    }
}
