import SwiftUI
import Photos

struct VideoThumbnailView: View {
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
                MediaPlayButton(title: "Video") {
                    isShowingPlayer = true
                }
            }
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
