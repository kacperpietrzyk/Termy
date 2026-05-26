#if canImport(AppKit)
import XCTest
@testable import Termy
import TermyCore

// M3-1 deferred parity regression (spec reviewer + Task-4 implementer both
// flagged: the two FROZEN SwiftTermStreamBridgeTests do NOT cover these two
// load-bearing properties of the bridge's byte->String->parser path):
//
//   1. A multi-byte UTF-8 codepoint split mid-codepoint ACROSS two
//      `bridge.ingest(...)` calls must still decode losslessly. This exercises
//      the reused `TermyCore.TerminalUTF8StreamDecoder`'s carry-across-calls
//      contract (SwiftTermStreamBridge.swift:19-26) through the bridge's own
//      `Data(slice)` copy path (SwiftTermStreamBridge.swift:37-40). The frozen
//      `testIngestSplitAcrossMarkerBoundaryStillParses` splits an OSC *marker*,
//      never a UTF-8 codepoint, so this is genuinely new coverage.
//
//   2. The bridge applies the SAME CR/LF normalization the M3-2 live path
//      (`SwiftTermStreamBridge` -> `ShellIntegrationParser`) applies before
//      `parser.consume` (`\r\n`->`\n`, then `\r`->`\n`;
//      SwiftTermStreamBridge.swift:61-64). Neither frozen test feeds a
//      `\r`-bearing stream, so the normalization is currently unverified.
//
// Both are deterministic: no real shell, hard-fail (NO XCTSkip), exact
// expected `[ShellIntegrationEvent]` arrays — same idiom as the frozen
// SwiftTermStreamBridgeTests.
final class SwiftTermStreamBridgeParityTests: XCTestCase {

    /// Concatenate all `.output` text from a bridge event stream. Parity
    /// property: the bridge produces ONE parser-consume per ingest() (it does
    /// NOT coalesce across calls — neither does the M3-2 live path
    /// (`SwiftTermStreamBridge` -> `ShellIntegrationParser`)), so a split
    /// codepoint legitimately spans
    /// two `.output` events; "lossless" means the JOINED text is byte-exact,
    /// with the codepoint intact (no U+FFFD), not that events are merged.
    private func joinedOutput(_ events: [ShellIntegrationEvent]) -> String {
        events.compactMap { event -> String? in
            if case let .output(text) = event { return text }
            return nil
        }.joined()
    }

    /// "€" (U+20AC) encodes as 3 bytes: E2 82 AC. Split it mid-codepoint
    /// (1 byte | 2 bytes) across two ingest() calls. If the bridge decoded
    /// each slice independently (without the reused stream decoder's
    /// carry-across-calls) it would emit U+FFFD garbage for the lone 0xE2 and
    /// again for the orphan 0x82 0xAC. The decoder must instead hold the
    /// incomplete codepoint and reassemble it, so the joined .output text is
    /// byte-exact and contains a real "€".
    func testMultiByteCodepointSplitAcrossIngestDecodesLosslessly() {
        var events: [ShellIntegrationEvent] = []
        let bridge = SwiftTermStreamBridge { events.append(contentsOf: $0) }

        let euro = Array("€".utf8)               // [0xE2, 0x82, 0xAC]
        XCTAssertEqual(euro.count, 3, "precondition: € is a 3-byte UTF-8 codepoint")

        let head = Array("price=".utf8) + [euro[0]]   // ends mid-codepoint
        let tail = [euro[1], euro[2]] + Array("\n".utf8)

        bridge.ingest(head[...])
        bridge.ingest(tail[...])
        bridge.flush()

        let joined = joinedOutput(events)
        XCTAssertEqual(
            joined,
            "price=€\n",
            "a 3-byte UTF-8 codepoint split across two ingest() calls must decode losslessly: joined .output text must be byte-exact"
        )
        XCTAssertTrue(joined.contains("€"), "the reassembled codepoint must be a real € (no U+FFFD substitution)")
        XCTAssertFalse(joined.unicodeScalars.contains("\u{FFFD}"), "no U+FFFD replacement char may appear — that would mean the split codepoint was corrupted")
    }

