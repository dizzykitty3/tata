import SwiftUI
import Photos
import PhotosUI
import UIKit

struct LivePhotoPlayerSheet: View {
    let asset: PHAsset

    @ObservedObject
    private var muteController = MediaPlaybackMuteController.shared

    @State private var livePhoto: PHLivePhoto?
    @State private var isMutedByDefault = false
    @State private var startedMutedPlayback = false
    @State private var isPlaybackViewVisible = false

    private var aspectRatio: CGFloat {
        guard asset.pixelHeight > 0 else {
            return 1
        }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    var body: some View {
        Group {
            if let livePhoto {
                GeometryReader { proxy in
                    let containerRatio = proxy.size.width / proxy.size.height
                    let fittedSize: CGSize = {
                        if aspectRatio > containerRatio {
                            let width = proxy.size.width
                            return CGSize(
                                width: width,
                                height: width / aspectRatio
                            )
                        } else {
                            let height = proxy.size.height
                            return CGSize(
                                width: height * aspectRatio,
                                height: height
                            )
                        }
                    }()

                    LivePhotoPlayerView(
                        livePhoto: livePhoto,
                        isMuted: isMutedByDefault
                    )
                        .frame(
                            width: fittedSize.width,
                            height: fittedSize.height
                        )
                        .position(
                            x: proxy.size.width / 2,
                            y: proxy.size.height / 2
                        )
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            isPlaybackViewVisible = true
        }
        .task {
            PhotoService.shared.requestLivePhoto(asset: asset) { livePhoto in
                guard let livePhoto, isPlaybackViewVisible else {
                    return
                }

                isMutedByDefault = muteController.beginMutedPlaybackIfNeeded()
                startedMutedPlayback = isMutedByDefault
                self.livePhoto = livePhoto
            }
        }
        .onChange(of: muteController.hasManualVolumeOverride) { _, hasOverride in
            guard hasOverride, isMutedByDefault else {
                return
            }

            isMutedByDefault = false
        }
        .onDisappear {
            isPlaybackViewVisible = false
            muteController.endMutedPlaybackIfNeeded(startedMutedPlayback)
            startedMutedPlayback = false
        }
    }
}

struct LivePhotoPlayerView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    let isMuted: Bool

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.isMuted = isMuted
        DispatchQueue.main.async {
            view.startPlayback(with: .full)
        }
        return view
    }

    func updateUIView(
        _ uiView: PHLivePhotoView,
        context: Context
    ) {
        uiView.livePhoto = livePhoto
        uiView.isMuted = isMuted
    }
}
