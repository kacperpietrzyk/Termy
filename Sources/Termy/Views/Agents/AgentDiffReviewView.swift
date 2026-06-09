import SwiftUI
import TermyCore

/// AD-3: read-only per-agent diff-review surface. Renders the selected agent's
/// **working-tree** diff (staged + unstaged + untracked) for its isolation
/// cwd/worktree, one collapsible section per file, reusing the FB-1
/// `SyntaxHighlighter` (+ `SyntaxTokenColor`) to tint code line content under the
/// add/remove background.
///
/// AD-4 adds the comment→steering loop on top: attach an inline comment to a
/// file, then SEND the composed comment set as one steering instruction into the
/// live agent PTY (`store.sendSteeringInstruction`). B4: nothing is sent without
/// an explicit press; the diff is otherwise read-only. The diff is loaded off the
/// main actor via `.task(id:)` keyed to the agent so drilling between agents
/// re-loads exactly once and never blocks the UI. Committed agent work (HEAD
/// advanced) is intentionally not shown — see `GitRepository.fileDiffs()`.
struct AgentDiffReviewView: View {
    @ObservedObject var store: TermyStore
    let vitals: AgentSessionVitals

    @State private var phase: Phase = .loading
    @State private var collapsed: Set<String> = []
    /// AD-4: per-file in-progress comment bodies, keyed by file path. A file is
    /// "commented" once its body is non-blank.
    @State private var commentDrafts: [String: String] = [:]
    /// AD-4: which file rows currently show their comment composer.
    @State private var commenting: Set<String> = []

    private var agentExited: Bool { vitals.state == .exited }

    /// AD-4: the composed, ordered comment set for the currently-loaded files.
    private func pendingComments(_ files: [GitFileDiff]) -> [AgentSteering.Comment] {
        files.compactMap { file in
            let body = (commentDrafts[file.path] ?? "")
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return AgentSteering.Comment(filePath: file.path, body: body)
        }
    }

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
                        toggle: { toggle(file.id) },
                        isCommenting: commenting.contains(file.id),
                        commentBody: bindingForComment(file.path),
                        toggleCommenting: { toggleCommenting(file.id) },
                        disabled: agentExited
                    )
                }
                steeringBar(files)
            }
        }
    }

    /// AD-4: the explicit-send footer. Shows only once at least one file carries a
    /// non-blank comment; honest no-op messaging is left to the store when the
    /// agent has exited (the button disables instead).
    @ViewBuilder private func steeringBar(_ files: [GitFileDiff]) -> some View {
        let comments = pendingComments(files)
        if !comments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 11)).foregroundStyle(Color(DesignTokens.agent.base))
                    Text("\(comments.count) review \(comments.count == 1 ? "comment" : "comments") staged")
                        .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg2))
                    Spacer(minLength: 8)
                    Button("Send to \(vitals.agentType.displayName)") { send(comments) }
                        .buttonStyle(TermyCommandButtonStyle(emphasized: true))
                        .disabled(agentExited)
                }
                HStack(spacing: 6) {
                    Image(systemName: "lock").font(.system(size: 9))
                    Text("steered into ").foregroundStyle(Color(DesignTokens.fg4))
                    + Text(vitals.agentType.displayName).foregroundStyle(Color(DesignTokens.fg2))
                    + Text(" — your auth, no Termy account, no relay").foregroundStyle(Color(DesignTokens.fg4))
                }
                .font(Typography.mono(10)).foregroundStyle(Color(DesignTokens.fg4))
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(Color(DesignTokens.bg2).opacity(0.6), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(Color(DesignTokens.agent.base).opacity(0.45), lineWidth: 1))
        }
    }

    private func bindingForComment(_ path: String) -> Binding<String> {
        Binding(get: { commentDrafts[path] ?? "" }, set: { commentDrafts[path] = $0 })
    }

    private func toggleCommenting(_ id: String) {
        if commenting.contains(id) { commenting.remove(id) } else { commenting.insert(id) }
    }

    /// AD-4 explicit send (B4). On a real send, clear the staged comments and
    /// collapse the composers; on a no-op (agent exited mid-review) keep them.
    private func send(_ comments: [AgentSteering.Comment]) {
        let sent = store.sendSteeringInstruction(comments, to: vitals.id)
        if sent {
            for c in comments { commentDrafts[c.filePath] = nil }
            commenting.removeAll()
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
    // AD-4 comment affordance.
    let isCommenting: Bool
    @Binding var commentBody: String
    let toggleCommenting: () -> Void
    let disabled: Bool

    private var hasComment: Bool {
        !commentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isCommenting || hasComment { commentComposer }
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
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .stroke(hasComment ? Color(DesignTokens.agent.base).opacity(0.5) : Color(DesignTokens.hair),
                    lineWidth: 1))
    }

    // AD-4: a one-line comment field anchored to this file. Single-line by design
    // (the steering instruction is one line); newlines are flattened on compose.
    private var commentComposer: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble").font(.system(size: 10))
                .foregroundStyle(Color(DesignTokens.agent.base))
            TextField("Instruction for \(file.path)…", text: $commentBody)
                .textFieldStyle(.plain).font(Typography.ui(12))
            if hasComment {
                Button { commentBody = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                        .foregroundStyle(Color(DesignTokens.fg4))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color(DesignTokens.bg1).opacity(0.6))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // AD-4 comment toggle.
            Button(action: toggleCommenting) {
                Image(systemName: hasComment ? "text.bubble.fill" : "text.bubble")
                    .font(.system(size: 11))
                    .foregroundStyle(hasComment ? Color(DesignTokens.agent.base) : Color(DesignTokens.fg4))
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .help(disabled ? "Agent exited — steering unavailable" : "Comment on this file")
        }
        .padding(.horizontal, 10).frame(height: 30)
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
