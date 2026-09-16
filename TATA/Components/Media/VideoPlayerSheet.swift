import SwiftUI
import Photos
import AVKit
import UIKit

struct VideoPlayerSheet: View {
    let asset: PHAsset

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
                    IncludedAlbumsPills(asset: asset)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.leading, 16)

                Spacer()

                MediaShareButton(asset: asset)
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
