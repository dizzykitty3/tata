import Combine
import Photos
import SwiftUI

@MainActor
private final class MediaFavorites: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let shared = MediaFavorites()
    @Published private(set) var values: [String: Bool] = [:]
    @Published private(set) var updating: Set<String> = []
    @Published private(set) var revision = 0

    private override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in self?.revision += 1 }
    }

    func refresh(_ asset: PHAsset) {
        let current = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil).firstObject
        values[asset.localIdentifier] = current?.isFavorite ?? asset.isFavorite
    }

    func toggle(_ asset: PHAsset) async throws {
        let identifier = asset.localIdentifier
        guard !updating.contains(identifier) else { return }
        updating.insert(identifier)
        defer { updating.remove(identifier) }
        guard let current = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let desired = !current.isFavorite
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest(for: current).isFavorite = desired
        }
        values[identifier] = desired
    }
}

struct MediaFavoriteButton: View {
    let asset: PHAsset
    @ObservedObject private var favorites = MediaFavorites.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var errorMessage: String?

    private var isFavorite: Bool {
        favorites.values[asset.localIdentifier] ?? asset.isFavorite
    }

    var body: some View {
        Button {
            Task { @MainActor in
                do {
                    try await favorites.toggle(asset)
                } catch {
                    let photosError = error as NSError
                    if photosError.domain == PHPhotosErrorDomain,
                       photosError.code == PHPhotosError.userCancelled.rawValue { return }
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.title3)
                .frame(width: ActionButtonLayout.height, height: ActionButtonLayout.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .disabled(favorites.updating.contains(asset.localIdentifier))
        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
        .accessibilityValue(isFavorite ? "Favorited" : "Not Favorited")
        .task(id: asset.localIdentifier) { favorites.refresh(asset) }
        .onChange(of: favorites.revision) { _, _ in favorites.refresh(asset) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { favorites.refresh(asset) }
        }
        .alert("Unable to Update Favorite", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }
}
