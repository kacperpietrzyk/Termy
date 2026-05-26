import SwiftUI
import TermyCore

/// §3.1 hero greeting: time-aware salutation (first name in a violet→blue
/// gradient) + a single-line mono meta row + a real-state sub-text.
struct DesktopHeroView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                greeting
                Spacer(minLength: 24)
                metaRow
            }
            subText
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: some View {
        let g = DesktopModel.greeting(at: Date(), name: "Kacper")
        return (Text(g.lead + ", ").foregroundStyle(Color(DesignTokens.fg1))
                + Text(g.name).foregroundStyle(nameGradient)
                + Text(".").foregroundStyle(Color(DesignTokens.fg1)))
            .font(Typography.display(44))
            .tracking(-1)
            .lineLimit(1)
    }

    private var nameGradient: LinearGradient {
        LinearGradient(colors: [Color(DesignTokens.primary), Color(DesignTokens.git.base)],
                       startPoint: .leading, endPoint: .trailing)
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(Color(DesignTokens.sync.base)).frame(width: 6, height: 6)
                Text("iCloud · ") + Text("synced").foregroundStyle(Color(DesignTokens.fg1))
            }
            divider
            Text("local · ") + Text("0 net").foregroundStyle(Color(DesignTokens.fg1))
            divider
            Text(Self.dateString(Date()))
        }
        .font(Typography.mono(12))
        .foregroundStyle(Color(DesignTokens.fg3))
        .lineLimit(1)
        .fixedSize()
    }

    private var divider: some View {
        Rectangle().fill(Color(DesignTokens.hair2)).frame(width: 1, height: 14)
    }

    private var subText: some View {
        let spans = DesktopModel.heroSubText(
            vitals: store.agentVitals,
            gitDirty: DesktopModel.gitDirtyCount(store.gitStatus),
            branch: store.selectedGitBranch)
        return spans.reduce(Text("")) { acc, span in
            acc + Text(span.text).foregroundStyle(color(for: span.accent))
        }
        .font(Typography.ui(15))
        .frame(maxWidth: 720, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func color(for accent: DesktopModel.HeroAccent) -> Color {
        switch accent {
        case .agent: Color(DesignTokens.agent.base)
        case .git:   Color(DesignTokens.git.base)
        case .plain: Color(DesignTokens.fg3)
        }
    }

    static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }
}
