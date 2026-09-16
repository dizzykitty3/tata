import Photos
import SwiftUI
import UIKit

struct IncludedAlbumsPills: View {
    let asset: PHAsset

    @State private var albumTitles: [String] = []
    @State private var showsAllAlbums = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !albumTitles.isEmpty {
                ForEach(displayedTitles, id: \.self) { title in
                    Text("Included in \(title)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Color(uiColor: .systemGray).opacity(0.55),
                            in: Capsule()
                        )
                }

                if albumTitles.count > 2, !showsAllAlbums {
                    Button {
                        showsAllAlbums = true
                    } label: {
                        Text("…")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Color(uiColor: .systemGray).opacity(0.55),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show all included albums")
                }
            }
        }
        .task(id: asset.localIdentifier) {
            let albums = PHAssetCollection.fetchAssetCollectionsContaining(
                asset,
                with: .album,
                options: nil
            )

            albumTitles = (0..<albums.count).compactMap { index in
                albums.object(at: index).localizedTitle
            }
            showsAllAlbums = false
        }
    }

    private var displayedTitles: [String] {
        showsAllAlbums ? albumTitles : Array(albumTitles.prefix(2))
    }
}

struct MediaShareButton: View {
    let asset: PHAsset

    @State private var sharedMedia: SharedMedia?
    @State private var isPreparingShare = false

    var body: some View {
        Button {
            prepareShare()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title3)
                .frame(
                    width: PendingDeletionLayout.buttonHeight,
                    height: PendingDeletionLayout.buttonHeight,
                    alignment: .center
                )
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.blue)
        .disabled(isPreparingShare)
        .accessibilityLabel("Share Media")
        .sheet(item: $sharedMedia) { media in
            ActivityShareSheet(fileURL: media.fileURL) {
                try? FileManager.default.removeItem(at: media.fileURL)
                sharedMedia = nil
            }
        }
    }

    private func prepareShare() {
        isPreparingShare = true
        PhotoService.shared.requestShareFile(asset: asset) { fileURL in
            isPreparingShare = false

            if let fileURL {
                sharedMedia = SharedMedia(fileURL: fileURL)
            }
        }
    }
}

struct MediaPhotoPreviewSheet: View {
    let asset: PHAsset

    var body: some View {
        ZStack {
            ImageView(
                asset: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .fit
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SharedMedia: Identifiable {
    let id = UUID()
    let fileURL: URL
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    let completion: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion()
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
