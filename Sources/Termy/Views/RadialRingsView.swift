import SwiftUI
import TermyCore

/// §3.2 decorative orbital rings + the animated pulsing ring, sized to the
/// 440pt dock. Reduce Motion freezes the pulse to a static faint ring.
struct RadialRingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach([190.0, 300.0, 420.0], id: \.self) { d in
                Circle()
                    .stroke(Color(DesignTokens.hair2).opacity(0.5), lineWidth: 1)
                    .frame(width: d, height: d)
            }
            Circle()
                .stroke(Color(DesignTokens.primary).opacity(0.4), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(pulse ? 1.45 : 1.0)
                .opacity(pulse ? 0 : 0.4)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 3.5).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
