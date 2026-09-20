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
        albums = PhotoService.shared.fetchAlbumSnapshot()
    }

    func replace(with albums: [MediaAlbum]) {
        self.albums = albums
    }
}
