import SwiftUI
import TermyCore

// MARK: §5.5 — vitals strip.
struct AgentVitalsStripView: View {
    let vitals: AgentSessionVitals

    private func color(_ hue: AgentsModuleModel.ChipHue) -> Color {
        switch hue {
        case .neutral: return Color(DesignTokens.fg2)
        case .git:     return Color(DesignTokens.git.base)
        case .agent:   return Color(DesignTokens.agent.base)
        }
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(AgentsModuleModel.vitalsChips(vitals).enumerated()), id: \.offset) { _, chip in
                HStack(spacing: 5) {
                    if let icon = chip.icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
                    if let key = chip.key { Text(key).foregroundStyle(Color(DesignTokens.fg4)) }
                    Text(chip.value).foregroundStyle(color(chip.hue)).lineLimit(1)
                }
                .font(Typography.mono(12))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(Color(DesignTokens.hair), lineWidth: 1))
            }
        }
    }
}

// MARK: §5.8 — animated plan stepper.
struct AgentPlanCardView: View {
    let plan: [AgentPlanStep]

    var body: some View {
        let progress = AgentsModuleModel.planProgress(plan)
        AgentCardShell(title: "plan", trailing: "\(progress.done)/\(progress.total)") {
            if plan.isEmpty {
                Text("No plan yet — the agent reports steps as it works.")
                    .font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(plan) { step in PlanStepRow(step: step) }
                }
            }
        }
    }
}

private struct PlanStepRow: View {
    let step: AgentPlanStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            pip
            VStack(alignment: .leading, spacing: 2) {
                Text(step.text)
                    .font(Typography.ui(12.5, weight: step.state == .active ? .medium : .regular))
                    .strikethrough(step.state == .done)
                    .foregroundStyle(step.state == .done ? Color(DesignTokens.fg3) : Color(DesignTokens.fg1))
                if let sub = step.sub {
                    Text("↳ \(sub)").font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4))
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var pip: some View {
        switch step.state {
        case .done:
            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white).frame(width: 16, height: 16)
                .background(Color(DesignTokens.sync.base), in: Circle())
        case .active:
            Circle().fill(Color(DesignTokens.primary)).frame(width: 16, height: 16)
                .overlay(Circle().fill(.white).frame(width: 6, height: 6))
        case .todo:
            Circle().stroke(Color(DesignTokens.hair2), lineWidth: 1.5).frame(width: 16, height: 16)
        }
    }
}

// MARK: signals card — value + truthful source tag.
struct AgentSignalsCardView: View {
    let vitals: AgentSessionVitals

    var body: some View {
        let n = vitals.touched.count
        return AgentCardShell(title: "signals · \(n) \(n == 1 ? "file" : "files") touched", trailing: nil) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(AgentsModuleModel.signalRows(vitals).enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 8) {
                        Text(row.key).font(Typography.ui(11)).foregroundStyle(Color(DesignTokens.fg4))
                            .frame(width: 84, alignment: .leading)
                        Text(row.value).font(Typography.mono(12)).foregroundStyle(Color(DesignTokens.fg1))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let tag = row.tag { SourceTagChip(tag: tag) }
                    }
                }
            }
        }
    }
}

private struct SourceTagChip: View {
    let tag: AgentsModuleModel.SourceTag

    private var hue: Color {
        switch tag {
        case .hook: return Color(DesignTokens.agent.base)
        case .pty:  return Color(DesignTokens.sync.base)
        case .osc:  return Color(DesignTokens.git.base)
        case .proc: return Color(DesignTokens.fg3)
        }
    }

    var body: some View {
        Text(tag.label)
            .font(Typography.mono(9, weight: .medium))
            .foregroundStyle(hue)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(hue.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: touched-files card.
struct AgentTouchedCardView: View {
    let touched: [String]

    var body: some View {
        AgentCardShell(title: "touched files", trailing: nil) {
            if touched.isEmpty {
                Text("No edits yet.").font(Typography.ui(12)).foregroundStyle(Color(DesignTokens.fg4))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(touched, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text").font(.system(size: 11))
                                .foregroundStyle(Color(DesignTokens.fg4))
                            Text(path).font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg2))
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }
}

/// The §5.3 detail card now lives in DesignSystem.swift as TermyDetailCard.
/// Alias kept so the Agents call sites read unchanged.
typealias AgentCardShell = TermyDetailCard

/// Minimal wrapping flow layout for the vitals chips (SwiftUI `Layout`, macOS 13+).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
