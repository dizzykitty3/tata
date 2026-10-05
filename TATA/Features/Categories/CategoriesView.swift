import Photos
import SwiftUI

private struct MediaTypeCategory: Identifiable {
    let title: String
    let assets: [PHAsset]

    var id: String {
        title
    }
}

struct CategoriesView: View {
    @ObservedObject var model: CategoriesViewModel

    @ObservedObject var deletionManager: DeletionManager
    @Binding var isShowingPendingDeletions: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if model.albums.isEmpty, model.assets.isEmpty {
                    ContentUnavailableView(
                        "No Categories",
                        systemImage: "square.grid.2x2",
                        description: Text(
                            "Your photo library doesn't contain media or albums."
                        )
                    )
                } else {
                    List {
                        albumSection(
                            title: "Personal Albums",
                            albums: personalAlbums
                        )

                        albumSection(
                            title: "Shared Albums",
                            albums: sharedAlbums
                        )

                        let mediaTypes = mediaTypeCategories
                        if !mediaTypes.isEmpty {
                            Section("Media Types") {
                                ForEach(mediaTypes) { category in
                                    NavigationLink {
                                        MediaGridView(
                                            assets: category.assets,
                                            title: category.title,
                                            deletionManager: deletionManager,
                                            deletionSource: .category,
                                            refreshMedia: model.reload
                                        )
                                    } label: {
                                        CategoryMediaRow(
                                            title: category.title,
                                            assets: category.assets,
                                            deletionManager: deletionManager
                                        )
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
            .navigationTitle("Categories")
        }
        .onAppear {
            model.reload()
        }
    }

    @ViewBuilder
    private func albumSection(
        title: String,
        albums: [MediaAlbum]
    ) -> some View {
        if !albums.isEmpty {
            Section(title) {
                ForEach(albums) { album in
                    NavigationLink {
                        MediaGridView(
                            assets: album.assets,
                            title: album.title,
                            deletionManager: deletionManager,
                            deletionSource: .category,
                            refreshMedia: model.reload
                        )
                    } label: {
                        CategoryMediaRow(
                            title: album.title,
                            assets: album.assets,
                            deletionManager: deletionManager
                        )
                    }
                }
            }
        }
    }

    private var personalAlbums: [MediaAlbum] {
        model.albums.filter {
            $0.collection.assetCollectionSubtype != .albumCloudShared
        }
    }

    private var sharedAlbums: [MediaAlbum] {
        model.albums.filter {
            $0.collection.assetCollectionSubtype == .albumCloudShared
        }
    }

    private var mediaTypeCategories: [MediaTypeCategory] {
        [
            MediaTypeCategory(
                title: "Videos",
                assets: model.assets.filter { $0.mediaType == .video }
            ),
            MediaTypeCategory(
                title: "Live Photos",
                assets: model.assets.filter {
                    $0.mediaSubtypes.contains(.photoLive)
                }
            ),
            MediaTypeCategory(
                title: "Static Photos",
                assets: model.assets.filter {
                    $0.mediaType == .image
                        && !$0.mediaSubtypes.contains(.photoLive)
                }
            )
        ]
        .filter { !$0.assets.isEmpty }
    }
}

private struct CategoryMediaRow: View {
    let title: String
    let assets: [PHAsset]
    @ObservedObject var deletionManager: DeletionManager

    private var mediaCount: Int {
        let pendingIdentifiers = Set(
            deletionManager.pendingAssets.map(\.localIdentifier)
        )
        return assets.filter {
            !pendingIdentifiers.contains($0.localIdentifier)
        }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryMediaCollage(assets: Array(assets.prefix(3)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))

                MediaCountText(text: "\(mediaCount) \(mediaCount == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CategoryMediaCollage: View {
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
