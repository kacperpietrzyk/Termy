import Foundation

public enum ShellIntegrationEvent: Equatable, Sendable {
    case output(String)
    case commandStarted(String)
    case commandFinished(exitCode: Int32, workingDirectory: String?)
    case inputBufferChanged(text: String, cursor: Int, length: Int)
    /// FB-1: zsh-syntax-highlighting `region_highlight` spans for the live input
    /// line, published alongside the buffer (separate OSC 133 `H` marker).
    case inputHighlightsChanged([InputHighlightSpan])
}

/// FB-1: one `region_highlight` span over the live line-editor buffer —
/// character range `[start, end)` painted with a foreground color. `start`/`end`
/// are character offsets into the buffer (as zsh reports them).
public struct InputHighlightSpan: Equatable, Sendable {
    public let start: Int
    public let end: Int
    public let foregroundHex: String?   // "#rrggbb" when the style had `fg=#…`
    public let underline: Bool

    public init(start: Int, end: Int, foregroundHex: String?, underline: Bool) {
        self.start = start
        self.end = end
        self.foregroundHex = foregroundHex
        self.underline = underline
    }

    /// Parse one `region_highlight` entry ("START END STYLE [MEMO]"), e.g.
    /// "0 3 fg=#cdd6f4" or "4 7 fg=#f38ba8,bold". Returns nil if start/end are
    /// missing. Only `fg=#hex` + `underline` are interpreted (Termy injects hex
    /// styles); other style tokens are ignored (span left uncolored).
    public static func parse(entry: String) -> InputHighlightSpan? {
        let parts = entry.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2, let start = Int(parts[0]), let end = Int(parts[1]) else { return nil }
        let style = parts.count >= 3 ? parts[2] : ""
        var fgHex: String?
        var underline = false
        for token in style.split(separator: ",").map(String.init) {
            if token.hasPrefix("fg=#") { fgHex = String(token.dropFirst(3)) }   // "#rrggbb"
            else if token == "underline" { underline = true }
        }
        return InputHighlightSpan(start: start, end: end, foregroundHex: fgHex, underline: underline)
    }
}

/// OSC 133 contract (M3-1, spec §4.1.5). Markers are `ESC ] 133 ; … BEL`.
/// CONSUMED:
///   `C` -> .commandStarted(values["cmd"] ?? "") — the non-standard `cmd=`
///     extension IS relied upon; Termy's own ShellIntegrationScript emits it.
///   `D` -> .commandFinished(exitCode: Int32, workingDirectory: values["pwd"]).
///   `T` -> .inputBufferChanged(base64-decoded values["b"], Int(values["c"]) ?? 0, Int(values["n"]) ?? 0)
///     — F-1 zle-line-pre-redraw $BUFFER report (Termy-private OSC 133 subtype).
///   `H` -> .inputHighlightsChanged(spans) — FB-1 zsh-syntax-highlighting
///     `region_highlight` for the live line (base64 values["r"], Termy-private).
/// IGNORED: `A` (prompt-start), `B` (prompt-end), and any other sub-sequence
///   -> parseMarker returns nil; the marker bytes are consumed and dropped.
/// Everything outside a complete marker is emitted verbatim as .output
///   (an unterminated trailing marker is buffered until the next chunk or flush()).
public struct ShellIntegrationParser: Sendable {
    private static let markerPrefix = "\u{1B}]133;"
    private static let markerTerminator = "\u{7}"

    private var buffer = ""

    public init() {}

    public mutating func consume(_ chunk: String) -> [ShellIntegrationEvent] {
        buffer += chunk
        return drainBuffer(allowIncompleteTrailingMarker: true)
    }

    public mutating func flush() -> [ShellIntegrationEvent] {
        drainBuffer(allowIncompleteTrailingMarker: false)
    }

    private mutating func drainBuffer(allowIncompleteTrailingMarker: Bool) -> [ShellIntegrationEvent] {
        var events: [ShellIntegrationEvent] = []

        while !buffer.isEmpty {
            guard let markerStart = buffer.range(of: Self.markerPrefix) else {
                emitOutput(buffer, into: &events)
                buffer.removeAll()
                break
            }

            if markerStart.lowerBound > buffer.startIndex {
                emitOutput(String(buffer[..<markerStart.lowerBound]), into: &events)
                buffer.removeSubrange(..<markerStart.lowerBound)
                continue
            }

            let payloadStart = buffer.index(buffer.startIndex, offsetBy: Self.markerPrefix.count)
            guard let markerEnd = buffer.range(
                of: Self.markerTerminator,
                range: payloadStart..<buffer.endIndex
            ) else {
                if allowIncompleteTrailingMarker {
                    break
                }
                emitOutput(buffer, into: &events)
                buffer.removeAll()
                break
            }

            let payload = String(buffer[payloadStart..<markerEnd.lowerBound])
            if let event = parseMarker(payload) {
                events.append(event)
            }
            buffer.removeSubrange(..<markerEnd.upperBound)
        }

        return coalesceOutput(events)
    }

    private func parseMarker(_ payload: String) -> ShellIntegrationEvent? {
        let segments = payload.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        guard let marker = segments.first else { return nil }
        let values = Dictionary(
            uniqueKeysWithValues: segments.dropFirst().compactMap { segment -> (String, String)? in
                guard let separator = segment.firstIndex(of: "=") else { return nil }
                let key = String(segment[..<separator])
                let value = String(segment[segment.index(after: separator)...])
                return (key, value.removingPercentEncoding ?? value)
            }
        )

        switch marker {
        case "C":
            return .commandStarted(values["cmd"] ?? "")
        case "D":
            let exitCode = Int32(values["exit"] ?? "") ?? 0
            return .commandFinished(exitCode: exitCode, workingDirectory: values["pwd"])
        case "T":
            guard let b64 = values["b"],
                  let data = Data(base64Encoded: b64),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            let cursor = Int(values["c"] ?? "") ?? 0
            let length = Int(values["n"] ?? "") ?? 0
            return .inputBufferChanged(text: text, cursor: cursor, length: length)
        case "H":
            // FB-1: base64-encoded `region_highlight`, entries joined by `|`.
            // An empty array (no highlighting) decodes to no spans.
            guard let b64 = values["r"],
                  let data = Data(base64Encoded: b64),
                  let joined = String(data: data, encoding: .utf8) else { return nil }
            let spans = joined
                .split(separator: "|", omittingEmptySubsequences: true)
                .compactMap { InputHighlightSpan.parse(entry: String($0)) }
            return .inputHighlightsChanged(spans)
        default:
            return nil
        }
    }

    private func emitOutput(_ text: String, into events: inout [ShellIntegrationEvent]) {
        guard !text.isEmpty else { return }
        events.append(.output(text))
    }

    private func coalesceOutput(_ events: [ShellIntegrationEvent]) -> [ShellIntegrationEvent] {
        var coalesced: [ShellIntegrationEvent] = []

        for event in events {
            if case .output(let text) = event,
               case .output(let existing)? = coalesced.last {
                coalesced[coalesced.count - 1] = .output(existing + text)
            } else {
                coalesced.append(event)
            }
        }

        return coalesced
    }
}
