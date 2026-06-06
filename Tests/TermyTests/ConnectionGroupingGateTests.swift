import XCTest
import SwiftUI
import AppKit
import TermyCore
@testable import Termy

/// Static visual gate for the Connections grouping slice (D-DEBT-ORDER #6).
/// Renders real ConnectionCards laid out in grouped sections (the same
/// ConnectionGrouping the panel uses) to a PNG for inspection.
@MainActor
final class ConnectionGroupingGateTests: XCTestCase {
    func test_groupedSections_render() throws {
        let store = TermyStore(startInitialPTY: false)
        let profiles: [ConnectionProfile] = [
            .ssh(name: "web-prod", host: "10.0.0.4", user: "deploy", identity: .keychain("k"), groupPath: "Client A"),
            .ssh(name: "db-prod", host: "10.0.0.5", user: "deploy", identity: .keychain("k"), groupPath: "Client A"),
            .rdp(name: "win-box", host: "10.0.1.9", user: "admin", gateway: nil, credential: .keychain("k"), groupPath: "Client B"),
            .ssh(name: "scratch-host", host: "192.168.1.2", user: "kacper", identity: .keychain("k"), groupPath: nil),
        ]

        let sections = ConnectionGrouping.grouped(profiles)
        XCTAssertEqual(sections.map(\.title), ["Client A", "Client B", nil])

        let view = VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 10) {
                    Text((section.title ?? "Ungrouped").uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(DesignTokens.Glass.textQuaternary)
                    ForEach(section.profiles) { profile in
                        ConnectionCard(store: store, profile: profile)
                    }
                }
            }
        }
        .frame(width: 360)
        .padding(16)
        .background(Color(DesignTokens.bg1))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/gate-connections-01-grouped.png"))
        }
    }
}
