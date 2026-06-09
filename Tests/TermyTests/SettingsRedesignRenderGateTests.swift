import XCTest
import SwiftUI
import AppKit
import TermyCore
@testable import Termy

/// Static visual gate for the Settings redesign slice (M5).
/// Rasterizes the card-based Settings into PNGs for inspection. The redesigned
/// `SettingsView` roots a `ScrollView`, whose content does NOT rasterize under
/// ImageRenderer, so the gate renders the extracted `SettingsContent` column
/// (sans ScrollView) at a tall frame — the full stack of cards is captured.
/// This is a compile+draw smoke test, NOT a binding test (a miswired $store.x
/// still compiles and renders cleanly — binding fidelity is the owner gate).
@MainActor
final class SettingsRedesignRenderGateTests: XCTestCase {
    private func render(_ store: TermyStore, name: String) -> NSImage? {
        let view = SettingsContent(store: store)
            .frame(width: 600)
            .padding(20)
            .frame(width: 640, height: 1400, alignment: .top)
            .background(Color(DesignTokens.bg0))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let img = renderer.nsImage
        if let img, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-settings-\(name).png"))
        }
        return img
    }

    func test_settings_renders_to_png() throws {
        let store = TermyStore(startInitialPTY: false)
        XCTAssertNotNil(render(store, name: "01-redesign"))
    }

    func test_customThemeCard_renders_with_seeded_draft() throws {
        let store = TermyStore(startInitialPTY: false)
        store.customThemeName = "Midnight"
        store.customThemeBackgroundHex = "#101015"
        store.customThemeForegroundHex = "#E8E8F0"
        store.customThemePromptHex = "#7AA2F7"
        store.customThemeErrorHex = "#F7768E"
        store.customThemeMutedHex = "#565F89"
        store.terminalShellKind = "custom"
        store.terminalCustomShellPath = "/bin/zsh"
        store.terminalCustomShellArguments = "-l"
        XCTAssertNotNil(render(store, name: "02-customtheme"))
    }
}
