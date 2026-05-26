import Foundation

public struct GitConflictHunk: Equatable, Sendable {
    public let path: String
    public let oursLabel: String
    public let theirsLabel: String
    public let ours: String
    public let theirs: String

    public init(path: String, oursLabel: String, theirsLabel: String, ours: String, theirs: String) {
        self.path = path
        self.oursLabel = oursLabel
        self.theirsLabel = theirsLabel
        self.ours = ours
        self.theirs = theirs
    }
}

public struct GitConflictParser: Sendable {
    public init() {}

    public func parse(_ contents: String, path: String) -> [GitConflictHunk] {
        enum State {
            case normal
            case ours(label: String, lines: [String])
            case theirs(oursLabel: String, ours: [String], lines: [String])
        }

        var hunks: [GitConflictHunk] = []
        var state = State.normal

        for line in contents.components(separatedBy: .newlines) {
            switch state {
            case .normal:
                if let label = markerLabel(line, prefix: "<<<<<<<") {
                    state = .ours(label: label, lines: [])
                }
            case .ours(let label, let lines):
                if line == "=======" {
                    state = .theirs(oursLabel: label, ours: lines, lines: [])
                } else {
                    state = .ours(label: label, lines: lines + [line])
                }
            case .theirs(let oursLabel, let ours, let lines):
                if let theirsLabel = markerLabel(line, prefix: ">>>>>>>") {
                    hunks.append(
                        GitConflictHunk(
                            path: path,
                            oursLabel: oursLabel,
                            theirsLabel: theirsLabel,
                            ours: ours.joined(separator: "\n"),
                            theirs: lines.joined(separator: "\n")
                        )
                    )
                    state = .normal
                } else {
                    state = .theirs(oursLabel: oursLabel, ours: ours, lines: lines + [line])
                }
            }
        }

        return hunks
    }

    private func markerLabel(_ line: String, prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        let label = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? prefix : label
    }
}
