import AVFAudio
import Combine
import Foundation

@MainActor
final class MediaPlaybackMuteController: NSObject, ObservableObject {
    static let shared = MediaPlaybackMuteController()

    private static let builtInKey = "muteBuiltInOutputByDefault"
    private static let externalKey = "muteExternalOutputByDefault"

    @Published var muteBuiltInByDefault: Bool {
        didSet {
            UserDefaults.standard.set(muteBuiltInByDefault, forKey: Self.builtInKey)
            if !externalOutput { manualMute = nil }
        }
    }
    @Published var muteExternalByDefault: Bool {
        didSet {
            UserDefaults.standard.set(muteExternalByDefault, forKey: Self.externalKey)
            if externalOutput { manualMute = nil }
        }
    }

    @Published private var externalOutput = false
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
        let legacy = defaults.bool(forKey: "muteMediaByDefault")
        for key in [Self.builtInKey, Self.externalKey] where defaults.object(forKey: key) == nil {
            defaults.set(legacy, forKey: key)
        }
        muteBuiltInByDefault = defaults.bool(forKey: Self.builtInKey)
        muteExternalByDefault = defaults.bool(forKey: Self.externalKey)
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
        // Prefer the built-in policy if any sound could reach the device speaker.
        externalOutput = !outputs.isEmpty && outputs.allSatisfy {
            $0.portType != .builtInSpeaker && $0.portType != .builtInReceiver
        }
        manualMute = nil
        lastRouteChange = ProcessInfo.processInfo.systemUptime
    }

    var shouldMuteNewPlayback: Bool {
        manualMute ?? (externalOutput ? muteExternalByDefault : muteBuiltInByDefault)
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
