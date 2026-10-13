import SwiftUI
import Photos
import Combine

@MainActor
final class FavoriteDeletionConfirmation: ObservableObject {
    static let settingKey = "confirmBeforeDeletingFavorites"
    @Published var isPresented = false
    private(set) var favoriteCount = 0
    private var pendingAction: (() -> Void)?

    func request(assets: [PHAsset], onRequiresConfirmation: () -> Void = {}, action: @escaping () -> Void) {
        let enabled = UserDefaults.standard.object(forKey: Self.settingKey) as? Bool ?? true
        guard enabled else { action(); return }
        let latest = PHAsset.fetchAssets(withLocalIdentifiers: assets.map(\.localIdentifier), options: nil)
        var count = 0
        latest.enumerateObjects { asset, _, _ in
            if asset.isFavorite { count += 1 }
        }
        guard count > 0 else { action(); return }
        onRequiresConfirmation()
        favoriteCount = count
        pendingAction = action
        isPresented = true
    }

    func confirm() {
        let action = pendingAction
        pendingAction = nil
        action?()
    }

    func cancel() { pendingAction = nil }
}

private struct FavoriteDeletionAlert: ViewModifier {
    @ObservedObject var confirmation: FavoriteDeletionConfirmation

    func body(content: Content) -> some View {
        content.alert(confirmation.favoriteCount == 1 ? "Move Favorite to Pending Deletions?" : "Move Favorites to Pending Deletions?", isPresented: $confirmation.isPresented) {
            Button("Cancel", role: .cancel) { confirmation.cancel() }
            Button("Move to Pending Deletions", role: .destructive) { confirmation.confirm() }
        } message: {
            Text(confirmation.favoriteCount == 1
                 ? "This selection contains one item marked as a favorite in Photos."
                 : "This selection contains \(confirmation.favoriteCount) items marked as favorites in Photos.")
        }
    }
}

extension View {
    func favoriteDeletionConfirmation(_ confirmation: FavoriteDeletionConfirmation) -> some View {
        modifier(FavoriteDeletionAlert(confirmation: confirmation))
    }
}
