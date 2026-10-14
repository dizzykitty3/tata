import SwiftUI

struct MediaPlayButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button {
                ActionFeedback.light()
                action()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(
                        color: .black.opacity(0.4),
                        radius: 8
                    )
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(
                    color: .black.opacity(0.4),
                    radius: 4
                )
        }
    }
}
