#if canImport(AppKit)
import XCTest
@testable import Termy

/// Slice-3a: the block transcript covers the live SwiftTerm host only at the
/// prompt. It yields (verdict 2a) while a command executes so SwiftTerm draws the
/// live run, and while an alt-screen TUI owns the alternate buffer.
final class ShellTranscriptVisibilityTests: XCTestCase {
    func testTranscriptHiddenWhileExecutingSoSwiftTermDrawsTheRun() {
        // At the prompt, block mode, primary screen → transcript covers the host.
        XCTAssertTrue(shellShowsBlockTranscript(routeBlocks: true, altScreen: false, executing: false))
        // While a command runs → transcript removed → SwiftTerm draws the live run.
        XCTAssertFalse(shellShowsBlockTranscript(routeBlocks: true, altScreen: false, executing: true))
        // Alt-screen TUI → already revealed regardless of executing (unchanged).
        XCTAssertFalse(shellShowsBlockTranscript(routeBlocks: true, altScreen: true, executing: false))
        // Non-block route (stream/SSH/RDP) → never the block transcript.
        XCTAssertFalse(shellShowsBlockTranscript(routeBlocks: false, altScreen: false, executing: false))
    }
}
#endif
