import Photos
import SwiftUI

private enum AlbumCategory: String, CaseIterable, Identifiable {
    case personal = "Personal"
    case shared = "Shared"

    var id: String {
        rawValue
    }
}

struct AlbumsView: View {
    @StateObject private var model = AlbumViewModel()

    @ObservedObject var deletionManager: DeletionManager
    @Binding var isShowingPendingDeletions: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if model.albums.isEmpty {
                    ContentUnavailableView(
                        "No Albums",
                        systemImage: "photo.stack",
                        description: Text(
                            "Your photo library doesn't contain any albums."
                        )
                    )
                } else {
                    List {
                        ForEach(AlbumCategory.allCases) { category in
                            let albums = albums(for: category)

                            if !albums.isEmpty {
                                Section(category.rawValue) {
                                    ForEach(albums) { album in
                                        NavigationLink {
                                            MediaGridView(
                                                assets: album.assets,
                                                title: album.title,
                                                deletionManager: deletionManager,
                                                refreshMedia: model.reload
                                            )
                                        } label: {
                                            AlbumTimelineRow(album: album)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                if !deletionManager.pendingAssets.isEmpty {
                    Button {
                        isShowingPendingDeletions = true
                    } label: {
                        Text("Pending Deletions (\(deletionManager.pendingAssets.count))")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(height: PendingDeletionLayout.buttonHeight)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Pending Deletions")
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Albums")
        }
        .onAppear {
            model.reload()
        }
    }

    private func albums(for category: AlbumCategory) -> [MediaAlbum] {
        model.albums.filter {
            switch category {
            case .personal:
                $0.collection.assetCollectionSubtype != .albumCloudShared
            case .shared:
                $0.collection.assetCollectionSubtype == .albumCloudShared
            }
        }
    }
}

private struct AlbumTimelineRow: View {
    let album: MediaAlbum

    var body: some View {
        HStack(spacing: 12) {
            AlbumMediaCollage(assets: Array(album.assets.prefix(3)))

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.body.weight(.semibold))

                Text("\(album.assets.count) \(album.assets.count == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AlbumMediaCollage: View {
    let assets: [PHAsset]

    var body: some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)

            HStack(spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    MediaView(
                        asset: asset,
                        targetSize: CGSize(width: 240, height: 240),
                        contentMode: .fill
                    )
                    .frame(width: 24, height: 64)
                    .clipped()
                }
            }
        }
        .frame(width: 76, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
