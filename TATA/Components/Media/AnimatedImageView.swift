import Combine
import ImageIO
import Photos
import SwiftUI
import UniformTypeIdentifiers

extension PHAsset {
    nonisolated var isGIF: Bool {
        guard mediaType == .image, !mediaSubtypes.contains(.photoLive) else {
            return false
        }
        return PHAssetResource.assetResources(for: self).contains {
            UTType($0.uniformTypeIdentifier)?.conforms(to: .gif) == true
        }
    }
}

/// Keeps thumbnails static and loads original animation data only while visible.
struct AnimatedImageView: View {
    let asset: PHAsset
    let targetSize: CGSize
    let contentMode: ContentMode

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback = GIFPlayback()
    @State private var isVisible = false

    var body: some View {
        ImageView(asset: asset, targetSize: targetSize, contentMode: contentMode)
            .opacity(playback.frame == nil ? 1 : 0)
            .overlay {
                if let frame = playback.frame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            }
            .onAppear {
                isVisible = true
                if scenePhase == .active { playback.start(asset: asset) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, isVisible {
                    playback.start(asset: asset)
                } else {
                    playback.stop()
                }
            }
            .onChange(of: asset.localIdentifier) { _, _ in
                playback.stop()
                if scenePhase == .active, isVisible { playback.start(asset: asset) }
            }
            .onDisappear {
                isVisible = false
                playback.stop()
            }
    }
}

@MainActor
private final class GIFPlayback: ObservableObject {
    @Published private(set) var frame: UIImage?
    private var requestID: PHImageRequestID?
    private var generation = UUID()
    private var activeIdentifier: String?

    func start(asset: PHAsset) {
        guard activeIdentifier != asset.localIdentifier else { return }
        stop()
        activeIdentifier = asset.localIdentifier
        let token = generation
        let options = PHImageRequestOptions()
        options.version = .original
        options.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImageDataAndOrientation(
            for: asset, options: options
        ) { [weak self] data, _, _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.requestID = nil
                guard let data,
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      CGImageSourceGetCount(source) > 1 else { return }
                // Image I/O delivers frames on the main queue using GIF timing and loops.
                CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self] _, image, stop in
                    MainActor.assumeIsolated {
                        guard let self, self.generation == token else {
                            stop.pointee = true
                            return
                        }
                        self.frame = UIImage(cgImage: image)
                    }
                }
            }
        }
    }

    func stop() {
        generation = UUID()
        activeIdentifier = nil
        if let requestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        requestID = nil
        frame = nil
    }
}
