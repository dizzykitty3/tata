import AVFAudio
import Combine
import Foundation

@MainActor
final class MediaPlaybackMuteController: NSObject, ObservableObject {
    static let shared = MediaPlaybackMuteController()

    static let defaultMuteKey = "muteMediaByDefault"

    @Published private(set) var hasManualVolumeOverride = false

    @Published private var manualMute: Bool?

    func toggleMute() {
        manualMute = !shouldMuteNewPlayback
    }

    private let audioSession = AVAudioSession.sharedInstance()
    private var outputVolumeObservation: NSKeyValueObservation?
    private var mutedPlaybackCount = 0

    private override init() {
        super.init()
    }

    var shouldMuteNewPlayback: Bool {
        manualMute ?? (UserDefaults.standard.bool(forKey: Self.defaultMuteKey) &&
            !hasManualVolumeOverride)
    }

    func beginMutedPlaybackIfNeeded() -> Bool {
        guard shouldMuteNewPlayback else {
            return false
        }

        mutedPlaybackCount += 1
        observeSystemVolumeIfNeeded()
        return true
    }

    func endMutedPlaybackIfNeeded(_ wasMuted: Bool) {
        guard wasMuted else {
            return
        }

        mutedPlaybackCount = max(0, mutedPlaybackCount - 1)
    }

    private func observeSystemVolumeIfNeeded() {
        guard outputVolumeObservation == nil else {
            return
        }

        try? audioSession.setCategory(.ambient)
        try? audioSession.setActive(true)

        outputVolumeObservation = audioSession.observe(
            \.outputVolume,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleSystemVolumeChange()
            }
        }
    }

    private func handleSystemVolumeChange() {
        guard mutedPlaybackCount > 0 else {
            return
        }

        manualMute = false
        hasManualVolumeOverride = true
    }
}
