import SwiftUI

/// Sizes columns using the container, including resizable windows and sheets.
struct AdaptiveMediaGrid<Content: View>: View {
    private let spacing: CGFloat = 2
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns(for: proxy.size.width), spacing: spacing) {
                    content()
                }
            }
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        if width < 600 {
            return Array(
                repeating: GridItem(.flexible(), spacing: spacing),
                count: 3
            )
        }

        return [GridItem(.adaptive(minimum: 150), spacing: spacing)]
    }
}
