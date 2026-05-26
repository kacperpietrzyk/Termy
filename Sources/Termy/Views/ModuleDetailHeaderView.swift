import SwiftUI
import TermyCore

/// DESIGN.md §4.3 dt-header: 56×56 hue-tinted badge + h2 title + optional inline
/// live-chip + mono sub-text spans + right-aligned actions. Reusable across the
/// Phase-3 per-module ports; first consumer is the Agents canary.
struct ModuleDetailHeaderView<Subtitle: View, Chip: View, Actions: View>: View {
    let icon: String
    let hue: OKLCH
    let title: String
    @ViewBuilder var chip: () -> Chip
    @ViewBuilder var subtitle: () -> Subtitle
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color(hue))
                .frame(width: 56, height: 56)
                .background(Color(hue).opacity(0.14), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(Color(hue).opacity(0.4), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(title).font(Typography.display(26)).foregroundStyle(Color(DesignTokens.fg1))
                    chip()
                }
                subtitle().font(Typography.mono(13)).foregroundStyle(Color(DesignTokens.fg3)).lineLimit(1)
            }

            Spacer()
            HStack(spacing: 8) { actions() }
        }
    }
}
