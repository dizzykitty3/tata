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
    @Published private(set) var isLoading = true

    private var loadedRevision: Int?
    private var loadingRevision: Int?
    private var generation = UUID()

    func loadIfNeeded() {
        let revision = PhotoLibraryRevision.shared.value
        guard loadedRevision != revision, loadingRevision != revision else { return }
        reload()
    }

    func reload() {
        isLoading = true
        let revision = PhotoLibraryRevision.shared.value
        loadingRevision = revision
        let token = UUID()
        generation = token
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let albums = PhotoService.shared.fetchAlbumSnapshot()
            let assets = PhotoService.shared.fetchAssetSnapshot()
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.albums = albums
                self.assets = assets
                self.loadedRevision = revision
                self.loadingRevision = nil
                self.isLoading = false
            }
        }
    }

    func replace(with albums: [MediaAlbum], assets: [PHAsset]) {
        generation = UUID()
        loadingRevision = nil
        loadedRevision = PhotoLibraryRevision.shared.value
        self.albums = albums
        self.assets = assets
        isLoading = false
    }
}
