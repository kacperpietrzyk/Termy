import Foundation

public enum InterfaceTextScale: String, CaseIterable, Equatable, Sendable {
    case regular
    case large
    case extraLarge = "extra-large"

    public var title: String {
        switch self {
        case .regular:
            return "Regular"
        case .large:
            return "Large"
        case .extraLarge:
            return "Extra Large"
        }
    }
}
