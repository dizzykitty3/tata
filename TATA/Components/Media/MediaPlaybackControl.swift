import AVKit
import Combine
import SwiftUI

@MainActor
final class MediaPlaybackControl: ObservableObject {
    @Published var isPlaying = false
    @Published var videoPlayer: AVPlayer?
    var videoAssetIdentifier: String?
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

struct MediaMuteButton: View {
    @ObservedObject private var muteController = MediaPlaybackMuteController.shared
    @AppStorage(MediaPlaybackMuteController.defaultMuteKey) private var defaultMute = false

    var body: some View {
        Button {
            ActionFeedback.light()
            muteController.toggleMute()
        } label: {
            Image(systemName: muteController.shouldMuteNewPlayback ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.title3)
                .frame(width: ActionButtonLayout.height, height: ActionButtonLayout.height)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(muteController.shouldMuteNewPlayback ? "Unmute" : "Mute")
    }
}
