import Foundation
import TermyCore

/// Observe-without-consume tap that layers the PRD §6.1 command-block model
/// onto the SwiftTerm-owned terminal. Receives the raw SwiftTerm PTY output
/// slice (forwarded by the Task-3 tap mechanism —
/// `TappedLocalProcessTerminalView.dataReceived(slice:)` AFTER `super`, so
/// SwiftTerm still renders the bytes verbatim) and feeds the existing
/// `TermyCore.ShellIntegrationParser` without consuming or mutating the
/// stream — the command-block layer never perturbs what the user sees.
///
/// M3-2 live path — bytes flow:
///   PTY bytes → `TermyCore.TerminalUTF8StreamDecoder` → String chunk →
///   CR/LF normalization (`\r\n`→`\n`, then `\r`→`\n` — the two
///   `replacingOccurrences` calls in `normalize` below) →
///   `ShellIntegrationParser.consume`.
///
/// Boundary correctness: `TerminalUTF8StreamDecoder` already holds an
/// incomplete trailing UTF-8 codepoint across `decode` calls (and
/// `ShellIntegrationParser` holds an incomplete trailing OSC marker across
/// `consume` calls), so a multi-byte codepoint or OSC 133 sequence straddling
/// two `ingest()` calls is reassembled correctly. We deliberately reuse the
/// already-shipping production decoder (and its malformed-input policy: hold
/// until >4 bytes, then U+FFFD-decode) rather than a cleverer bespoke one —
/// parity with the live command-block model is the contract here.
public final class SwiftTermStreamBridge {
    private var parser = ShellIntegrationParser()
    private var decoder = TerminalUTF8StreamDecoder()
    private let onEvents: ([ShellIntegrationEvent]) -> Void

    public init(onEvents: @escaping ([ShellIntegrationEvent]) -> Void) {
        self.onEvents = onEvents
    }

    /// Forwarded a verbatim copy of the bytes SwiftTerm received; never mutates them.
    public func ingest(_ slice: ArraySlice<UInt8>) {
        // `Data(slice)` copies the slice's elements regardless of its
        // (possibly non-zero) startIndex — safe for `whole[6...]`-style slices.
        let chunk = normalize(decoder.decode(Data(slice)))
        guard !chunk.isEmpty else { return }
        // Decoder state is fully advanced by `decode` above and parser state by
        // `consume` below BEFORE `onEvents` runs (last), so a reentrant
        // `ingest` from within the callback cannot double-decode these bytes.
        let events = parser.consume(chunk)
        if !events.isEmpty { onEvents(events) }
    }

    public func flush() {
        let remainder = normalize(decoder.flush())
        if !remainder.isEmpty {
            let events = parser.consume(remainder)
            if !events.isEmpty { onEvents(events) }
        }
        let events = parser.flush()
        if !events.isEmpty { onEvents(events) }
    }

    /// The exact CR/LF normalization the M3-2 live path
    /// (`SwiftTermStreamBridge` -> `ShellIntegrationParser`) applies before
    /// `parser.consume`: `\r\n`->`\n` first, then any remaining `\r`->`\n`.
    private func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
