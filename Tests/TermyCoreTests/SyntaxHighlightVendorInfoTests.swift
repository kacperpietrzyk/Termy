import XCTest
@testable import TermyCore

final class SyntaxHighlightVendorInfoTests: XCTestCase {
    func test_parsesNameAndTag() {
        let pins = """
        # Canonical pin for the vendored zsh-syntax-highlighting (FB-1).
        NAME    zsh-syntax-highlighting
        TAG     0.8.0
        SHA     db085e4661f6aafd24e5acb5b2e17e4dd5dddf3e
        LICENSE MIT
        """
        let info = SyntaxHighlightVendorInfo.parse(pins)
        XCTAssertEqual(info?.name, "zsh-syntax-highlighting")
        XCTAssertEqual(info?.version, "0.8.0")
    }

    func test_missingTagReturnsNil() {
        let pins = "NAME    zsh-syntax-highlighting\nSHA  abc\n"
        XCTAssertNil(SyntaxHighlightVendorInfo.parse(pins))
    }

    func test_parsesRealCommittedPINS() throws {
        // Resolve <repo>/vendor/zsh-syntax-highlighting/PINS from this test file.
        let repo = URL(fileURLWithPath: #filePath)   // …/Tests/TermyCoreTests/<file>.swift
            .deletingLastPathComponent()             // TermyCoreTests
            .deletingLastPathComponent()             // Tests
            .deletingLastPathComponent()             // repo root
        let pins = repo.appendingPathComponent("vendor/zsh-syntax-highlighting/PINS")
        let contents = try String(contentsOf: pins, encoding: .utf8)
        let info = SyntaxHighlightVendorInfo.parse(contents)
        XCTAssertEqual(info?.name, "zsh-syntax-highlighting")
        XCTAssertFalse(info?.version.isEmpty ?? true)
    }
}
