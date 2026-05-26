import SwiftUI
import TermyCore

/// The 44pt top tab bar (DESIGN.md §1.2): traffic-light inset · Desktop Tab 0
/// (permanent, glowing violet dot) + dynamic module tabs · right cluster
/// (⌘K pill, notifications, avatar).
struct TabBarView: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        HStack(spacing: 4) {
            // Reserve the system traffic-light inset (§1.2).
            Spacer().frame(width: 78)

            DesktopTab(isActive: store.activeTab == .desktop) {
                store.goToDesktop()
            }

            ForEach(store.openTabs) { module in
                ModuleTab(
                    module: module,
                    isActive: store.activeTab == .module(module),
                    onSelect: { store.goToTab(.module(module)) },
                    onClose: { store.closeModuleTab(module) }
                )
            }

            Button {
                store.goToDesktop()
            } label: {
                Image(systemName: "plus").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(DesignTokens.fg3))
            .frame(width: 26, height: 26)
            .help("Desktop (⌘0)")

            Spacer(minLength: 12)

            TabBarRightCluster(store: store)
        }
        .padding(.horizontal, 6)
        .frame(height: 44)
        .background(Color(DesignTokens.bg1))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(DesignTokens.hair)).frame(height: 1)
        }
    }
}

private struct DesktopTab: View {
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(DesignTokens.primary))
                    .frame(width: 9, height: 9)
                    .shadow(color: Color(DesignTokens.primary).opacity(0.9), radius: 5)
                Text("Desktop").font(Typography.ui(13, weight: .semibold))
            }
            .foregroundStyle(Color(isActive ? DesignTokens.fg1 : DesignTokens.fg3))
            .padding(.horizontal, 12)
            .frame(minWidth: 134, minHeight: 32, alignment: .leading)
            .background(tabBackground(isActive: isActive))
        }
        .buttonStyle(.plain)
        .help("Desktop (⌘0)")
    }
}

private struct ModuleTab: View {
    let module: ShellNavigationModel.Module
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 7) {
                Image(systemName: module.systemImage).font(.system(size: 12))
                Text(module.title).font(Typography.ui(13)).lineLimit(1)
                if hovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(DesignTokens.fg4))
                        .contentShape(Rectangle())
                        .onTapGesture { onClose() }
                } else {
                    Spacer().frame(width: 12)
                }
            }
            .foregroundStyle(Color(isActive ? DesignTokens.fg1 : DesignTokens.fg3))
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(tabBackground(isActive: isActive))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Active tabs get a bg3 fill + 2px primary underline glow (§1.2).
@ViewBuilder
private func tabBackground(isActive: Bool) -> some View {
    ZStack(alignment: .bottom) {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
            .fill(isActive ? Color(DesignTokens.bg3) : .clear)
        if isActive {
            Rectangle()
                .fill(Color(DesignTokens.primary))
                .frame(height: 2)
                .shadow(color: Color(DesignTokens.primary).opacity(0.7), radius: 6)
        }
    }
}

private struct TabBarRightCluster: View {
    @ObservedObject var store: TermyStore

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.perform("open-command-center")
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12))
                    Text("Search or run a command").font(Typography.ui(12))
                    Text("⌘K").font(Typography.mono(11)).foregroundStyle(Color(DesignTokens.fg4))
                }
                .foregroundStyle(Color(DesignTokens.fg3))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color(DesignTokens.bg3), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(Color(DesignTokens.hair2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Image(systemName: "bolt.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(DesignTokens.fg3))
                .frame(width: 26, height: 26)

            Text("KP")
                .font(Typography.ui(10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    LinearGradient(colors: [Color(DesignTokens.primary), Color(DesignTokens.git.base)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
        }
    }
}
