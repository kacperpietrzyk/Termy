import SwiftUI
import TermyCore

/// AD-3: read-only per-agent diff-review surface. Renders the selected agent's
/// **working-tree** diff (staged + unstaged + untracked) for its isolation
/// cwd/worktree, one collapsible section per file, reusing the FB-1
/// `SyntaxHighlighter` (+ `SyntaxTokenColor`) to tint code line content under the
/// add/remove background.
///
/// Read-only by construction (AD-4 adds the comment→steering loop). The diff is
/// loaded off the main actor via `.task(id:)` keyed to the agent so drilling
/// between agents re-loads exactly once and never blocks the UI. Committed agent
/// work (HEAD advanced) is intentionally not shown — see `GitRepository.fileDiffs()`.
struct AgentDiffReviewView: View {
    let vitals: AgentSessionVitals

    @State private var phase: Phase = .loading
    @State private var collapsed: Set<String> = []

    private enum Phase: Equatable {
        case loading
        case notARepo
        case clean
        case loaded([GitFileDiff])
    }

    var body: some View {
        TermyDetailCard(title: diffTitle, trailing: diffTrailing, systemImage: "plus.forwardslash.minus") {
            content
        }
        // Re-load when the agent changes OR its working tree moves (dirty count /
        // state transition) so a live agent's diff tracks its edits, not just the
        // first drill-in.
        .task(id: refreshKey) { await load() }
    }

    private var refreshKey: String {
        "\(vitals.id)-\(vitals.dirtyCount)-\(vitals.stateChangedAt.timeIntervalSince1970)"
    }

    private var diffTitle: String {
        switch phase {
        case .loaded(let files): return "worktree diff · \(files.count) \(files.count == 1 ? "file" : "files")"
        default:                 return "worktree diff"
        }
    }

    private var diffTrailing: String? {
        guard case .loaded(let files) = phase else { return nil }
        let added = files.reduce(0) { $0 + $1.addedCount }
        let removed = files.reduce(0) { $0 + $1.removedCount }
        return "+\(added) −\(removed)"
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Reading worktree diff…").font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
            }
        case .notARepo:
            emptyLine("Not a git repository — no diff to review.")
        case .clean:
            emptyLine("Working tree clean — the agent has no uncommitted changes.")
        case .loaded(let files):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(files) { file in
                    AgentDiffFileSection(
                        file: file,
                        isCollapsed: collapsed.contains(file.id),
                        toggle: { toggle(file.id) }
                    )
                }
            }
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text).font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
    }

    private func toggle(_ id: String) {
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
    }

    /// Resolve the agent's git root and parse its working-tree diff off-main.
    private func load() async {
        guard let root = Self.worktreeRoot(for: vitals) else { phase = .notARepo; return }
        phase = .loading
        let outcome = await Task.detached(priority: .userInitiated) { () -> Phase in
            let repo = GitRepository(root: root)
            guard repo.isRepository() else { return .notARepo }
            guard let files = try? repo.fileDiffs() else { return .clean }
            return files.isEmpty ? .clean : .loaded(files)
        }.value
        phase = outcome
    }

    /// The directory whose working-tree diff is the agent's: the worktree path
    /// when isolated, else the enclosing git root of its cwd.
    static func worktreeRoot(for vitals: AgentSessionVitals) -> URL? {
        switch vitals.isolation {
        case .worktree(let path) where !path.isEmpty:
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        default:
            guard let cwd = vitals.cwd, !cwd.isEmpty else { return nil }
            let url = URL(fileURLWithPath: (cwd as NSString).expandingTildeInPath)
            return GitRepository.enclosingGitRoot(of: url) ?? url
        }
    }
}

// MARK: - one collapsible file

private struct AgentDiffFileSection: View {
    static let maxLines = 400

