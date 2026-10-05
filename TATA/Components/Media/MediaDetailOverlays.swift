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

struct MediaPendingDeletionButton: View {
    let asset: PHAsset
    let deletionManager: DeletionManager
    let source: DeletionManager.Source
    let dismiss: () -> Void

    var body: some View {
        Button {
            deletionManager.add(asset, source: source)
            dismiss()
        } label: {
            Image(systemName: "trash")
                .font(.title3)
                .frame(
                    width: PendingDeletionLayout.buttonHeight,
                    height: PendingDeletionLayout.buttonHeight,
                    alignment: .center
                )
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(.red)
        .accessibilityLabel("Move to Pending Deletions")
    }
}

struct MediaDetailActionBar: View {
    let asset: PHAsset
    let deletionManager: DeletionManager?
    let deletionSource: DeletionManager.Source?
    let dismiss: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                MediaShareButton(asset: asset)

                if let deletionManager, let deletionSource {
                    MediaPendingDeletionButton(
                        asset: asset,
                        deletionManager: deletionManager,
                        source: deletionSource,
                        dismiss: dismiss
                    )
                }
            }
        }
    }
}

struct MediaPhotoPreviewSheet: View {
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
                    MediaInfoOverlay(asset: asset)
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

struct MediaInfoOverlay: View {
    let asset: PHAsset

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                IncludedAlbumsPills(asset: asset)
                MediaMetadataPill(asset: asset)
            }
            .id(asset.localIdentifier)
            .transition(.opacity)
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: asset.localIdentifier
        )
    }
}

private struct MediaMetadataPill: View {
    let asset: PHAsset

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var fileSize: Int64?
    @State private var isLoadingSize = true

    var body: some View {
        Text(metadataText)
            .contentTransition(.opacity)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Color(uiColor: .systemGray).opacity(0.55),
                in: Capsule()
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: metadataText
            )
            .task(id: asset.localIdentifier) {
                fileSize = nil
                isLoadingSize = true
                defer { isLoadingSize = false }
                do {
                    let size = try await PhotoService.shared.mediaFileSize(asset: asset)
                    try Task.checkCancellation()
                    fileSize = size
                } catch {
                    // Show an unavailable placeholder when the resource cannot be read.
                }
            }
    }

    private var metadataText: String {
        let size = fileSize.map(Self.formatSize) ?? (isLoadingSize ? "…" : "—")
        return asset.mediaType == .video ? "\(formattedDuration) \(size)" : size
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
