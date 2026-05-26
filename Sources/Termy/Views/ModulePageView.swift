import SwiftUI
import TermyCore

/// The reusable module shell (DESIGN.md §4.1): a 56pt breadcrumb bar over a
/// content region. The content (sub-rail + body, or a full-width bridged body)
/// is supplied by the caller. An optional `actions` slot places icon-buttons on
/// the right of the breadcrumb; an `alert` flag tints the bar amber and draws
/// an edge ring (used by the Agents canary when an agent needs attention).
struct ModulePageView<Content: View, Actions: View>: View {
    @ObservedObject var store: TermyStore
    let module: ShellNavigationModel.Module
    var alert: Bool = false
    /// Optional mono third segment (DESIGN.md §4.1 trail): `Desktop / Shell / termy`.
    /// Omitted when nil/empty so a blank `/` segment never renders.
    var trailingCrumb: String? = nil
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            breadcrumb
            Divider().overlay(Color(DesignTokens.hair))
            // Bound the body to the available content area. A tall body (e.g. the
            // transitional Settings `Form` / Connections form) would otherwise
            // impose a min height larger than the window, overflow this VStack,
            // and push the breadcrumb + the global tab/status bars off-screen.
            // GeometryReader hands the body an exact size (scrolling content then
            // scrolls in place) without propagating its min upward.
            GeometryReader { geo in
                content()
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .background(Color(DesignTokens.bg0))
        .overlay {
            if alert {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color(DesignTokens.agent.base).opacity(0.55), lineWidth: 2)
                    .blur(radius: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 10) {
            Button { store.goToDesktop() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(DesignTokens.fg3))
            .frame(width: 30, height: 30)
            .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            .help("Back to Desktop (⌘0)")

            Image(systemName: module.systemImage)
                .font(.system(size: 14))
                .foregroundStyle(Color(TermyDesign.areaToken(module.area)))
                .frame(width: 28, height: 28)
                .background(Color(TermyDesign.areaToken(module.area)).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))

            HStack(spacing: 6) {
                Text("Desktop").foregroundStyle(Color(DesignTokens.fg4))
                Text("/").foregroundStyle(Color(DesignTokens.fg5))
                Text(module.title).foregroundStyle(Color(DesignTokens.fg1)).fontWeight(.medium)
                if let trailingCrumb, !trailingCrumb.isEmpty {
                    Text("/").foregroundStyle(Color(DesignTokens.fg5))
                    Text(trailingCrumb).font(Typography.mono(13))
                        .foregroundStyle(Color(DesignTokens.fg1)).lineLimit(1)
                }
            }
            .font(Typography.ui(13))

            Spacer()

            HStack(spacing: 8) { actions() }
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(alert
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Color(DesignTokens.agent.base).opacity(0.16), Color(DesignTokens.bg1)],
                        startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color(DesignTokens.bg1)))
    }
}

/// Keeps the existing actionless callers (Slice-1/2) compiling unchanged.
extension ModulePageView where Actions == EmptyView {
    init(store: TermyStore, module: ShellNavigationModel.Module, alert: Bool = false,
         trailingCrumb: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(store: store, module: module, alert: alert, trailingCrumb: trailingCrumb,
                  actions: { EmptyView() }, content: content)
    }
}

/// The 280pt left sub-rail scaffold (DESIGN.md §4.2): section header + search +
/// item list. Slice 1 provides the chrome; module-specific items arrive with
/// each module's port.
struct ModuleSubRailView<Items: View>: View {
    let title: String
    var count: Int? = nil
    /// String count (DESIGN.md §6.1 "3 local · 2 remote"); takes precedence over
    /// the bare `count` Int kept for the Agents/Workspaces callers.
    var countText: String? = nil
    var searchPlaceholder: String? = nil
    /// Optional kbd hint on the right of the search field (e.g. "⌘P").
    var searchShortcut: String? = nil
    @Binding var search: String
    @ViewBuilder var items: () -> Items

    private var countLabel: String? { countText ?? count.map { "\($0)" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(Typography.ui(11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color(DesignTokens.fg4))
                Spacer()
                if let countLabel {
                    Text(countLabel).font(Typography.ui(11)).foregroundStyle(Color(DesignTokens.fg3))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
                TextField(searchPlaceholder ?? "Search", text: $search)
                    .textFieldStyle(.plain).font(Typography.ui(12))
                if let searchShortcut {
                    TermyKbd(searchShortcut, size: 10.5)
                }
            }
            .foregroundStyle(Color(DesignTokens.fg3))
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(Color(DesignTokens.bg2), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm).stroke(Color(DesignTokens.hair2), lineWidth: 1))

            ScrollView { VStack(alignment: .leading, spacing: 6) { items() } }
            Spacer()
        }
        .padding(12)
        .frame(width: 280)
        .background(Color(DesignTokens.bg1))
        .overlay(alignment: .trailing) { Rectangle().fill(Color(DesignTokens.hair)).frame(width: 1) }
    }
}