    let file: GitFileDiff
    let isCollapsed: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) { header }.buttonStyle(.plain)
            if !isCollapsed {
                Rectangle().fill(Color(DesignTokens.hair)).frame(height: 1)
                VStack(alignment: .leading, spacing: 0) {
                    // Cap per-file rendering: each row syntax-highlights synchronously,
                    // so a huge refactor diff would hitch the main thread. Truncate
                    // with a footer rather than render thousands of rows.
                    ForEach(file.lines.prefix(Self.maxLines)) { line in
                        AgentDiffLineRow(line: line, fileName: file.path)
                    }
                    if file.lines.count > Self.maxLines {
                        Text("… \(file.lines.count - Self.maxLines) more lines")
                            .font(Typography.mono(10.5)).foregroundStyle(Color(DesignTokens.fg4))
                            .padding(.horizontal, 10).padding(.vertical, 3)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(Color(DesignTokens.bg2).opacity(0.5), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm).stroke(Color(DesignTokens.hair), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(DesignTokens.fg4))
                .frame(width: 10)
            StatusBadge(status: file.status)
            Text(displayPath).font(Typography.mono(11.5)).foregroundStyle(Color(DesignTokens.fg1))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 8)
            if file.addedCount > 0 {
                Text("+\(file.addedCount)").font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.sync.base))
            }
            if file.removedCount > 0 {
                Text("−\(file.removedCount)").font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.error.base))
            }
        }
        .padding(.horizontal, 10).frame(height: 30)
        .contentShape(Rectangle())
    }

    private var displayPath: String {
        if let old = file.oldPath, file.status == .renamed, old != file.path {
            return "\(old) → \(file.path)"
        }
        return file.path
    }
}

private struct StatusBadge: View {
    let status: GitFileDiff.Status

    private var label: String {
        switch status {
        case .added:     return "A"
        case .modified:  return "M"
        case .deleted:   return "D"
        case .renamed:   return "R"
        case .untracked: return "U"
        }
    }

    private var hue: Color {
        switch status {
        case .added, .untracked: return Color(DesignTokens.sync.base)
        case .deleted:           return Color(DesignTokens.error.base)
        case .modified:          return Color(DesignTokens.agent.base)
        case .renamed:           return Color(DesignTokens.primary)
        }
    }

    var body: some View {
        Text(label)
            .font(Typography.mono(9, weight: .bold)).foregroundStyle(hue)
            .frame(width: 16, height: 16)
            .background(hue.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - one diff line

private struct AgentDiffLineRow: View {
    let line: GitDiffLine
    let fileName: String

    private static let highlighter = SyntaxHighlighter()

    var body: some View {
        HStack(spacing: 6) {
            Text(marker).font(Typography.mono(11)).foregroundStyle(markerColor)
                .frame(width: 10, alignment: .center)
            lineContent
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private var marker: String {
        switch line.kind {
        case .added: return "+"
        case .removed: return "−"
        default: return " "
        }
    }

    private var markerColor: Color {
        switch line.kind {
        case .added:   return Color(DesignTokens.sync.base)
        case .removed: return Color(DesignTokens.error.base)
        default:       return Color(DesignTokens.fg4)
        }
    }

    private var rowBackground: Color {
        switch line.kind {
        case .added:      return Color(DesignTokens.sync.base).opacity(0.10)
        case .removed:    return Color(DesignTokens.error.base).opacity(0.10)
        case .hunkHeader: return Color(DesignTokens.bg2).opacity(0.6)
        default:          return .clear
        }
    }

    @ViewBuilder private var lineContent: some View {
        switch line.kind {
        case .hunkHeader:
            Text(line.text).font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.primary)).lineLimit(1)
        case .meta:
            Text(line.text).font(Typography.mono(10.5)).italic().foregroundStyle(Color(DesignTokens.fg4)).lineLimit(1)
        case .added, .removed, .context:
            // FB-1 reuse: tokenize the marker-stripped content for syntax tint.
            highlightedContent
        }
    }

    private var highlightedContent: some View {
        let tokens = Self.highlighter.highlight(line.content, fileName: fileName)
        return tokens.reduce(Text("")) { acc, token in
            acc + Text(token.text).foregroundStyle(SyntaxTokenColor.color(for: token.kind))
        }
        .font(Typography.mono(11.5))
        .lineLimit(1)
        .truncationMode(.tail)
    }
}
