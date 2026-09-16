import Foundation
import Photos
import Combine

@MainActor
final class SwipeViewModel: ObservableObject {
    private let service = PhotoService.shared
    private let deletionManager: DeletionManager
    private let preloadCount = 5

    private var assets: [PHAsset]
    private var index = 0

    @Published
    var current: PHAsset?

    @Published
    var next: PHAsset?

    @Published
    var previous: PHAsset?

    init(deletionManager: DeletionManager) {
        self.deletionManager = deletionManager

        let fetchResult = service.fetchAssets()
        let pendingIdentifiers = Set(
            deletionManager.pendingAssets.map(\.localIdentifier)
        )

        assets = (0..<fetchResult.count).map {
            fetchResult.object(at: $0)
        }.filter {
            !pendingIdentifiers.contains($0.localIdentifier)
        }

        load(index: 0)
    }

    func load(index: Int) {
        guard index >= 0 else {
            return
        }

        if index >= assets.count {
            self.index = index
            current = nil
            next = nil
            previous = assets.last
            return
        }

        self.index = index
        current = assets[index]

        if index > 0 {
            previous = assets[index - 1]
        } else {
            previous = nil
        }

        if index + 1 < assets.count {
            next = assets[index + 1]
        } else {
            next = nil
        }

        let assetsToPreload = (1...preloadCount)
            .flatMap { distance in
                [index + distance, index - distance]
            }
            .filter { $0 >= 0 && $0 < assets.count }
            .prefix(preloadCount)
            .map { assets[$0] }

        if !assetsToPreload.isEmpty {
            service.preload(assets: Array(assetsToPreload))
        }
    }

    func moveNext() {
        guard index < assets.count else {
            return
        }

        load(index: index + 1)
    }

    func movePrevious() {
        guard index > 0 else {
            return
        }

        load(index: index - 1)
    }

    func undoLastDeletion() {
        guard deletionManager.undoLast(from: .swipe) != nil else {
            return
        }

        let currentIdentifier = current?.localIdentifier
        let fetchResult = service.fetchAssets()
        let pendingIdentifiers = Set(
            deletionManager.pendingAssets.map(\.localIdentifier)
        )

        assets = (0..<fetchResult.count).map {
            fetchResult.object(at: $0)
        }.filter {
            !pendingIdentifiers.contains($0.localIdentifier)
        }

        if let currentIdentifier,
           let currentIndex = assets.firstIndex(
                where: { $0.localIdentifier == currentIdentifier }
           ) {
            load(index: currentIndex)
        } else {
            load(index: min(index, max(assets.count - 1, 0)))
        }
    }

    func markCurrentForDeletion() {
        guard let current else {
            return
        }

        deletionManager.add(current, source: .swipe)

        if let deletedIndex = assets.firstIndex(
            where: { $0.localIdentifier == current.localIdentifier }
        ) {
            assets.remove(at: deletedIndex)
        }

        load(index: index)
    }
}
