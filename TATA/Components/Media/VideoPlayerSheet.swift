import SwiftUI
import Photos
import AVKit
import UIKit

struct VideoPlayerSheet: View {
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

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        IncludedAlbumsPills(asset: asset)
                        VideoMetadataPill(asset: asset)
                    }
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.leading, 16)

                Spacer()

                MediaDetailActionBar(
                    asset: asset,
                    deletionManager: deletionManager,
                    deletionSource: deletionSource,
                    dismiss: { dismiss() }
                )
                    .padding(.bottom, 16)
            }
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
        .onChange(of: muteController.hasManualVolumeOverride) { _, hasOverride in
            guard hasOverride, isMutedByDefault else {
                return
            }

            player?.isMuted = false
            isMutedByDefault = false
        }
        .onDisappear {
            isPlaybackViewVisible = false
            muteController.endMutedPlaybackIfNeeded(startedMutedPlayback)
            startedMutedPlayback = false
            player?.pause()
        }
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

private struct VideoMetadataPill: View {
    let asset: PHAsset

    @State private var fileSize: Int64?
    @State private var isLoadingSize = true

    var body: some View {
        Text("\(formattedDuration) \(fileSize.map(Self.formatSize) ?? (isLoadingSize ? "…" : "—"))")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Color(uiColor: .systemGray).opacity(0.55),
                in: Capsule()
            )
            .task(id: asset.localIdentifier) {
                fileSize = nil
                isLoadingSize = true
                defer { isLoadingSize = false }
                do {
                    let size = try await PhotoService.shared.videoFileSize(asset: asset)
                    try Task.checkCancellation()
                    fileSize = size
                } catch {
                    // Keep the duration visible if the resource is unavailable.
                }
            }
    }

    private var formattedDuration: String {
        let duration = asset.duration
        let seconds = duration.isFinite ? Int(max(0, duration)) : 0
        if seconds >= 3600 {
            return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    nonisolated private static func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
            .filter { !$0.isWhitespace }
    }
}
