import SwiftUI
import TermyCore

/// §3.2 center: "TERMY" + a live clock (isolated 1 Hz `TimelineView` so the dock
/// does not re-evaluate every second) + the highest-priority attention signal.
struct RadialCenterView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        VStack(spacing: 4) {
            Text("TERMY")
                .font(Typography.ui(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color(DesignTokens.fg4))
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Self.timeString(context.date))
                    .font(Typography.mono(28, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color(DesignTokens.fg1))
            }
            signalLine
        }
        .frame(width: 200, height: 200)
        .background(
            Circle()
                .fill(Color(DesignTokens.bg1))
                .shadow(color: Color(DesignTokens.primary).opacity(0.35), radius: 30)
        )
        .overlay(Circle().stroke(Color(DesignTokens.hair), lineWidth: 1))
    }

    @ViewBuilder private var signalLine: some View {
        switch DesktopModel.attentionSignal(store.agentVitals) {
        case .waiting(let name):
            HStack(spacing: 6) {
                TermyStatusDot(hue: DesignTokens.agent.base, pulsing: true)
                Text("\(name) waiting").lineLimit(1)
            }
            .font(Typography.ui(12))
            .foregroundStyle(Color(DesignTokens.agent.base))
        case .running(let count):
            HStack(spacing: 6) {
                TermyStatusDot(hue: DesignTokens.sync.base)
                Text("\(count) running")
            }
            .font(Typography.ui(12))
            .foregroundStyle(Color(DesignTokens.sync.base))
        case .calm:
            Text("all clear")
                .font(Typography.ui(12))
                .foregroundStyle(Color(DesignTokens.fg4))
        }
    }

    static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
