import Combine
import SwiftUI

@MainActor
final class MediaPlaybackControl: ObservableObject {
    @Published var isPlaying = false
    var action: (() -> Void)?
}

struct MediaPlaybackButton: View {
    @ObservedObject var control: MediaPlaybackControl

    var body: some View {
        Button {
            guard let action = control.action else { return }
            ActionFeedback.light()
            action()
        } label: {
            Image(systemName: control.isPlaying ? "pause.fill" : "play.fill")
                .font(.title3)
                .frame(width: ActionButtonLayout.height, height: ActionButtonLayout.height)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(control.isPlaying ? "Pause" : "Play")
    }
}
