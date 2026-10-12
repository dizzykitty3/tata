import Foundation
import Photos
import Combine

@MainActor
final class DeletionManager: ObservableObject {
    static let deletedMediaCountKey = "deletedMediaCount"

    enum Source {
        case swipe
        case date
        case category
    }

    @Published
    private(set) var pendingAssets: [PHAsset] = []

    @Published
    private(set) var deletedMediaCount: Int

    private var sourceByAssetIdentifier: [String: Source] = [:]

    init() {
        deletedMediaCount = UserDefaults.standard.integer(
            forKey: Self.deletedMediaCountKey
        )
    }

    func add(_ asset: PHAsset, source: Source) {
        add([asset], source: source)
    }

    func add(_ assets: [PHAsset], source: Source) {
        var identifiers = Set(pendingAssets.map(\.localIdentifier))
        let additions = assets.filter { identifiers.insert($0.localIdentifier).inserted }
        guard !additions.isEmpty else { return }
        for asset in additions {
            sourceByAssetIdentifier[asset.localIdentifier] = source
        }
        // Publish once for the entire selection instead of rebuilding UI per item.
        pendingAssets.append(contentsOf: additions)
    }

    @discardableResult
    func undoLast(from source: Source) -> PHAsset? {
        guard let index = pendingAssets.lastIndex(where: {
            sourceByAssetIdentifier[$0.localIdentifier] == source
        }) else {
            return nil
        }

        let asset = pendingAssets.remove(at: index)
        sourceByAssetIdentifier[asset.localIdentifier] = nil
        return asset
    }

    func hasPendingAssets(from source: Source) -> Bool {
        pendingAssets.contains {
            sourceByAssetIdentifier[$0.localIdentifier] == source
        }
    }

    func clearPendingAssets() {
        pendingAssets.removeAll()
        sourceByAssetIdentifier.removeAll()
    }

    func deleteAll(
        completion: @escaping (PhotoDeletionResult) -> Void
    ) {
        guard !pendingAssets.isEmpty else {
            completion(.success)
            return
        }

        let deletedCount = pendingAssets.count
        PhotoService.shared.delete(assets: pendingAssets) { result in
            Task { @MainActor in
                if case .success = result {
                    self.deletedMediaCount += deletedCount
                    UserDefaults.standard.set(
                        self.deletedMediaCount,
                        forKey: Self.deletedMediaCountKey
                    )
                    self.clearPendingAssets()
                }
                completion(result)
            }
        }
    }
}
