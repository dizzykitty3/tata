import SwiftUI
import Photos

struct VideoThumbnailView: View {
    let asset: PHAsset
    let showsPlaybackButton: Bool
    var autoplaysOnce = false
    var playbackControl: MediaPlaybackControl? = nil
    let targetSize: CGSize
    let contentMode: ContentMode
    let deletionManager: DeletionManager?
    let deletionSource: DeletionManager.Source?

    @State private var isShowingPlayer = false
    @State private var isVisible = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = InlineVideoPlayback()
    @ObservedObject private var muteController = MediaPlaybackMuteController.shared

    private var shouldPlay: Bool {
        autoplaysOnce && isVisible && scenePhase == .active && !isShowingPlayer
    }

    var body: some View {
        ZStack {
            ImageView(
                asset: asset,
                targetSize: targetSize,
                contentMode: contentMode
            )

            if let player = playback.player {
                PlayerLayerView(player: player)
                    .allowsHitTesting(false)
            }

            if showsPlaybackButton && !autoplaysOnce && playbackControl == nil {
                MediaPlayButton(title: "Video") {
                    isShowingPlayer = true
                }
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            isVisible = true
            playbackControl?.isPlaying = playback.isPlaying
            playbackControl?.action = { playback.toggle(asset: asset) }
        }
        .onChange(of: playback.isPlaying) { _, playing in
            playbackControl?.isPlaying = playing
        }
        .onDisappear {
            isVisible = false
            playback.stop()
        }
        .task(id: shouldPlay) {
            guard shouldPlay else { playback.stop(); return }
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                playback.start(asset: asset)
            } catch {}
        }
        .onChange(of: muteController.hasManualVolumeOverride) { _, overridden in
            if overridden { playback.player?.isMuted = false }
        }
        .sheet(isPresented: $isShowingPlayer) {
            NavigationStack {
                VideoPlayerSheet(
                    asset: asset,
                    deletionManager: deletionManager,
                    deletionSource: deletionSource
                )
                    .navigationTitle("Video Playback")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
