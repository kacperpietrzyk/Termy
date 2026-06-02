import AppKit
import SwiftUI
import TermyCore

/// The calm live-card **Home** (root `DESIGN.md`): a time-of-day greeting, a
/// real-state subline, and a grid of glass cards summarising sessions, agents,
/// git, and connections. Every datum is derived from real store state via
/// `DesktopModel` — cards empty-state honestly and never show fabricated metrics.
struct HomeView: View {
    @ObservedObject var store: TermyStore

    private var firstName: String {
        let full = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return full.isEmpty ? "there" : full
    }

    private var grouped: GroupedAgentVitals { groupAgentVitals(store.agentVitals) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                cardsGrid
                if !store.frequentCommands().isEmpty {
                    frequentCommandsSection
                }
                quickActions
            }
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
            .padding(.vertical, 40)
            // Vertically center the block so Home reads as a calm, balanced hero
            // rather than content pinned to the top of a large empty window.
            .frame(minHeight: 640, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Load real git status promptly so the Git card reflects the repo instead
        // of the unqueried sentinel (the metric/empty-state still guard on a
        // confirmed-clean marker, so there is no false "clean" before this lands).
        .task { store.refreshGitStatus() }
    }

    // MARK: frequent commands (real frecency history)

    private var frequentCommandsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FREQUENT COMMANDS")
                .font(.system(size: 11, weight: .semibold)).tracking(0.5)
                .foregroundStyle(DesignTokens.Glass.textTertiary)
            FlowChips(items: store.frequentCommands(limit: 8)) { cmd in
                store.runCommandInShell(cmd)
            }
        }
    }

    // MARK: greeting + subline

    private var header: some View {
        let g = DesktopModel.greeting(at: Date(), name: firstName)
        return VStack(alignment: .leading, spacing: 8) {
            (Text(g.lead + ", ").foregroundStyle(DesignTokens.Glass.textPrimary)
             + Text(g.name).foregroundStyle(DesignTokens.Glass.accent))
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.2)   // neutral range per DESIGN.md (no marketing-site compression)

            subline
        }
    }

    private var subline: some View {
        let spans = DesktopModel.heroSubText(
            vitals: store.agentVitals,
            gitDirty: DesktopModel.gitDirtyCount(store.gitStatus),
            branch: store.selectedGitBranch
        )
        return spans.reduce(Text("")) { acc, span in
            let color: Color = switch span.accent {
            case .agent: Color(DesignTokens.agent.base)
            case .git:   Color(DesignTokens.git.base)
            case .plain: DesignTokens.Glass.textSecondary
            }
            return acc + Text(span.text).foregroundStyle(color)
        }
        .font(.system(size: 14))
    }

    // MARK: cards

    private var cardsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
            sessionsCard
            agentsCard
            gitCard
            connectionsCard
        }
    }

    private var sessionsCard: some View {
        let recents = store.sessions.suffix(3).reversed().map(\.title)
        return HomeCard(
            title: "Sessions",
            systemImage: "terminal",
            hue: DesignTokens.neutral.base,
            metric: "\(store.sessions.count)",
            metricLabel: store.sessions.count == 1 ? "live session" : "live sessions",
            action: { store.openModuleTab(.shell) }
        ) {
            if recents.isEmpty {
                HomeCardEmpty("No sessions yet — ⌘T to start one")
            } else {
                ForEach(Array(recents.enumerated()), id: \.offset) { _, title in
                    HomeCardLine(text: title, systemImage: "chevron.right")
                }
            }
        }
    }

    private var agentsCard: some View {
        let waiting = grouped.waiting
        let running = grouped.running
        let metric = waiting.isEmpty ? "\(running.count)" : "\(waiting.count)"
        let label = waiting.isEmpty
            ? (running.count == 1 ? "agent running" : "agents running")
            : (waiting.count == 1 ? "agent waiting" : "agents waiting")
        return HomeCard(
            title: "Agents",
            systemImage: "cpu",
            hue: waiting.isEmpty ? DesignTokens.sync.base : DesignTokens.agent.base,
            metric: metric,
            metricLabel: label,
            action: { store.openModuleTab(.agents) }
        ) {
            let shown = (waiting + running).prefix(3)
            if shown.isEmpty {
                HomeCardEmpty("No active agents")
            } else {
                ForEach(shown) { v in
                    HomeCardLine(
                        text: v.name,
                        systemImage: v.state == .waitingForInput ? "exclamationmark.circle" : "circle.fill",
                        tint: Color(TermyDesign.activityToken(v.state))
                    )
                }
            }
        }
    }

    private var gitCard: some View {
        let status = store.gitStatus
        let rows = DesktopModel.gitMiniRows(from: status, limit: 3)
        let dirty = DesktopModel.gitDirtyCount(status)
        let confirmedClean = DesktopModel.gitIsConfirmedClean(status)
        // Three honest states: dirty (real count), confirmed clean, or not-yet-loaded
        // (unqueried sentinel / not-a-repo / error). Only a confirmed clean tree may
        // show "0 / Working tree clean"; unknown shows a neutral em dash.
        let metric = dirty > 0 ? "\(dirty)" : (confirmedClean ? "0" : "—")
        return HomeCard(
            title: "Git",
            systemImage: "point.3.connected.trianglepath.dotted",
            hue: DesignTokens.git.base,
            metric: metric,
            metricLabel: dirty == 1 ? "dirty file" : "dirty files",
            trailing: store.selectedGitBranch,
            action: { store.openModuleTab(.git) }
        ) {
            if !rows.isEmpty {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HomeCardLine(text: row.path, monoBadge: row.code.trimmingCharacters(in: .whitespaces))
                }
            } else if confirmedClean {
                HomeCardEmpty("Working tree clean")
            } else {
                HomeCardEmpty("Git status not loaded yet")
            }
        }
    }

    private var connectionsCard: some View {
        let remotes = store.profiles.filter { $0.kind == .ssh || $0.kind == .rdp }
        let recents = remotes.prefix(3)
        return HomeCard(
            title: "Connections",
            systemImage: "network",
            hue: DesignTokens.host.base,
            metric: "\(remotes.count)",
            metricLabel: remotes.count == 1 ? "saved host" : "saved hosts",
            action: { store.openModuleTab(.connections) }
        ) {
            if recents.isEmpty {
                HomeCardEmpty("No SSH/RDP hosts saved")
            } else {
                ForEach(recents) { profile in
                    HomeCardLine(
                        text: profile.name,
                        systemImage: profile.kind == .rdp ? "display" : "terminal",
                        secondary: profile.host
                    )
                }
            }
        }
    }

    // MARK: quick actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickAction(title: "New Shell", shortcut: "⌘T", systemImage: "plus") {
                store.newLocalShellSession()
                store.openModuleTab(.shell)
            }
            QuickAction(title: "Search & Run", shortcut: "⌘K", systemImage: "magnifyingglass") {
                store.perform("open-command-center")
            }
            QuickAction(title: "Connect", shortcut: "⇧⌘S", systemImage: "network") {
                store.perform("connect-ssh")
            }
            Spacer()
        }
    }
}

