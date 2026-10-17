import SwiftUI

struct MediaCountText: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        CrossfadeText(text: text)
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

/// Keep data transitions local to the text, including with Reduce Motion enabled.
struct CrossfadeText: View {
    let text: String

    var body: some View {
        ZStack {
            Text(text)
                .id(text)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }
}

struct PendingDeletionCountLabel: View {
    let count: Int

    var body: some View {
        Label {
            CrossfadeText(text: count.formatted())
                .monospacedDigit()
        } icon: {
            Image(systemName: "trash")
        }
    }
}
