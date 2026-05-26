import Foundation

/// v3 Shell §6.1 ("Highlight · zsh-syntax-highlighting 0.8.0"): the single
/// source of truth for the vendored syntax-highlighter version is
/// `vendor/zsh-syntax-highlighting/PINS` (shipped verbatim in the app bundle).
/// This parses that file's `KEY  VALUE` lines — never hardcode the version.
public enum SyntaxHighlightVendorInfo {
    public static func parse(_ contents: String) -> (name: String, version: String)? {
        var name: String?
        var version: String?
        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let split = line.firstIndex(where: { $0 == " " || $0 == "\t" }) else { continue }
            let key = String(line[line.startIndex..<split])
            let value = String(line[split...]).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            switch key {
            case "NAME": name = value
            case "TAG": version = value
            default: break
            }
        }
        guard let name, let version else { return nil }
        return (name, version)
    }
}
