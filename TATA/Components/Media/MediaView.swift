import SwiftUI
import Photos

struct MediaView: View {
    let asset: PHAsset
    var showsPlaybackButton = false
    var targetSize: CGSize = PHImageManagerMaximumSize
    var contentMode: ContentMode = .fit
    var deletionManager: DeletionManager?
    var deletionSource: DeletionManager.Source?

    var body: some View {
        if asset.mediaSubtypes.contains(.photoLive) {
            LivePhotoView(
                asset: asset,
                showsPlaybackButton: showsPlaybackButton,
                targetSize: targetSize,
                contentMode: contentMode,
                deletionManager: deletionManager,
                deletionSource: deletionSource
            )
        } else if asset.mediaType == .video {
            VideoThumbnailView(
                asset: asset,
                showsPlaybackButton: showsPlaybackButton,
                targetSize: targetSize,
                contentMode: contentMode,
                deletionManager: deletionManager,
                deletionSource: deletionSource
            )
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
    let targetSize: CGSize
    let contentMode: ContentMode
    let deletionManager: DeletionManager?
    let deletionSource: DeletionManager.Source?

    @State private var isShowingPlayer = false

    var body: some View {
        ZStack {
            ImageView(
                asset: asset,
                targetSize: targetSize,
                contentMode: contentMode
            )

            if showsPlaybackButton {
                MediaPlayButton(title: "LivePhoto") {
                    isShowingPlayer = true
                }
            }
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
