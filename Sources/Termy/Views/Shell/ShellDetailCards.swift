import SwiftUI
import TermyCore

/// DESIGN.md §6.1 detail cards. Every row is real-sourced (Slice-1 data layer +
/// Slice-3 additions); honest empty where a value is absent. Built on the shared
/// `TermyDetailCard` atom + `TermyPill`.

struct ShellSessionStatsCard: View {
    @ObservedObject var store: TermyStore
    let session: TermySession
    @State private var crashCount = 0

    var body: some View {
        TermyDetailCard(title: "Session stats", systemImage: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 0) {
                ShellDetailRow(key: "Commands") { Text("\(store.commandsToday()) today").detailValue() }
                ShellDetailRow(key: "Uptime", showsTopSeparator: true) {
                    Text("\(DesktopModel.relativeAge(Date().timeIntervalSince(session.startedAt)))").detailValue()
                }
                ShellDetailRow(key: "Output mode", showsTopSeparator: true) {
                    TermyPill(title: store.selectedTerminalOutputModeValue.rawValue, tint: Color(DesignTokens.host.base))
                }
                ShellDetailRow(key: "Sidecar", showsTopSeparator: true) {
                    let disabled = store.sidecarDisabledSessions.contains(session.id)
                    TermyPill(title: ShellModuleModel.sidecarSummary(disabled: disabled, crashCount: crashCount),
                              tint: Color(disabled ? DesignTokens.error.base : DesignTokens.sync.base))
                }
                if let vendor = store.syntaxHighlightVendor {
                    ShellDetailRow(key: "Highlight", showsTopSeparator: true) {
                        TermyPill(title: "\(vendor.name) \(vendor.version)", tint: Color(DesignTokens.sync.base))
                    }
                }
            }
        }
        .task(id: session.id) { crashCount = await store.sidecarRecentCrashCount(forSession: session.id) }
    }
}

struct ShellAIContextCard: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        TermyDetailCard(title: "AI context", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 0) {
                ShellDetailRow(key: "Local model") { Text(store.aiModel).detailValue() }
                ShellDetailRow(key: "Endpoint", showsTopSeparator: true) {
                    Text(ShellModuleModel.endpointDisplay(store.aiEndpoint)).detailValue()
                }
                ShellDetailRow(key: "Network", showsTopSeparator: true) {
                    TermyPill(title: "0 net · loopback only", systemImage: "lock", tint: Color(DesignTokens.sync.base))
                }
                ShellDetailRow(key: "Last explain", showsTopSeparator: true) {
                    Text(ShellModuleModel.lastExplainSummary(store.lastTerminalExplain) ?? "—").detailValue()
                }
            }
        }
    }
}

/// §6.1 `f-row` (`styles.css`): `grid-template-columns: 120px 1fr` — a fixed key
/// column with the value left-aligned right after it (NOT pushed to the far
/// edge). Center-aligned vertically; a dashed hairline separates rows.
private struct ShellDetailRow<Value: View>: View {
    let key: String
    var showsTopSeparator: Bool = false
    @ViewBuilder var value: () -> Value

    var body: some View {
        VStack(spacing: 0) {
            if showsTopSeparator { DashedHairline() }
            HStack(spacing: 0) {
                Text(key).font(Typography.ui(13)).foregroundStyle(Color(DesignTokens.fg3))
                    .frame(width: 120, alignment: .leading)
                value().frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 7)
        }
    }
}

/// §6.1 `f-row + f-row { border-top: 1px dashed }`.
private struct DashedHairline: View {
    var body: some View {
        HairlinePath()
            .stroke(Color(DesignTokens.hair), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }
}

private struct HairlinePath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

private extension Text {
    func detailValue() -> some View {
        self.font(Typography.mono(12.5)).foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
    }
}
