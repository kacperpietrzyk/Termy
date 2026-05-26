import SwiftUI
import TermyCore

/// DESIGN.md §5.10 — the embedded PTY pane. Live agents render the *real*
/// `LiveTerminalSurface`; an exited "Recent" agent shows a static ended-state
/// (never re-mounting a surface, which would re-spawn the process).
struct AgentTUIPaneView: View {
    @ObservedObject var store: TermyStore
    let vitals: AgentSessionVitals

    private var isLive: Bool { vitals.state != .exited }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color(DesignTokens.hair2))
            paneContent
            Divider().overlay(Color(DesignTokens.hair2))
            footer
        }
        .background(Color(DesignTokens.bg0))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
            .stroke(Color(DesignTokens.hair2), lineWidth: 1))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle().fill(isLive ? Color(DesignTokens.sync.base) : Color(DesignTokens.fg5))
                    .frame(width: 9, height: 9)
                Circle().fill(Color(DesignTokens.fg5)).frame(width: 9, height: 9)
                Circle().fill(Color(DesignTokens.fg5)).frame(width: 9, height: 9)
            }
            Text(vitals.agentType.displayName).font(Typography.mono(12, weight: .medium))
                .foregroundStyle(Color(DesignTokens.fg2))
            Spacer()
            if let cwd = vitals.cwd {
                Text((cwd as NSString).lastPathComponent)
                    .font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4))
            }
            Text(AgentsModuleModel.stateLabel(vitals.state))
                .font(Typography.mono(11))
                .foregroundStyle(Color(TermyDesign.activityToken(vitals.state)))
        }
        .padding(.horizontal, 12).frame(height: 32)
    }

    @ViewBuilder private var paneContent: some View {
        if isLive,
           let session = store.session(for: vitals.id),
           session.interactionMode == .rawPTY,
           let descriptor = store.terminalLaunchDescriptor(for: vitals.id) {
            LiveTerminalSurface(store: store, session: session, descriptor: descriptor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "moon.zzz").font(.system(size: 22))
                    .foregroundStyle(Color(DesignTokens.fg4))
                Text("Session ended").font(Typography.ui(14, weight: .medium))
                    .foregroundStyle(Color(DesignTokens.fg2))
                Text("Plan and touched files below reflect its last run. Re-launch with ⌘K.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            footTag("raw PTY tap", on: isLive)
            if vitals.agentType != .codex {
                footTag("Notification hook", on: true)
            }
            Text("OSC 133 prompt-return").foregroundStyle(Color(DesignTokens.fg4))
            Text("OSC 7 cwd").foregroundStyle(Color(DesignTokens.fg4))
            Spacer()
            Text("chrome driven by the signals — no TUI re-render")
                .foregroundStyle(Color(DesignTokens.fg5))
        }
        .font(Typography.mono(10)).padding(.horizontal, 12).frame(height: 30)
    }

    private func footTag(_ label: String, on: Bool) -> some View {
        HStack(spacing: 4) {
            Circle().fill(on ? Color(DesignTokens.sync.base) : Color(DesignTokens.fg5)).frame(width: 6, height: 6)
            Text(label).foregroundStyle(Color(DesignTokens.fg4))
        }
    }
}
