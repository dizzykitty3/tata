import SwiftUI
import Photos

struct VideoThumbnailView: View {
    let asset: PHAsset
    let showsPlaybackButton: Bool
    var autoplaysOnce = false
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

            if autoplaysOnce, let player = playback.player {
                PlayerLayerView(player: player)
                    .allowsHitTesting(false)
            }

            if showsPlaybackButton && !autoplaysOnce {
                MediaPlayButton(title: "Video") {
                    isShowingPlayer = true
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                guard showsPlaybackButton && autoplaysOnce else { return }
                isShowingPlayer = true
            },
            including: showsPlaybackButton && autoplaysOnce ? .all : .none
        )
        .accessibilityAction(named: Text("Play Video Fullscreen")) {
            if showsPlaybackButton { isShowingPlayer = true }
        }
        .onAppear { isVisible = true }
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
