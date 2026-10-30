import SwiftUI
import Combine
import Photos
import AVKit
import UIKit

struct VideoPlayerSheet: View {
    @AppStorage("tapToHideMediaUI") private var tapToHideMediaUI = true
    @State private var isUIHidden = false

    let asset: PHAsset
    let deletionManager: DeletionManager?
    let deletionSource: DeletionManager.Source?

    @Environment(\.dismiss) private var dismiss

    init(
        asset: PHAsset,
        deletionManager: DeletionManager? = nil,
        deletionSource: DeletionManager.Source? = nil
    ) {
        self.asset = asset
        self.deletionManager = deletionManager
        self.deletionSource = deletionSource
    }

    @ObservedObject
    private var muteController = MediaPlaybackMuteController.shared

    @State private var player: AVPlayer?
    @State private var isMutedByDefault = false
    @State private var startedMutedPlayback = false
    @State private var isPlaybackViewVisible = false

    var body: some View {
        ZStack {
            Group {
                if let player {
                    PlayerLayerView(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            player.play()
                        }
                } else {
                    ProgressView()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if tapToHideMediaUI { isUIHidden.toggle() } }

            VStack {
                HStack {
                    MediaInfoOverlay(asset: asset)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.leading, 16)

                Spacer()

            }
            .mediaChromeHidden(tapToHideMediaUI && isUIHidden)
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if let player {
                    VideoControlsRow(player: player) { detailActions }
                        .id(ObjectIdentifier(player))
                } else {
                    detailActions
                }
            }
            .padding(.vertical, 12)
            .mediaChromeHidden(tapToHideMediaUI && isUIHidden)
        }
        .onChange(of: tapToHideMediaUI) { _, enabled in
            if !enabled { isUIHidden = false }
        }
        .onAppear {
            isPlaybackViewVisible = true
        }
        .task {
            PhotoService.shared.requestVideo(asset: asset) { avAsset in
                if let avAsset, isPlaybackViewVisible {
                    let player = AVPlayer(
                        playerItem: AVPlayerItem(asset: avAsset)
                    )
                    let shouldMute = muteController.beginMutedPlaybackIfNeeded()
                    player.isMuted = shouldMute
                    isMutedByDefault = shouldMute
                    startedMutedPlayback = shouldMute
                    self.player = player
                }
            }
        }
        .onChange(of: muteController.shouldMuteNewPlayback) { _, muted in
            isMutedByDefault = muted
            player?.isMuted = muted
        }
        .onDisappear {
            isPlaybackViewVisible = false
            muteController.endMutedPlaybackIfNeeded(startedMutedPlayback)
            startedMutedPlayback = false
            player?.pause()
        }
    }
    private var detailActions: some View {
        MediaDetailActionBar(
            asset: asset,
            deletionManager: deletionManager,
            deletionSource: deletionSource,
            dismiss: { dismiss() }
        )
    }

}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(
        _ uiView: PlayerContainerView,
        context: Context
    ) {
        uiView.playerLayer.player = player
    }
}

final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


@MainActor
final class VideoScrubber: ObservableObject {
    @Published var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    private var player: AVPlayer?
    private var observer: Any?
    private var generation = UUID()
    private var dragging = false
    private var seeking = false
    private var pendingTime: Double?
    private var resumeRate: Float = 0
    private var finishing = false

