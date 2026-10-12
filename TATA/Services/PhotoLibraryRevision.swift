import Photos

/// Tracks changes without fetching or rebuilding the library on every tab visit.
@MainActor
final class PhotoLibraryRevision: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoLibraryRevision()
    private(set) var value = 0

    private override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in self?.value += 1 }
    }
}
