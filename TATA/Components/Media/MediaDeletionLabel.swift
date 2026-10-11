import Photos
import SwiftUI

struct MediaDeletionLabel: View {
    let assets: [PHAsset]
    let actionName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var totalSize: Int64?
    @State private var completedIdentifiers: [String]?

    private var identifiers: [String] {
        assets.map(\.localIdentifier).sorted()
    }

    private var sizeText: String {
        if assets.isEmpty { return MediaFileFormatting.size(0) }
        guard completedIdentifiers == identifiers else { return "…" }
        guard let totalSize else { return "—" }
        return MediaFileFormatting.size(totalSize)
    }

    var body: some View {
        Label("\(assets.count) (\(sizeText))", systemImage: "trash")
            .contentTransition(.opacity)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: "\(assets.count) \(sizeText)"
            )
            .accessibilityLabel("\(actionName), \(assets.count) items, \(sizeText)")
            .task(id: identifiers) {
                let requestedIdentifiers = identifiers
                totalSize = nil
                completedIdentifiers = nil
                do {
                    var total: Int64 = 0
                    for asset in assets {
                        total += try await PhotoService.shared.mediaFileSize(asset: asset)
                    }
                    try Task.checkCancellation()
                    totalSize = total
                    completedIdentifiers = requestedIdentifiers
                } catch {
                    guard !Task.isCancelled else { return }
                    completedIdentifiers = requestedIdentifiers
                }
            }
    }
}