    /// A 4-byte codepoint (emoji U+1F600, F0 9F 98 80) split 2|2 across the
    /// boundary — wider straddle than the 3-byte case, exercises the decoder's
    /// >1-byte carry.
    func testFourByteEmojiSplitAcrossIngestDecodesLosslessly() {
        var events: [ShellIntegrationEvent] = []
        let bridge = SwiftTermStreamBridge { events.append(contentsOf: $0) }

        let emoji = Array("😀".utf8)             // [0xF0, 0x9F, 0x98, 0x80]
        XCTAssertEqual(emoji.count, 4, "precondition: 😀 is a 4-byte UTF-8 codepoint")

        bridge.ingest(ArraySlice(emoji[0..<2]))  // first half of the codepoint
        bridge.ingest(ArraySlice(emoji[2..<4] + Array("!\n".utf8)))
        bridge.flush()

        let joined = joinedOutput(events)
        XCTAssertEqual(
            joined,
            "😀!\n",
            "a 4-byte UTF-8 codepoint split 2|2 across two ingest() calls must decode losslessly: joined .output text must be byte-exact"
        )
        XCTAssertTrue(joined.contains("😀"), "the reassembled 4-byte codepoint must be the real emoji")
        XCTAssertFalse(joined.unicodeScalars.contains("\u{FFFD}"), "no U+FFFD replacement char may appear")
    }

    /// `\r\n`-bearing and bare-`\r`-bearing output must come out of the bridge
    /// with the EXACT normalization the M3-2 live path
    /// (`SwiftTermStreamBridge` -> `ShellIntegrationParser`) does:
    /// `\r\n`->`\n` first, then any remaining `\r`->`\n`. If the bridge did
    /// not normalize, the parser would see raw CRs and the emitted .output
    /// text would differ from the live command-block model.
    func testCRLFAndBareCRNormalizedLikeLivePath() {
        var events: [ShellIntegrationEvent] = []
        let bridge = SwiftTermStreamBridge { events.append(contentsOf: $0) }

        // "a\r\nb\rc\n": \r\n -> \n  ; bare \r -> \n  =>  "a\nb\nc\n"
        let bytes = Array("a\r\nb\rc\n".utf8)
        bridge.ingest(bytes[...])
        bridge.flush()

        XCTAssertEqual(
            events,
            [.output("a\nb\nc\n")],
            "the bridge must apply the same \\r\\n->\\n then \\r->\\n normalization as the M3-2 live path (SwiftTermStreamBridge -> ShellIntegrationParser)"
        )
    }

    /// Per-chunk parity: the bridge normalizes EACH ingested chunk
    /// independently, exactly as the M3-2 live path
    /// (`SwiftTermStreamBridge` -> `ShellIntegrationParser`) does
    /// (it calls the two `replacingOccurrences` on each PTY read in isolation,
    /// not on a re-joined stream). So a `\r` that ends one chunk is normalized
    /// to `\n` within that chunk; the `\n` that begins the next chunk stays a
    /// `\n`. The contract this locks is: NO `\r` ever survives the bridge, and
    /// the behavior matches the live path's per-chunk normalization (not an
    /// idealized cross-chunk `\r\n`->`\n` merge — the live path does not do
    /// that either, so the bridge must not either).
    func testCRSurvivesNoChunkBoundaryAndMatchesLivePerChunkNormalization() {
        var events: [ShellIntegrationEvent] = []
        let bridge = SwiftTermStreamBridge { events.append(contentsOf: $0) }

        let first = Array("line\r".utf8)         // ends on a lone CR
        let second = Array("\nnext\n".utf8)      // a leading LF in the next chunk

        bridge.ingest(first[...])
        bridge.ingest(second[...])
        bridge.flush()

        let joined = joinedOutput(events)

        // Reference oracle: apply the EXACT live normalization the M3-2 live
        // path (`SwiftTermStreamBridge` -> `ShellIntegrationParser`) performs
        // per chunk, mirroring how the bridge processes each ingest()
        // independently.
        // Intentional mirror of SwiftTermStreamBridge.normalize(); literal-expected
        // correctness is anchored by testCRLFAndBareCRNormalizedLikeLivePath above.
        func liveNormalize(_ s: String) -> String {
            s.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }
        let expected = liveNormalize("line\r") + liveNormalize("\nnext\n")

        XCTAssertEqual(
            joined,
            expected,
            "the bridge must normalize each ingested chunk exactly as the M3-2 live path (SwiftTermStreamBridge -> ShellIntegrationParser) does (per-chunk \\r\\n->\\n then \\r->\\n)"
        )
        XCTAssertFalse(joined.contains("\r"), "no carriage return may survive bridge normalization")
    }
}
#endif
