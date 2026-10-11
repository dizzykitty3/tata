import Foundation
import Photos
import UniformTypeIdentifiers

// Shared by the metadata overlay and deletion totals.
enum MediaFileFormatting {
    nonisolated static func size(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
            .filter { !$0.isWhitespace }
    }

    nonisolated static func format(for asset: PHAsset) -> String {
        if asset.mediaSubtypes.contains(.photoLive) { return "Live Photo" }
        let resources = PHAssetResource.assetResources(for: asset)
        let resource: PHAssetResource?
        if asset.mediaType == .video {
            resource = resources.first { $0.type == .fullSizeVideo }
                ?? resources.first { $0.type == .video }
        } else {
            resource = resources.first { $0.type == .fullSizePhoto }
                ?? resources.first { $0.type == .photo }
        }
        guard let resource else { return asset.mediaType == .video ? "Video" : "Image" }
        let fileExtension = URL(fileURLWithPath: resource.originalFilename).pathExtension
        let format = fileExtension.isEmpty
            ? UTType(resource.uniformTypeIdentifier)?.preferredFilenameExtension ?? ""
            : fileExtension
        switch format.lowercased() {
        case "jpeg", "jpg": return "JPG"
        case "tiff", "tif": return "TIFF"
        case "": return asset.mediaType == .video ? "Video" : "Image"
        default: return format.uppercased()
        }
    }
}
