import Photos
import SwiftUI

struct MediaDeletionLabel: View {
    let assets: [PHAsset]
    let actionName: String

    @State private var totalSize: Int64?
    @State private var completedIdentifiers: [String]?

    private var identifiers: [String] {
        assets.map(\.localIdentifier).sorted()
    }

    private var sizeText: String {
        if assets.isEmpty { return MediaFileFormatting.size(0) }
        guard let totalSize else { return completedIdentifiers == nil ? "…" : "—" }
        return MediaFileFormatting.size(totalSize)
    }

    var body: some View {
        Label {
            HStack(spacing: 0) {
                CrossfadeText(text: assets.count.formatted())
                Text(" (")
                CrossfadeText(text: sizeText)
                Text(")")
            }
            .monospacedDigit()
        } icon: {
            Image(systemName: "trash")
        }
            .accessibilityLabel("\(actionName), \(assets.count) items, \(completedIdentifiers == identifiers ? sizeText : "Calculating size")")
            .task(id: identifiers) {
                let requestedIdentifiers = identifiers
                // Keep the previous result until its replacement is ready, avoiding
                // a placeholder flash for every selection change.
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
                    totalSize = nil
                    completedIdentifiers = requestedIdentifiers
                }
            }
    }
}
