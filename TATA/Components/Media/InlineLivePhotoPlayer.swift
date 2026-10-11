import Photos
import PhotosUI
import SwiftUI

struct InlineLivePhotoPlayer: UIViewRepresentable {
    let asset: PHAsset
    let isActive: Bool
    let hasPlayed: Bool
    let hasManualVolumeOverride: Bool
    let contentMode: ContentMode
    let onStart: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.delegate = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        view.contentMode = contentMode == .fit ? .scaleAspectFit : .scaleAspectFill
        view.clipsToBounds = true
        context.coordinator.update(self)
    }

    static func dismantleUIView(_ view: PHLivePhotoView, coordinator: Coordinator) {
        coordinator.stop()
        view.delegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, PHLivePhotoViewDelegate {
        weak var view: PHLivePhotoView?
        private var requestID: PHImageRequestID?
        private var generation = UUID()
        private var isPlaying = false
        private var didStart = false
        private var startedMuted = false
        private var configuration: InlineLivePhotoPlayer?

        func update(_ configuration: InlineLivePhotoPlayer) {
            self.configuration = configuration
            guard configuration.isActive else {
                stop()
                return
            }
            if configuration.hasManualVolumeOverride { view?.isMuted = false }
            guard !configuration.hasPlayed, !didStart, requestID == nil else { return }
            let token = UUID()
            generation = token
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            requestID = PHImageManager.default().requestLivePhoto(
                for: configuration.asset,
                targetSize: CGSize(width: 1200, height: 1200),
                contentMode: .aspectFit,
                options: options
            ) { [weak self] photo, info in
                guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token,
                          let configuration = self.configuration, configuration.isActive else { return }
                    self.requestID = nil
                    guard let photo, let view = self.view,
                          !self.didStart, !configuration.hasPlayed else { return }
                    self.didStart = true
                    self.startedMuted = MediaPlaybackMuteController.shared.beginMutedPlaybackIfNeeded()
                    view.isMuted = self.startedMuted
                    view.livePhoto = photo
                    self.isPlaying = true
                    configuration.onStart()
                    view.startPlayback(with: .full)
                }
            }
        }

        func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            finishPlayback()
        }

        private func finishPlayback() {
            guard isPlaying else { return }
            isPlaying = false
            MediaPlaybackMuteController.shared.endMutedPlaybackIfNeeded(startedMuted)
            startedMuted = false
        }

        func stop() {
            generation = UUID()
            if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
            requestID = nil
            view?.stopPlayback()
            finishPlayback()
            view?.livePhoto = nil
        }
    }
}
