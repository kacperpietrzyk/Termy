import SwiftUI
import TermyCore

/// AD-8 — the light review→commit→push→PR finalizer surface for one agent.
///
/// Each step is a DISTINCT, explicit user action (B4 — offer, never take over):
///   1. Commit the worktree changes (with an editable message).
///   2. Push the agent's branch (sets upstream).
///   3. Draft a PR title+body with the LOCAL model (offline) — REVIEWED and
///      EDITABLE before anything is sent.
///   4. Create the PR via the user's own `gh` auth.
///
/// Nothing auto-commits, auto-pushes, or auto-submits; the drafted description is
/// never sent unreviewed. All work targets the agent's worktree (resolved in the
/// store), not the main session — preserving per-agent isolation.
struct AgentPRFinalizerView: View {
    @ObservedObject var store: TermyStore
    let vitals: AgentSessionVitals

    @State private var commitMessage: String = ""
    @State private var prTitle: String = ""
    @State private var prBody: String = ""
    @State private var committed = false
    @State private var pushed = false
    @State private var drafting = false
    @State private var working = false
    /// Set once a PR URL is parsed back, so the surface shows the link.
    @State private var createdURL: String?

    private var agentExited: Bool { vitals.state == .exited }

    var body: some View {
        TermyDetailCard(title: "finalize → PR", trailing: vitals.branch, systemImage: "arrow.triangle.pull") {
            VStack(alignment: .leading, spacing: 12) {
                privacyNote
                step1Commit
                step2Push
                step3Draft
                step4Create
                if let createdURL {
                    Link(destination: URL(string: createdURL) ?? URL(fileURLWithPath: "/")) {
                        Label(createdURL, systemImage: "checkmark.seal.fill")
                            .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.sync.base))
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
            }
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock").font(.system(size: 9))
            Text("`gh` uses your GitHub auth · description from your local model · no Termy account, no relay")
                .foregroundStyle(Color(DesignTokens.fg4))
        }
        .font(Typography.mono(10)).foregroundStyle(Color(DesignTokens.fg4))
    }

    // MARK: 1 — commit

    private var step1Commit: some View {
        VStack(alignment: .leading, spacing: 6) {
            stepHeader(1, "Commit changes", done: committed)
            HStack(spacing: 8) {
                TextField("Commit message…", text: $commitMessage)
                    .textFieldStyle(GlassTextFieldStyle())
                    .font(Typography.ui(12))
                    .disabled(working || agentExited)
                Button("Commit") {
                    working = true
                    store.commitAgentWorktree(sessionID: vitals.id, message: commitMessage) { ok in
                        working = false
                        if ok { committed = true }
                    }
                }
                .buttonStyle(TermyCommandButtonStyle())
                .disabled(working || agentExited || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: 2 — push

    private var step2Push: some View {
        VStack(alignment: .leading, spacing: 6) {
            stepHeader(2, "Push branch", done: pushed)
            Button("Push to origin") {
                working = true
                store.pushAgentWorktree(sessionID: vitals.id) { ok in
                    working = false
                    if ok { pushed = true }
                }
            }
            .buttonStyle(TermyCommandButtonStyle())
            .disabled(working || agentExited)
        }
    }

    // MARK: 3 — draft

    private var step3Draft: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                stepHeader(3, "Draft description (local AI)", done: !prTitle.isEmpty)
                Spacer(minLength: 8)
                Button {
                    drafting = true
                    store.draftAgentPRDescription(sessionID: vitals.id) { draft in
                        drafting = false
                        if let draft {
                            prTitle = draft.title
                            prBody = draft.body
                        }
                    }
                } label: {
                    if drafting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Draft with local AI", systemImage: "sparkles")
                    }
                }
                .buttonStyle(TermyCommandButtonStyle())
                .disabled(drafting || working)
            }
            TextField("PR title…", text: $prTitle)
                .textFieldStyle(GlassTextFieldStyle())
                .font(Typography.ui(12))
            TextEditor(text: $prBody)
                .font(Typography.mono(11.5))
                .frame(minHeight: 80, maxHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(DesignTokens.bg1).opacity(0.6),
                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(Color(DesignTokens.hair), lineWidth: 1))
            Text("Review and edit before creating — nothing is sent until you press Create PR.")
                .font(Typography.ui(10)).foregroundStyle(Color(DesignTokens.fg4))
        }
    }

    // MARK: 4 — create

    private var step4Create: some View {
        HStack(spacing: 8) {
            Button("Create PR") {
                working = true
                store.createAgentPR(
                    sessionID: vitals.id, title: prTitle, body: prBody
                ) { outcome in
                    working = false
                    if case .created(let url, _) = outcome { createdURL = url }
                }
            }
            .buttonStyle(TermyCommandButtonStyle(emphasized: true))
            .disabled(working || prTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text("base: main")
                .font(Typography.mono(10)).foregroundStyle(Color(DesignTokens.fg4))
        }
    }

    private func stepHeader(_ n: Int, _ label: String, done: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle")
                .font(.system(size: 12))
                .foregroundStyle(done ? Color(DesignTokens.sync.base) : Color(DesignTokens.fg3))
            Text(label).font(Typography.ui(12, weight: .medium)).foregroundStyle(Color(DesignTokens.fg2))
        }
    }
}
