import SwiftUI
import Photos

struct MediaView: View {
    let asset: PHAsset
    var showsPlaybackButton = false
    var playsAnimatedImages = false
    var autoplaysLivePhoto = false
    var autoplaysVideo = false
    var playbackControl: MediaPlaybackControl? = nil
    var targetSize: CGSize = PHImageManagerMaximumSize
    var contentMode: ContentMode = .fit
    var deletionManager: DeletionManager?
    var deletionSource: DeletionManager.Source?

    var body: some View {
        if asset.mediaSubtypes.contains(.photoLive) {
            LivePhotoView(
                asset: asset,
                showsPlaybackButton: showsPlaybackButton,
                autoplaysOnce: autoplaysLivePhoto,
                playbackControl: playbackControl,
                targetSize: targetSize,
                contentMode: contentMode,
                deletionManager: deletionManager,
                deletionSource: deletionSource
            )
        } else if asset.mediaType == .video {
            VideoThumbnailView(
                asset: asset,
                showsPlaybackButton: showsPlaybackButton,
                autoplaysOnce: autoplaysVideo,
                playbackControl: playbackControl,
                targetSize: targetSize,
                contentMode: contentMode,
                deletionManager: deletionManager,
                deletionSource: deletionSource
            )
        } else if playsAnimatedImages {
            AnimatedImageView(asset: asset, targetSize: targetSize, contentMode: contentMode)
        } else {
            ImageView(
                asset: asset,
                targetSize: targetSize,
                contentMode: contentMode
            )
        }
    }
}

struct LivePhotoView: View {
    let asset: PHAsset
    let showsPlaybackButton: Bool
    let autoplaysOnce: Bool
    var playbackControl: MediaPlaybackControl? = nil
    @State private var replayID = 0
    @State private var manuallyPlaying = false
    let targetSize: CGSize
    let contentMode: ContentMode
    let deletionManager: DeletionManager?
    let deletionSource: DeletionManager.Source?

    @State private var isShowingPlayer = false
    @State private var isVisible = false
    @State private var hasAutoplayed = false
    @State private var autoplayReady = false
    private var shouldAutoplay: Bool {
        autoplaysOnce && isVisible && scenePhase == .active && !isShowingPlayer
    }
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var muteController = MediaPlaybackMuteController.shared

    var body: some View {
        ZStack {
            ImageView(
                asset: asset,
                targetSize: targetSize,
                contentMode: contentMode
            )

            if autoplaysOnce || manuallyPlaying {
                InlineLivePhotoPlayer(
                    asset: asset,
                    isActive: isVisible && scenePhase == .active && !isShowingPlayer && (manuallyPlaying || (shouldAutoplay && autoplayReady)),
                    hasPlayed: hasAutoplayed,
                    hasManualVolumeOverride: muteController.hasManualVolumeOverride,
                    contentMode: contentMode,
                    onStart: { hasAutoplayed = true }
                )
                .id(replayID)
                .allowsHitTesting(false)
            }

            if showsPlaybackButton && !autoplaysOnce && playbackControl == nil {
                MediaPlayButton(title: "LivePhoto") {
                    isShowingPlayer = true
                }
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            isVisible = true
            playbackControl?.isPlaying = false
            playbackControl?.action = {
                hasAutoplayed = false
                manuallyPlaying = true
                replayID += 1
            }
        }
        .onDisappear { isVisible = false; autoplayReady = false }
        .task(id: shouldAutoplay) {
            autoplayReady = false
            guard shouldAutoplay else { return }
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                autoplayReady = true
            } catch {}
        }
        .sheet(isPresented: $isShowingPlayer) {
            NavigationStack {
                LivePhotoPlayerSheet(
                    asset: asset,
                    deletionManager: deletionManager,
                    deletionSource: deletionSource
                )
                    .navigationTitle("Live Photo Playback")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
