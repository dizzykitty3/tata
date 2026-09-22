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
final class CategoriesViewModel: ObservableObject {
    @Published private(set) var albums: [MediaAlbum] = []
    @Published private(set) var assets: [PHAsset] = []

    func reload() {
        albums = PhotoService.shared.fetchAlbumSnapshot()
        assets = PhotoService.shared.fetchAssetSnapshot()
    }

    func replace(with albums: [MediaAlbum], assets: [PHAsset]) {
        self.albums = albums
        self.assets = assets
    }
}
