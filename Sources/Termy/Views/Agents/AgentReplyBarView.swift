import SwiftUI
import TermyCore

/// DESIGN.md §6.2 reply bar: writes a line into the agent PTY via
/// `store.sendAgentReply`. Amber when the agent is waiting; disabled when exited.
struct AgentReplyBarView: View {
    @ObservedObject var store: TermyStore
    let vitals: AgentSessionVitals
    @State private var text = ""
    @FocusState private var focused: Bool

    private var waiting: Bool { vitals.state == .waitingForInput }
    private var disabled: Bool { vitals.state == .exited }
    private var label: String { vitals.agentType.displayName }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: waiting ? "exclamationmark.triangle.fill" : "sparkle")
                    .font(.system(size: 13))
                    .foregroundStyle(waiting ? Color(DesignTokens.agent.base) : Color(DesignTokens.ai.base))
                TextField(waiting ? "Reply to \(label)…" : "Send a message to \(label)…", text: $text)
                    .textFieldStyle(.plain).font(Typography.ui(13))
                    .focused($focused)
                    .onSubmit(send)
                Button(waiting ? "Reply" : "Send", action: send)
                    .buttonStyle(TermyCommandButtonStyle(emphasized: true))
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(waiting ? Color(DesignTokens.agent.base).opacity(0.6) : Color(DesignTokens.hair2),
                        lineWidth: 1))

            HStack(spacing: 6) {
                Image(systemName: "lock").font(.system(size: 9))
                Text("routed to ").foregroundStyle(Color(DesignTokens.fg4))
                + Text(label).foregroundStyle(Color(DesignTokens.fg2))
                + Text(" — your auth, no Termy account, no relay").foregroundStyle(Color(DesignTokens.fg4))
                Spacer()
                Text("⏎ or ⌘⏎ to send").foregroundStyle(Color(DesignTokens.fg5))
            }
            .font(Typography.mono(10)).foregroundStyle(Color(DesignTokens.fg4))
        }
        .opacity(disabled ? 0.5 : 1)
        .disabled(disabled)
        .onAppear { if waiting { focused = true } }
        .onChange(of: waiting) { _, nowWaiting in if nowWaiting { focused = true } }
    }

    private func send() {
        guard !disabled else { return }
        store.sendAgentReply(text, to: vitals.id)
        text = ""
    }
}
