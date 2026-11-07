import SwiftUI
import Photos

struct ImageView: View {
    let asset: PHAsset
    let targetSize: CGSize
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var imageIdentity: String
    @State private var previewRequestID: PHImageRequestID?
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
        _image = State(initialValue: Self.cachedDisplayImage(asset: asset, size: targetSize))
        _imageIdentity = State(initialValue: "\(asset.localIdentifier)-\(targetSize)")
    }

    private var identity: String { "\(asset.localIdentifier)-\(targetSize)" }

    private static func cachedDisplayImage(asset: PHAsset, size: CGSize) -> UIImage? {
        if let cached = PhotoService.shared.cachedImage(asset: asset, size: size) { return cached }
        guard size == PHImageManagerMaximumSize else { return nil }
        return PhotoService.shared.cachedImage(asset: asset, size: PhotoService.browsingImageSize)
    }

    var body: some View {
        Group {
            if imageIdentity == identity, let image {
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
                image = Self.cachedDisplayImage(asset: asset, size: targetSize)
                imageIdentity = identity
            }
            if let cached = PhotoService.shared.cachedImage(asset: asset, size: targetSize) {
                image = cached
                return
            }

            let token = generation
            if targetSize == PHImageManagerMaximumSize, image == nil {
                previewRequestID = PhotoService.shared.requestImage(asset: asset, size: PhotoService.browsingImageSize) { preview in
                    Task { @MainActor in
                        guard generation == token, image == nil else { return }
                        image = preview
                    }
                }
            }
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
        if let previewRequestID { PhotoService.shared.cancelImageRequest(previewRequestID) }
        previewRequestID = nil
        requestID = nil
    }
}