// MARK: - Card atoms

/// A glass Home card: a header (icon + title + optional trailing mono), a large
/// real metric, and a small body of real lines. The whole card is a button that
/// opens its module.
private struct HomeCard<Body: View>: View {
    let title: String
    let systemImage: String
    let hue: OKLCH
    let metric: String
    let metricLabel: String
    var trailing: String? = nil
    let action: () -> Void
    @ViewBuilder var content: () -> Body

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hue))
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(DesignTokens.Glass.textTertiary)
                    Spacer()
                    if let trailing, !trailing.isEmpty {
                        Text(trailing)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DesignTokens.Glass.textSecondary)
                            .lineLimit(1)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(metric)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(DesignTokens.Glass.textPrimary)
                        .monospacedDigit()
                    Text(metricLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Glass.textSecondary)
                }

                VStack(alignment: .leading, spacing: 5) { content() }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Glass.raised.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                // Neutral hover edge — chroma stays in the icon/content, never the
                // chrome surface (DESIGN.md). Hover lift is carried by the shadow.
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(hovering ? DesignTokens.Glass.hairlineStrong : DesignTokens.Glass.hairline, lineWidth: 1)
            )
            .shadow(color: DesignTokens.Shadow.cardColor,
                    radius: hovering ? DesignTokens.Shadow.cardRadius : 8, y: 6)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(DesignTokens.Motion.easeOutSnappy, value: hovering)
    }
}

private struct HomeCardLine: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = DesignTokens.Glass.textSecondary
    var secondary: String? = nil
    var monoBadge: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let monoBadge {
                Text(monoBadge)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignTokens.Glass.textTertiary)
                    .frame(minWidth: 18, alignment: .leading)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9))
                    .foregroundStyle(tint)
                    .frame(width: 12)
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(DesignTokens.Glass.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let secondary {
                Text(secondary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.Glass.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Wrapping row of clickable command chips (real frecency history).
private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(item)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: 280)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(DesignTokens.Glass.fillControl, in: Capsule())
                        .overlay(Capsule().stroke(DesignTokens.Glass.hairline, lineWidth: 1))
                        .foregroundStyle(DesignTokens.Glass.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Run “\(item)” in a shell")
            }
        }
    }
}

private struct HomeCardEmpty: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(DesignTokens.Glass.textTertiary)
    }
}

private struct QuickAction: View {
    let title: String
    let shortcut: String
    let systemImage: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .medium))
                Text(shortcut)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.Glass.textTertiary)
            }
            .foregroundStyle(hovering ? DesignTokens.Glass.textPrimary : DesignTokens.Glass.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(hovering ? DesignTokens.Glass.fillSelection : DesignTokens.Glass.fillControl,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control)
                    .stroke(DesignTokens.Glass.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
