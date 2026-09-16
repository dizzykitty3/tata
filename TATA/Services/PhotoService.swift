import Foundation
import Photos
import UIKit
import AVFoundation

enum PhotoDeletionResult {
    case success
    case cancelled
    case failure
}

final class PhotoService {
    static let shared = PhotoService()

    private let manager = PHCachingImageManager()
    private var cachedAssets: [PHAsset] = []
    private let imageCache = NSCache<NSString, UIImage>()
    private let videoCache = NSCache<NSString, AVAsset>()

    private init() {}

    func fetchAssets() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]

        return PHAsset.fetchAssets(with: options)
    }

    func requestImage(
        asset: PHAsset,
        size: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {
        let cacheKey = "\(asset.localIdentifier)-\(size.width)x\(size.height)" as NSString

        if let image = imageCache.object(forKey: cacheKey) {
            completion(image)
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image {
                self.imageCache.setObject(image, forKey: cacheKey)
            }
            completion(image)
        }
    }

    func requestLivePhoto(
        asset: PHAsset,
        completion: @escaping (PHLivePhoto?) -> Void
    ) {
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        manager.requestLivePhoto(
            for: asset,
            targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit,
            options: options
        ) { livePhoto, _ in
            completion(livePhoto)
        }
    }

    func requestVideo(
        asset: PHAsset,
        completion: @escaping (AVAsset?) -> Void
    ) {
        let cacheKey = asset.localIdentifier as NSString

        if let avAsset = videoCache.object(forKey: cacheKey) {
            completion(avAsset)
            return
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .automatic
        options.isNetworkAccessAllowed = true

        manager.requestAVAsset(
            forVideo: asset,
            options: options
        ) { avAsset, _, _ in
            if let avAsset {
                self.videoCache.setObject(avAsset, forKey: cacheKey)
            }
            completion(avAsset)
        }
    }

    func requestShareFile(
        asset: PHAsset,
        completion: @escaping (URL?) -> Void
    ) {
        guard let resource = shareResource(for: asset) else {
            completion(nil)
            return
        }

        let fileExtension = URL(
            fileURLWithPath: resource.originalFilename
        ).pathExtension
        let fallbackExtension = asset.mediaType == .video ? "mov" : "jpg"
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(
                fileExtension.isEmpty ? fallbackExtension : fileExtension
            )
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        PHAssetResourceManager.default().writeData(
            for: resource,
            toFile: destination,
            options: options
        ) { error in
            completion(error == nil ? destination : nil)
        }
    }

    func delete(
        assets: [PHAsset],
        completion: @escaping (PhotoDeletionResult) -> Void
    ) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        } completionHandler: { success, error in
            if success {
                completion(.success)
            } else if Self.isUserCancelled(error) {
                completion(.cancelled)
            } else {
                completion(.failure)
            }
        }
    }

    private static func isUserCancelled(_ error: Error?) -> Bool {
        guard let error else {
            return false
        }

        if let photosError = error as? PHPhotosError,
           photosError.code == .userCancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == "PHPhotosErrorDomain"
            && nsError.code == PHPhotosError.userCancelled.rawValue
    }

    private func shareResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)

        if asset.mediaType == .video {
            return resources.first { $0.type == .video }
        }

        return resources.first { $0.type == .fullSizePhoto }
            ?? resources.first { $0.type == .photo }
    }

    func preload(assets: [PHAsset]) {
        let targetSize = CGSize(width: 1200, height: 1200)

        manager.stopCachingImages(
            for: cachedAssets,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: nil
        )
        manager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: nil
        )

        cachedAssets = assets

        for asset in assets {
            requestImage(asset: asset, size: targetSize) { _ in }

            if asset.mediaType == .video {
                requestVideo(asset: asset) { _ in }
            }
        }
    }
}
