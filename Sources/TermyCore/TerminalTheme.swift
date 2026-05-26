import Foundation

public struct TerminalTheme: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let backgroundHex: String
    public let foregroundHex: String
    public let promptHex: String
    public let errorHex: String
    public let mutedHex: String

    public init(
        id: String,
        name: String,
        backgroundHex: String,
        foregroundHex: String,
        promptHex: String,
        errorHex: String,
        mutedHex: String
    ) {
        self.id = id
        self.name = name
        self.backgroundHex = backgroundHex
        self.foregroundHex = foregroundHex
        self.promptHex = promptHex
        self.errorHex = errorHex
        self.mutedHex = mutedHex
    }

    public func applyingIncreasedContrast() -> TerminalTheme {
        TerminalTheme(
            id: id,
            name: name,
            backgroundHex: "#000000",
            foregroundHex: "#FFFFFF",
            promptHex: "#00D7FF",
            errorHex: "#FF5C5C",
            mutedHex: "#D0D0D0"
        )
    }
}

public struct TerminalThemeCatalog: Equatable, Sendable {
    public let themes: [TerminalTheme]
    public let defaultThemeID: String

    public init(themes: [TerminalTheme], defaultThemeID: String) {
        self.themes = themes
        self.defaultThemeID = defaultThemeID
    }

    public var defaultTheme: TerminalTheme {
        theme(id: defaultThemeID) ?? themes[0]
    }

    public func theme(id: String) -> TerminalTheme? {
        themes.first { $0.id == id } ?? themes.first { $0.id == defaultThemeID }
    }

    public func merging(customThemes: [TerminalTheme]) -> TerminalThemeCatalog {
        var merged = themes
        for theme in customThemes {
            if let index = merged.firstIndex(where: { $0.id == theme.id }) {
                merged[index] = theme
            } else {
                merged.append(theme)
            }
        }
        return TerminalThemeCatalog(themes: merged, defaultThemeID: defaultThemeID)
    }

    public static let builtIn = TerminalThemeCatalog(
        themes: [
            TerminalTheme(
                id: "system",
                name: "System",
                backgroundHex: "#1E1E1E",
                foregroundHex: "#F2F2F2",
                promptHex: "#64D2FF",
                errorHex: "#FF453A",
                mutedHex: "#98989D"
            ),
            TerminalTheme(
                id: "solarized-dark",
                name: "Solarized Dark",
                backgroundHex: "#002B36",
                foregroundHex: "#EEE8D5",
                promptHex: "#268BD2",
                errorHex: "#DC322F",
                mutedHex: "#839496"
            ),
            TerminalTheme(
                id: "paper-light",
                name: "Paper Light",
                backgroundHex: "#FAFAF8",
                foregroundHex: "#242424",
                promptHex: "#0057B8",
                errorHex: "#C1272D",
                mutedHex: "#6E6E73"
            )
        ],
        defaultThemeID: "system"
    )
}

public struct TerminalFontPreferences: Equatable, Sendable {
    public let size: Double
    public let family: String?
    public let usesLigatures: Bool

    public init(size: Double = 13, family: String? = nil, usesLigatures: Bool = true) {
        self.size = min(32, max(9, size))
        let trimmedFamily = family?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.family = trimmedFamily.isEmpty ? nil : trimmedFamily
        self.usesLigatures = usesLigatures
    }
}
