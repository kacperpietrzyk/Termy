import SwiftUI
import TermyCore

/// §3.2 radial dock: rings + center + 8 module orbs in stable §3.2 order,
/// reveal-staggered on mount.
struct RadialDockView: View {
    @ObservedObject var store: TermyStore
    @State private var revealed = false

    private static let radius: CGFloat = 185
    private static let modules = ShellNavigationModel.Module.allCases

    var body: some View {
        ZStack {
            RadialRingsView()
            RadialCenterView(store: store)
            ForEach(Array(Self.modules.enumerated()), id: \.element) { index, module in
                let pos = DesktopModel.radialOrbPosition(index: index,
                                                         count: Self.modules.count,
                                                         radius: Self.radius)
                ModuleOrbView(store: store, module: module, index: index, revealed: revealed)
                    .offset(x: pos.x, y: pos.y)
            }
        }
        .frame(width: 440, height: 440)
        .onAppear { revealed = true }
    }
}
