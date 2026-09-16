import Foundation
import Photos
import Combine

@MainActor
final class DeletionManager: ObservableObject {
    enum Source {
        case swipe
        case date
    }

    @Published
    private(set) var pendingAssets: [PHAsset] = []

    private var sourceByAssetIdentifier: [String: Source] = [:]

    func add(_ asset: PHAsset, source: Source) {
        guard !pendingAssets.contains(where: {
            $0.localIdentifier == asset.localIdentifier
        }) else {
            return
        }

        pendingAssets.append(asset)
        sourceByAssetIdentifier[asset.localIdentifier] = source
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

    func deleteAll(
        completion: @escaping (PhotoDeletionResult) -> Void
    ) {
        guard !pendingAssets.isEmpty else {
            completion(.success)
            return
        }

        PhotoService.shared.delete(assets: pendingAssets) { result in
            Task { @MainActor in
                if case .success = result {
                    self.pendingAssets.removeAll()
                    self.sourceByAssetIdentifier.removeAll()
                }
                completion(result)
            }
        }
    }
}
