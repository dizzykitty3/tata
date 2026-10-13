import AVKit
import Combine
import Photos

@MainActor
final class InlineVideoPlayback: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isPlaying = false
    private var requestID: PHImageRequestID?
    private var generation = UUID()
    private var hasStarted = false
    private var startedMuted = false
    private var endObserver: NSObjectProtocol?

    func start(asset: PHAsset) {
        guard !hasStarted, requestID == nil else { return }
        let token = UUID()
        generation = token
        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.requestID = nil
                guard let item else { return }
                self.hasStarted = true
                let player = AVPlayer(playerItem: item)
                player.actionAtItemEnd = .pause
                self.startedMuted = MediaPlaybackMuteController.shared.beginMutedPlaybackIfNeeded()
                player.isMuted = self.startedMuted
                self.endObserver = NotificationCenter.default.addObserver(
                    forName: AVPlayerItem.didPlayToEndTimeNotification,
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        self.isPlaying = false
                        self.finishMutedPlayback()
                    }
                }
                self.player = player
                player.play()
                self.isPlaying = true
            }
        }
    }

    func toggle(asset: PHAsset) {
        if let player {
            if isPlaying {
                player.pause()
                isPlaying = false
                finishMutedPlayback()
            } else {
                if let item = player.currentItem, player.currentTime() >= item.duration {
                    player.seek(to: .zero)
                }
                startedMuted = MediaPlaybackMuteController.shared.beginMutedPlaybackIfNeeded()
                player.isMuted = startedMuted
                player.play()
                isPlaying = true
            }
        } else {
            hasStarted = false
            start(asset: asset)
        }
    }

    func stop() {
        isPlaying = false
        generation = UUID()
        if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
        requestID = nil
        player?.pause()
        player = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        finishMutedPlayback()
    }

    private func finishMutedPlayback() {
        MediaPlaybackMuteController.shared.endMutedPlaybackIfNeeded(startedMuted)
        startedMuted = false
    }
}
