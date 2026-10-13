import SwiftUI
import Photos

struct ImageView: View {
    let asset: PHAsset
    let targetSize: CGSize
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var imageIdentity: String
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
        _image = State(initialValue: PhotoService.shared.cachedImage(asset: asset, size: targetSize))
        _imageIdentity = State(initialValue: "\(asset.localIdentifier)-\(targetSize)")
    }

    private var identity: String { "\(asset.localIdentifier)-\(targetSize)" }

    private var displayedImage: UIImage? {
        if imageIdentity == identity, let image { return image }
        return PhotoService.shared.cachedImage(asset: asset, size: targetSize)
    }

    var body: some View {
        Group {
            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ProgressView()
            }
        }
        .task(id: identity) {
            cancelRequest()
            if imageIdentity != identity {
                image = PhotoService.shared.cachedImage(asset: asset, size: targetSize)
                imageIdentity = identity
            }
            guard image == nil else { return }
            let token = generation
            requestID = PhotoService.shared.requestImage(asset: asset, size: targetSize) { result in
                Task { @MainActor in
                    guard generation == token else { return }
                    if let result { image = result }
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
