import Foundation
import Photos
import Combine

@MainActor
final class SwipeViewModel: ObservableObject {
    private let service = PhotoService.shared
    private let deletionManager: DeletionManager
    private var subscriptions = Set<AnyCancellable>()
    private let preloadCount = 5
    static let rememberKeptMediaKey = "rememberKeptMedia"
    private static let keptIdentifiersKey = "keptMediaIdentifiers"
    private var keptIdentifiers = Set(UserDefaults.standard.stringArray(forKey: keptIdentifiersKey) ?? [])
    private var remembersKeptMedia: Bool {
        UserDefaults.standard.bool(forKey: Self.rememberKeptMediaKey)
    }

    private func saveKeptIdentifiers() {
        UserDefaults.standard.set(Array(keptIdentifiers), forKey: Self.keptIdentifiersKey)
    }

    func clearKeptMediaAndReturnToLatest() {
        keptIdentifiers.removeAll()
        saveKeptIdentifiers()
        reset(with: service.fetchAssetSnapshot())
        returnToLatest()
    }

    private var assets: [PHAsset]
    private var index = 0
    private struct Position: Codable {
        let identifier: String
        let date: Date?
        let index: Int
        let atEnd: Bool
    }
    private static let positionKey = "swipeBrowsingPosition"
    private var savedPosition: Position? {
        guard let data = UserDefaults.standard.data(forKey: Self.positionKey) else { return nil }
        return try? JSONDecoder().decode(Position.self, from: data)
    }

    var canReturnToLatest: Bool { !assets.isEmpty && index > 0 }

    func returnToLatest() { load(index: 0) }

    private func savePosition() {
        guard let anchor = current ?? assets.last else { return }
        let position = Position(identifier: anchor.localIdentifier, date: anchor.creationDate,
                                index: index, atEnd: current == nil)
        if let data = try? JSONEncoder().encode(position) {
            UserDefaults.standard.set(data, forKey: Self.positionKey)
        }
    }

    @Published
    var current: PHAsset?

    @Published
    var next: PHAsset?

    @Published
    var previous: PHAsset?

    init(deletionManager: DeletionManager) {
        self.deletionManager = deletionManager

        assets = []
        reset(with: service.fetchAssetSnapshot())
        deletionManager.$pendingAssets
            .sink { [weak self] pending in
                self?.removeFromBrowsing(Set(pending.map(\.localIdentifier)))
            }
            .store(in: &subscriptions)
        deletionManager.$confirmedDeletedIdentifiers
            .sink { [weak self] identifiers in
                self?.removeFromBrowsing(identifiers)
            }
            .store(in: &subscriptions)
    }

    private func removeFromBrowsing(_ identifiers: Set<String>) {
        guard assets.contains(where: { identifiers.contains($0.localIdentifier) }) else { return }
        // Count surviving items before the cursor, preserving the current asset
        // or advancing to the next survivor when the current asset is removed.
        let restoredIndex = assets.prefix(index).filter {
            !identifiers.contains($0.localIdentifier)
        }.count
        assets.removeAll { identifiers.contains($0.localIdentifier) }
        load(index: restoredIndex)
    }

    func reset(with assets: [PHAsset]) {
        let pendingIdentifiers = Set(
            deletionManager.pendingAssets.map(\.localIdentifier)
        )
        self.assets = assets.filter {
            !pendingIdentifiers.contains($0.localIdentifier)
                && !deletionManager.confirmedDeletedIdentifiers.contains($0.localIdentifier)
                && (!remembersKeptMedia || !keptIdentifiers.contains($0.localIdentifier))
        }
        guard !self.assets.isEmpty, let position = savedPosition else {
            load(index: 0)
            return
        }
        if position.atEnd {
            load(index: self.assets.count)
        } else if let restored = self.assets.firstIndex(where: { $0.localIdentifier == position.identifier }) {
            load(index: restored)
        } else if let date = position.date,
                  let nearby = self.assets.firstIndex(where: { ($0.creationDate ?? .distantFuture) <= date }) {
            load(index: nearby)
        } else {
            load(index: min(position.index, self.assets.count - 1))
        }
    }

    func load(index: Int) {
        guard index >= 0 else {
            return
        }

        defer { savePosition() }

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

        if remembersKeptMedia, let current,
           keptIdentifiers.insert(current.localIdentifier).inserted {
            saveKeptIdentifiers()
        }
        load(index: index + 1)
    }

    func movePrevious() {
        guard index > 0 else {
            return
        }

        let previousIdentifier = assets[index - 1].localIdentifier
        if keptIdentifiers.remove(previousIdentifier) != nil {
            saveKeptIdentifiers()
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
                && !deletionManager.confirmedDeletedIdentifiers.contains($0.localIdentifier)
                && (!remembersKeptMedia || !keptIdentifiers.contains($0.localIdentifier))
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

        if keptIdentifiers.remove(current.localIdentifier) != nil {
            saveKeptIdentifiers()
        }
        deletionManager.add(current, source: .swipe)
    }
}
