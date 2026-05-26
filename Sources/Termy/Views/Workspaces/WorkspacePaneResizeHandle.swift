import SwiftUI
import TermyCore

// Moved out of the retired ShellTabBodyView (Slice 3). Shared by the Workspaces
// §6.7 pane-tree viz (the sole remaining consumer); the live Shell pane-tree is gone.

struct WorkspacePaneResizeHandle: View {
    let axis: WorkspaceSplitAxis
    let path: [WorkspacePaneTreeBranch]
    let containerLength: Double
    @ObservedObject var store: TermyStore
    var showsGrip = false
    @State private var previousTranslation: CGSize = .zero
    @State private var hovering = false

    var body: some View {
        Rectangle()
            .fill(TermyDesign.border)
            .frame(width: axis == .horizontal ? (showsGrip ? 4 : 5) : nil,
                   height: axis == .vertical ? (showsGrip ? 4 : 5) : nil)
            .overlay {
                if showsGrip {
                    Circle()
                        .fill(Color(hovering ? DesignTokens.primary : DesignTokens.hairStrong))
                        .frame(width: 6, height: 6)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let current = axis == .horizontal ? value.translation.width : value.translation.height
                        let previous = axis == .horizontal ? previousTranslation.width : previousTranslation.height
                        store.resizePaneSplit(at: path, byDraggingPixels: current - previous, inContainerLength: containerLength)
                        previousTranslation = value.translation
                    }
                    .onEnded { _ in
                        previousTranslation = .zero
                        store.finishPaneSplitResize()
                    }
            )
            .help("Drag to resize split")
    }
}