    func attach(_ player: AVPlayer) {
        guard self.player == nil else { return }
        self.player = player
        let token = generation
        updateTime()
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.updateTime()
            }
        }
    }

    func detach() {
        generation = UUID()
        if let observer, let player { player.removeTimeObserver(observer) }
        observer = nil
        player = nil
        dragging = false
        seeking = false
        finishing = false
        pendingTime = nil
    }

    func edit(_ editing: Bool) {
        guard let player else { return }
        if editing {
            guard !dragging else { return }
            if !finishing { resumeRate = player.rate }
            finishing = false
            dragging = true
            player.pause()
        } else if dragging {
            dragging = false
            finishing = true
            pendingTime = elapsed
            seekNext()
        }
    }

    func scrub(to value: Double) {
        // Also support accessibility adjustments that don't begin a touch drag.
        let standalone = !dragging
        if standalone { edit(true) }
        elapsed = min(max(value, 0), duration)
        pendingTime = elapsed
        seekNext()
        if standalone { edit(false) }
    }

    private func seekNext() {
        guard !seeking, let target = pendingTime, let player else { return }
        pendingTime = nil
        seeking = true
        let token = generation
        let tolerance = dragging ? CMTime(seconds: 0.08, preferredTimescale: 600) : .zero
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.seeking = false
                if self.pendingTime != nil {
                    self.seekNext()
                } else if self.finishing && !self.dragging {
                    self.finishing = false
                    if self.resumeRate > 0 { self.player?.playImmediately(atRate: self.resumeRate) }
                    self.updateTime()
                }
            }
        }
    }

    private func updateTime() {
        let seconds = player?.currentItem?.duration.seconds ?? 0
        duration = seconds.isFinite && seconds > 0 ? seconds : 0
        guard !dragging, !seeking, !finishing else { return }
        let current = player?.currentTime().seconds ?? 0
        elapsed = current.isFinite ? min(max(current, 0), duration) : 0
    }
}

struct VideoProgressBar: View {
    let player: AVPlayer
    @StateObject private var scrubber = VideoScrubber()

    var body: some View {
        HStack(spacing: 10) {
            Text(timeText(scrubber.elapsed))
            Slider(value: Binding(get: { scrubber.elapsed }, set: { scrubber.scrub(to: $0) }),
                   in: 0...max(scrubber.duration, 1), onEditingChanged: scrubber.edit)
                .disabled(scrubber.duration <= 0)
                .accessibilityLabel("Video progress")
                .accessibilityValue("\(timeText(scrubber.elapsed)) of \(timeText(scrubber.duration))")
            Text(timeText(scrubber.duration))
        }
        .font(.caption.monospacedDigit())
        .padding(.horizontal, 16)
        .frame(minHeight: 44, idealHeight: 44, maxHeight: .infinity)
        .glassEffect(.regular, in: .capsule)
        .onAppear { scrubber.attach(player) }
        .onDisappear { scrubber.detach() }
    }

    private func timeText(_ seconds: Double) -> String {
        let value = Int(max(seconds, 0))
        return value >= 3600
            ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
            : String(format: "%d:%02d", value / 60, value % 60)
    }
}

struct VideoControlsRow<Actions: View>: View {
    let player: AVPlayer
    @ViewBuilder var actions: () -> Actions
    @ScaledMetric private var minimumProgressWidth = 280.0

    var body: some View {
        VideoControlsLayout(minimumProgressWidth: minimumProgressWidth) {
            VideoProgressBar(player: player)
            HStack(spacing: 0) { actions() }
        }
        .padding(.horizontal, 24)
    }
}

/// Measure the actual action bar so split view and larger text can stack safely.
private struct VideoControlsLayout: Layout {
    let minimumProgressWidth: CGFloat
    private let spacing: CGFloat = 16

    private func horizontal(_ width: CGFloat, _ actions: CGSize) -> Bool {
        width >= max(560, minimumProgressWidth + actions.width + spacing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let actions = subviews[1].sizeThatFits(.unspecified)
        let width = proposal.width ?? minimumProgressWidth + actions.width + spacing
        let wide = horizontal(width, actions)
        let progress = subviews[0].sizeThatFits(ProposedViewSize(
            width: wide ? width - actions.width - spacing : width,
            height: wide ? max(44, actions.height) : 44
        ))
        return CGSize(width: width, height: wide ? max(progress.height, actions.height) : progress.height + spacing + actions.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let actions = subviews[1].sizeThatFits(.unspecified)
        if horizontal(bounds.width, actions) {
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                              proposal: ProposedViewSize(width: bounds.width - actions.width - spacing, height: bounds.height))
            subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing, proposal: .unspecified)
        } else {
            let progress = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: 44))
            subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: progress.height))
            subviews[1].place(at: CGPoint(x: bounds.midX, y: bounds.maxY), anchor: .bottom, proposal: .unspecified)
        }
    }
}
