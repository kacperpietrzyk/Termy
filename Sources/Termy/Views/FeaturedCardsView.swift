import SwiftUI
import TermyCore

/// §3.3 "What's open" — 4 featured cards over real state, each with an honest
/// empty-state. Click → open the corresponding module tab.
struct FeaturedCardsView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's open")
                .font(Typography.ui(13, weight: .semibold))
                .foregroundStyle(Color(DesignTokens.fg3))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
                      alignment: .leading, spacing: 16) {
                AgentWaitingCardView(store: store)
                DirtyRepoCardView(store: store)
                ShellSessionCardView(store: store)
                HostCardView(store: store)
            }
        }
    }
}

// MARK: shared card chrome

@ViewBuilder
private func cardHeader(dotHue: OKLCH, kind: String, pulsing: Bool = false) -> some View {
    HStack(spacing: 7) {
        TermyStatusDot(hue: dotHue, pulsing: pulsing)
        Text(kind).font(Typography.mono(11)).foregroundStyle(Color(dotHue))
        Spacer(minLength: 0)
    }
}

@ViewBuilder
private func cardStat(_ value: String, _ label: String) -> some View {
    (Text(value).foregroundStyle(Color(DesignTokens.fg1))
     + Text(label).foregroundStyle(Color(DesignTokens.fg4)))
        .font(Typography.mono(11))
}

@ViewBuilder
private func cardEmpty(_ text: String) -> some View {
    Text(text)
        .font(Typography.ui(13))
        .foregroundStyle(Color(DesignTokens.fg4))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
}

// MARK: 1 — agent waiting (agent / amber)

private struct AgentWaitingCardView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        let grouped = groupAgentVitals(store.agentVitals)
        TermyCard(hue: DesignTokens.agent.edge) {
            VStack(alignment: .leading, spacing: 8) {
                cardHeader(dotHue: DesignTokens.agent.base, kind: "agent · waiting", pulsing: true)
                if let a = grouped.waiting.first {
                    Text(a.name).font(Typography.ui(15, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                    Text("\(a.agentType.displayName)\(a.branch.map { " · \($0)" } ?? "")")
                        .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg3)).lineLimit(1)
                    HStack(spacing: 12) {
                        cardStat("\(a.dirtyCount)", " dirty")
                        cardStat(DesktopModel.relativeAge(Date().timeIntervalSince(a.stateChangedAt)), " waiting")
                    }
                } else {
                    cardEmpty(grouped.running.isEmpty ? "No agents waiting"
                                                       : "\(grouped.running.count) running")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture { store.openModuleTab(.agents) }
    }
}

// MARK: 2 — dirty repo (git / blue)

private struct DirtyRepoCardView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        let rows = DesktopModel.gitMiniRows(from: store.gitStatus, limit: 3)
        let dirty = DesktopModel.gitDirtyCount(store.gitStatus)
        TermyCard(hue: DesignTokens.git.edge) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    TermyStatusDot(hue: DesignTokens.git.base)
                    Text("git").font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.git.base))
                    Spacer(minLength: 0)
                    if let d = store.gitDivergence {
                        Text("↑\(d.ahead) ↓\(d.behind)").font(Typography.mono(11))
                            .foregroundStyle(Color(DesignTokens.fg3))
                    }
                }
                Text(store.selectedGitBranch ?? "—").font(Typography.ui(15, weight: .medium))
                    .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                if dirty > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(rows, id: \.path) { row in
                            HStack(spacing: 8) {
                                Text(row.code).font(Typography.mono(10, weight: .bold))
                                    .foregroundStyle(Color(DesignTokens.git.base))
                                    .frame(width: 18, alignment: .leading)
                                Text(row.path).font(Typography.mono(11))
                                    .foregroundStyle(Color(DesignTokens.fg2)).lineLimit(1)
                            }
                        }
                    }
                    cardStat("\(dirty)", dirty == 1 ? " change" : " changes")
                } else {
                    cardEmpty("Working tree clean")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture { store.openModuleTab(.git) }
    }
}

// MARK: 3 — shell session (neutral / green dot)

private struct ShellSessionCardView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        TermyCard {
            VStack(alignment: .leading, spacing: 8) {
                cardHeader(dotHue: DesignTokens.sync.base, kind: "shell · live")
                if let s = store.selectedSession {
                    Text(s.title).font(Typography.ui(15, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                    Text(s.currentWorkingDirectory ?? "~")
                        .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg3)).lineLimit(1)
                } else {
                    cardEmpty("No active session")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture { store.openModuleTab(.shell) }
    }
}

// MARK: 4 — host (host / cyan)

private struct HostCardView: View {
    @ObservedObject var store: TermyStore

    private var host: ConnectionProfile? {
        if let id = store.selectedConnectionProfileID,
           let p = store.profiles.first(where: { $0.id == id }), p.kind != .local {
            return p
        }
        return store.profiles.first { $0.kind != .local }
    }

    var body: some View {
        let h = host
        TermyCard(hue: DesignTokens.host.edge) {
            VStack(alignment: .leading, spacing: 8) {
                cardHeader(dotHue: DesignTokens.host.base, kind: h?.kind == .rdp ? "rdp" : "ssh")
                if let h {
                    Text(h.name).font(Typography.ui(15, weight: .medium))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                    Text("\(h.user.map { "\($0)@" } ?? "")\(h.host)")
                        .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg3)).lineLimit(1)
                } else {
                    cardEmpty("No connections")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture { store.openModuleTab(.connections) }
    }
}
