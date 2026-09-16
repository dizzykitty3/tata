import Combine
import Foundation
import Photos

struct MediaAlbum: Identifiable {
    let collection: PHAssetCollection
    let assets: [PHAsset]

    var id: String {
        collection.localIdentifier
    }

    var title: String {
        collection.localizedTitle ?? "Untitled Album"
    }

    var photoCount: Int {
        assets.filter { $0.mediaType == .image }.count
    }

    var videoCount: Int {
        assets.filter { $0.mediaType == .video }.count
    }
}

@MainActor
final class AlbumViewModel: ObservableObject {
    @Published private(set) var albums: [MediaAlbum] = []

    func reload() {
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        albums = (0..<collections.count).compactMap { index in
            let collection = collections.object(at: index)
            let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
            let assets = (0..<fetchResult.count).map(fetchResult.object(at:))

            guard !assets.isEmpty else {
                return nil
            }

            return MediaAlbum(collection: collection, assets: assets)
        }
        .sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
