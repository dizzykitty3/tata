import SwiftUI
import Photos

struct ImageView: View {
    let asset: PHAsset
    let targetSize: CGSize
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var generation = UUID()

    init(
        asset: PHAsset,
        targetSize: CGSize = PHImageManagerMaximumSize,
        contentMode: ContentMode = .fit
    ) {
        self.asset = asset
        self.targetSize = targetSize
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ProgressView()
            }
        }
        .task(id: "\(asset.localIdentifier)-\(targetSize)") {
            cancelRequest()
            image = nil
            let token = generation
            requestID = PhotoService.shared.requestImage(asset: asset, size: targetSize) { result in
                Task { @MainActor in
                    guard generation == token else { return }
                    image = result
                }
            }
        }
        .onDisappear { cancelRequest() }
    }

    private func cancelRequest() {
        generation = UUID()
        if let requestID { PhotoService.shared.cancelImageRequest(requestID) }
        requestID = nil
    }
}
