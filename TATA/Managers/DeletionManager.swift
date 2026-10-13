import Foundation
import Photos
import Combine

@MainActor
final class DeletionManager: ObservableObject {
    static let deletedMediaCountKey = "deletedMediaCount"
    private static let pendingAssetsKey = "pendingDeletionAssets"

    enum Source: String, Codable {
        case swipe
        case date
        case category
    }

    @Published
    private(set) var pendingAssets: [PHAsset] = []

    @Published
    private(set) var deletedMediaCount: Int

    private var sourceByAssetIdentifier: [String: Source] = [:]

    private struct PendingEntry: Codable {
        let identifier: String
        let source: Source
    }

    init() {
        deletedMediaCount = UserDefaults.standard.integer(
            forKey: Self.deletedMediaCountKey
        )
        restorePendingAssets()
    }

    private func restorePendingAssets() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited,
              let data = UserDefaults.standard.data(forKey: Self.pendingAssetsKey),
              let entries = try? JSONDecoder().decode([PendingEntry].self, from: data),
              !entries.isEmpty else { return }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: entries.map(\.identifier), options: nil)
        var available: [String: PHAsset] = [:]
        result.enumerateObjects { asset, _, _ in
            available[asset.localIdentifier] = asset
        }
        // Photos fetch results need not follow the saved order.
        for entry in entries {
            guard let asset = available.removeValue(forKey: entry.identifier) else { continue }
            sourceByAssetIdentifier[entry.identifier] = entry.source
            pendingAssets.append(asset)
        }
        savePendingAssets()
    }

    private func savePendingAssets() {
        let entries = pendingAssets.compactMap { asset -> PendingEntry? in
            guard let source = sourceByAssetIdentifier[asset.localIdentifier] else { return nil }
            return PendingEntry(identifier: asset.localIdentifier, source: source)
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.pendingAssetsKey)
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
        savePendingAssets()
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
        savePendingAssets()
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
        savePendingAssets()
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
