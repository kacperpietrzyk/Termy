import SwiftUI
import TermyCore

/// AD-7: read-only History over locally-archived agent sessions. Each archived
/// session (plan/touched/diff/metadata, persisted as JSONL under Application
/// Support/Termy) is listed newest-first; selecting one reveals its captured
/// plan, touched files and worktree diff.
///
/// "Restorable" here = the data is durable and viewable after the live session
/// (and its worktree) are gone — this slice does NOT re-spawn a PTY. A record
/// synced in from another Mac carries metadata + plan + touched but NO diff (the
/// diff is local-only — see `AgentArchiveRecord.diff`), so the diff section
/// renders an honest "not available on this Mac" note rather than a fake empty.
struct AgentHistoryView: View {
    @ObservedObject var store: TermyStore
    @State private var selectedID: String?

    private var records: [AgentArchiveRecord] { store.archivedAgentSessions }

    var body: some View {
        TermyDetailCard(title: "agent history", trailing: countLabel, systemImage: "clock.arrow.circlepath") {
            if records.isEmpty {
                Text("No archived agent sessions yet. Finished agents are archived here automatically.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(records) { record in
                        AgentHistoryRow(
                            record: record,
                            isSelected: selectedID == record.id,
                            toggle: { toggle(record.id) })
                        if selectedID == record.id {
                            AgentHistoryDetail(record: record)
                                .padding(.leading, 6)
                        }
                    }
                }
            }
        }
    }

    private var countLabel: String? {
        records.isEmpty ? nil : "\(records.count) \(records.count == 1 ? "session" : "sessions")"
    }

    private func toggle(_ id: String) {
        selectedID = (selectedID == id) ? nil : id
    }
}

// MARK: - one archived-session row

private struct AgentHistoryRow: View {
    let record: AgentArchiveRecord
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(DesignTokens.fg4))
                    .frame(width: 10)
                Text(record.name).font(Typography.ui(12.5)).foregroundStyle(Color(DesignTokens.fg1))
                    .lineLimit(1).truncationMode(.middle)
                Text(record.agentType.displayName).font(Typography.mono(9.5))
                    .foregroundStyle(Color(DesignTokens.fg4))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color(DesignTokens.bg2).opacity(0.7), in: Capsule())
                Spacer(minLength: 8)
                exitBadge
                Text(Self.relative.localizedString(for: record.archivedAt, relativeTo: Date()))
                    .font(Typography.mono(10.5)).foregroundStyle(Color(DesignTokens.fg4))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10).frame(height: 32)
            .background(isSelected ? Color(DesignTokens.bg2).opacity(0.5) : .clear,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var exitBadge: some View {
        if let code = record.exitCode {
            let ok = code == 0
            Text(ok ? "exit 0" : "exit \(code)")
                .font(Typography.mono(9.5))
                .foregroundStyle(ok ? Color(DesignTokens.fg4) : Color(DesignTokens.error.base))
        }
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

// MARK: - detail for one archived session

private struct AgentHistoryDetail: View {
    let record: AgentArchiveRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            metadata
            if !record.plan.isEmpty { planSection }
            if !record.touched.isEmpty { touchedSection }
            diffSection
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .background(Color(DesignTokens.bg2).opacity(0.4), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .stroke(Color(DesignTokens.hair), lineWidth: 1))
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let cwd = record.cwd { metaLine("folder", cwd) }
            if let branch = record.branch { metaLine("arrow.triangle.branch", branch) }
            if let wt = record.worktreePath { metaLine("square.split.2x1", wt) }
            metaLine("clock", "started \(Self.absolute.string(from: record.startedAt))")
        }
    }

    private func metaLine(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(Color(DesignTokens.fg4)).frame(width: 12)
            Text(text).font(Typography.mono(10.5)).foregroundStyle(Color(DesignTokens.fg3))
                .lineLimit(1).truncationMode(.middle)
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("PLAN · \(record.plan.count)")
            ForEach(record.plan) { step in
                HStack(spacing: 6) {
                    Image(systemName: Self.stepIcon(step.state)).font(.system(size: 9))
                        .foregroundStyle(Self.stepColor(step.state)).frame(width: 12)
                    Text(step.text).font(Typography.ui(11.5)).foregroundStyle(Color(DesignTokens.fg2))
                        .lineLimit(1).truncationMode(.tail)
                }
            }
        }
    }

    private var touchedSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionLabel("TOUCHED · \(record.touched.count)")
            ForEach(record.touched, id: \.self) { path in
                Text(path).font(Typography.mono(10.5)).foregroundStyle(Color(DesignTokens.fg3))
                    .lineLimit(1).truncationMode(.middle)
            }
        }
    }

    @ViewBuilder private var diffSection: some View {
        sectionLabel("DIFF")
        if record.diff.isEmpty {
            Text(record.worktreePath == nil && record.cwd == nil
                 ? "No diff captured."
                 : "No diff for this session (clean tree, or synced from another Mac — diff is kept local-only).")
                .font(Typography.ui(11)).foregroundStyle(Color(DesignTokens.fg4))
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diffLines.prefix(Self.maxDiffLines).enumerated()), id: \.offset) { _, line in
                    HistoryDiffLineRow(text: line)
                }
                if diffLines.count > Self.maxDiffLines {
                    Text("… \(diffLines.count - Self.maxDiffLines) more lines")
                        .font(Typography.mono(10)).foregroundStyle(Color(DesignTokens.fg4))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(DesignTokens.bg1).opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var diffLines: [String] {
        record.diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(Typography.ui(9.5, weight: .semibold)).tracking(0.4)
            .foregroundStyle(Color(DesignTokens.fg4))
    }

    private static let maxDiffLines = 400

    private static func stepIcon(_ state: String) -> String {
        switch state {
        case "done":   "checkmark.circle.fill"
        case "active": "circle.dotted"
        default:        "circle"
        }
    }

    private static func stepColor(_ state: String) -> Color {
        switch state {
        case "done":   Color(DesignTokens.sync.base)
        case "active": Color(DesignTokens.agent.base)
        default:        Color(DesignTokens.fg4)
        }
    }

    private static let absolute: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

// MARK: - one raw-diff line (lightweight unified-diff tinting)

private struct HistoryDiffLineRow: View {
    let text: String

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(Typography.mono(11)).foregroundStyle(color)
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 0.5)
            .background(background)
    }

    private var color: Color {
        if text.hasPrefix("+") && !text.hasPrefix("+++") { return Color(DesignTokens.sync.base) }
        if text.hasPrefix("-") && !text.hasPrefix("---") { return Color(DesignTokens.error.base) }
        if text.hasPrefix("@@") { return Color(DesignTokens.primary) }
        if text.hasPrefix("diff ") || text.hasPrefix("index ")
            || text.hasPrefix("+++") || text.hasPrefix("---") {
            return Color(DesignTokens.fg4)
        }
        return Color(DesignTokens.fg2)
    }

    private var background: Color {
        if text.hasPrefix("+") && !text.hasPrefix("+++") { return Color(DesignTokens.sync.base).opacity(0.10) }
        if text.hasPrefix("-") && !text.hasPrefix("---") { return Color(DesignTokens.error.base).opacity(0.10) }
        if text.hasPrefix("@@") { return Color(DesignTokens.bg2).opacity(0.6) }
        return .clear
    }
}
