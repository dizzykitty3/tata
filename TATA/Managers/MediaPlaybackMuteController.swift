import AVFAudio
import Combine
import Foundation

@MainActor
final class MediaPlaybackMuteController: NSObject, ObservableObject {
    static let shared = MediaPlaybackMuteController()

    private static let muteKey = "muteMediaByDefault"

    @Published var muteByDefault: Bool {
        didSet {
            UserDefaults.standard.set(muteByDefault, forKey: Self.muteKey)
            manualMute = nil
        }
    }

    private var outputIDs: Set<String> = []
    private var lastRouteChange: TimeInterval = -.infinity

    @Published private var manualMute: Bool?

    func toggleMute() {
        manualMute = !shouldMuteNewPlayback
    }

    private let audioSession = AVAudioSession.sharedInstance()
    private var outputVolumeObservation: NSKeyValueObservation?
    private var mutedPlaybackCount = 0

    private override init() {
        let defaults = UserDefaults.standard
        let builtInKey = "muteBuiltInOutputByDefault"
        let externalKey = "muteExternalOutputByDefault"
        if let previous = defaults.object(forKey: builtInKey) as? Bool
            ?? (defaults.object(forKey: externalKey) as? Bool) {
            defaults.set(previous, forKey: Self.muteKey)
            defaults.removeObject(forKey: builtInKey)
            defaults.removeObject(forKey: externalKey)
        }
        muteByDefault = defaults.bool(forKey: Self.muteKey)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged),
            name: AVAudioSession.routeChangeNotification, object: audioSession)
        updateRoute()
    }

    @objc private nonisolated func routeChanged(_ notification: Notification) {
        Task { @MainActor in updateRoute() }
    }

    private func updateRoute() {
        let outputs = audioSession.currentRoute.outputs
        let ids = Set(outputs.map(\.uid))
        guard ids != outputIDs else { return }
        outputIDs = ids
        manualMute = nil
        lastRouteChange = ProcessInfo.processInfo.systemUptime
    }

    var shouldMuteNewPlayback: Bool {
        manualMute ?? muteByDefault
    }

    func beginMutedPlaybackIfNeeded() -> Bool {
        updateRoute()
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
        updateRoute()
        // A route switch also changes outputVolume to the new device’s volume.
        guard ProcessInfo.processInfo.systemUptime - lastRouteChange > 1,
              mutedPlaybackCount > 0 else {
            return
        }

        manualMute = false
    }
}
