import SwiftUI
import TermyCore

/// DESIGN.md §4.3 / §6.1 dt-header live-chip: a green pulsing status dot + a
/// "live · {label}" mono caption. Distinct from `TermyLiveChip` (which is the
/// agent waiting/running/idle chip). `label` comes from
/// `ShellModuleModel.liveChipLabel(kind:zshVersion:)`.
struct ShellLiveChip: View {
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            TermyStatusDot(hue: DesignTokens.sync.base, pulsing: true)
            Text("live · \(label)").font(Typography.mono(12, weight: .medium))
        }
        .foregroundStyle(Color(DesignTokens.sync.base))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
    }
}
