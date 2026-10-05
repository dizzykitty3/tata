import SwiftUI

struct MediaCountText: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        Text(text)
            .contentTransition(.opacity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: text)
            .opacity(isVisible || reduceMotion ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isVisible = true
                }
            }
            .onDisappear {
                // Prepare a fresh fade when returning from the media grid.
                isVisible = false
            }
    }
}
