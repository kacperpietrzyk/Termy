import XCTest
@testable import TermyCore

final class CompletionSidecarTransportTests: XCTestCase {
    // ----- Q encoding -----

    func test_encodeComplete_baseCase() {
        let line = CompletionSidecarTransport.encodeComplete(
            buffer: "git p", cursor: 5, cwd: "/Users/x", reqId: 7
        )
        XCTAssertTrue(line.hasPrefix("__termy_complete "))
        XCTAssertTrue(line.hasSuffix("\n"))
        let parts = line.dropLast().split(separator: " ")
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(String(parts[2]), "5")
        XCTAssertEqual(String(parts[3]), "/Users/x")
        XCTAssertEqual(String(parts[4]), "7")
        let b64 = String(parts[1])
        let decoded = Data(base64Encoded: b64).flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(decoded, "git p")
    }

    func test_encodeComplete_unicodeAndControlChars() {
        let line = CompletionSidecarTransport.encodeComplete(
            buffer: "echo \"żółć\\nx\"", cursor: 14, cwd: "/tmp", reqId: 1
        )
        let parts = line.dropLast().split(separator: " ")
        let decoded = Data(base64Encoded: String(parts[1]))
            .flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(decoded, "echo \"żółć\\nx\"")
    }

    func test_encodeCd_basic() {
        let line = CompletionSidecarTransport.encodeCd(cwd: "/tmp/some dir")
        XCTAssertTrue(line.hasPrefix("__termy_cd "))
        XCTAssertTrue(line.hasSuffix("\n"))
    }

    // ----- TSV body decoding (post-spike file-based) -----

    func test_decodeTSVBody_happy() {
        let body = """
        command\tpush\tgit push\tUpdate remote refs
        command\tpull\tgit pull\tFetch and integrate
        """ + "\n"
        let items = CompletionSidecarTransport.decodeTSVBody(body)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "push")
        XCTAssertEqual(items[0].description, "Update remote refs")
        XCTAssertEqual(items[0].kind, .command)
        XCTAssertEqual(items[1].replacement, "git pull")
    }

    func test_decodeTSVBody_emptyDescription_preservedAsNil() {
        // Trailing tab means description column is empty; must round-trip to nil.
        let body = "command\tpop\tgit pop\t\n"
        let items = CompletionSidecarTransport.decodeTSVBody(body)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "pop")
        XCTAssertNil(items[0].description)
    }

    func test_decodeTSVBody_emptyBody_returnsEmpty() {
        XCTAssertEqual(CompletionSidecarTransport.decodeTSVBody(""), [])
    }

    func test_decodeTSVBody_skipMalformedLines() {
        let body = """
        command\tpush\tgit push\tdesc
        not-enough-columns
        \tnokind\trepl\t
        command\tok\trepl\t
        """ + "\n"
        let items = CompletionSidecarTransport.decodeTSVBody(body)
        // Three lines are skipped: "not-enough-columns" has <4 columns; the
        // "\tnokind\trepl\t" line has 4 columns but an empty kind — rejected by
        // the `guard !kindRaw.isEmpty` check. Only the 2 fully-formed lines
        // ("push" and "ok") survive.
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "push")
        XCTAssertEqual(items[1].title, "ok")
    }

    func test_decodeTSVBody_descriptionWithSpaces_preserved() {
        // Spaces in description survive tab-splitting.
        let body = "command\tcheckout\tgit checkout\tSwitch branches or restore working tree files\n"
        let items = CompletionSidecarTransport.decodeTSVBody(body)
        XCTAssertEqual(items[0].description, "Switch branches or restore working tree files")
    }

    func test_decodeTSVBody_trailingCRLF_handled() {
        // Files written on macOS could legitimately have \n; CR\n hardening doesn't hurt.
        let body = "command\tpush\tgit push\tdesc\r\n"
        let items = CompletionSidecarTransport.decodeTSVBody(body)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].description, "desc")
    }

    // ----- Err body decoding -----

    func test_decodeErrBody_happy() {
        XCTAssertEqual(CompletionSidecarTransport.decodeErrBody("err=bad-cwd\n"), "bad-cwd")
        XCTAssertEqual(CompletionSidecarTransport.decodeErrBody("err=internal"), "internal")
    }

    func test_decodeErrBody_malformed_returnsNil() {
        XCTAssertNil(CompletionSidecarTransport.decodeErrBody(""))
        XCTAssertNil(CompletionSidecarTransport.decodeErrBody("not-an-err-line\n"))
        XCTAssertNil(CompletionSidecarTransport.decodeErrBody("err="))  // empty value also nil
    }

    // ----- Tag mapping -----

    func test_mapZshTagToKind_known() {
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("commands"), .command)
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("builtins"), .builtin)
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("aliases"), .alias)
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("files"), .file)
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("directories"), .directory)
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("options"), .option)
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("flags"), .flag)
    }

    func test_mapZshTagToKind_unknown_fallsBackToCommand() {
        XCTAssertEqual(CompletionSidecarTransport.kindFromZshTag("anything-else"), .command)
    }
}
