import SwiftUI
import Photos

enum PendingDeletionLayout {
    static let buttonBottomInset: CGFloat = 72
    static let buttonHeight: CGFloat = 36
    static let gridSpacing: CGFloat = 2
    static let gridTargetSize = CGSize(width: 600, height: 600)
}

struct PendingDeletionSheet: View {
    @ObservedObject
    var deletionManager: DeletionManager

    @Environment(\.dismiss)
    private var dismiss

    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var selectedPhoto: PendingDeletionPhoto?

    private let columns = Array(
        repeating: GridItem(
            .flexible(),
            spacing: PendingDeletionLayout.gridSpacing
        ),
        count: 3
    )

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVGrid(
                        columns: columns,
                        spacing: PendingDeletionLayout.gridSpacing
                    ) {
                        ForEach(
                            deletionManager.pendingAssets,
                            id: \.localIdentifier
                        ) { asset in
                            GeometryReader { proxy in
                                gridMedia(for: asset)
                                    .frame(
                                        width: proxy.size.width,
                                        height: proxy.size.height
                                    )
                                    .clipped()
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Button {
                    deletePendingAssets()
                } label: {
                    Text("Delete")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(.red)
                .foregroundStyle(.white)
                .disabled(isDeleting)
                .padding(.bottom, 16)
            }
            .navigationTitle("Pending Deletions")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "Unable to Delete",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                MediaPhotoPreviewSheet(asset: photo.asset)
            }
        }
    }

    @ViewBuilder
    private func gridMedia(for asset: PHAsset) -> some View {
        if asset.mediaType == .image,
           !asset.mediaSubtypes.contains(.photoLive) {
            Button {
                selectedPhoto = PendingDeletionPhoto(asset: asset)
            } label: {
                MediaView(
                    asset: asset,
                    targetSize: PendingDeletionLayout.gridTargetSize,
                    contentMode: .fill
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            MediaView(
                asset: asset,
                showsPlaybackButton: true,
                targetSize: PendingDeletionLayout.gridTargetSize,
                contentMode: .fill
            )
        }
    }

    private func deletePendingAssets() {
        isDeleting = true

        deletionManager.deleteAll { result in
            isDeleting = false

            switch result {
            case .success:
                dismiss()
            case .cancelled:
                break
            case .failure:
                errorMessage = "The selected media could not be deleted."
            }
        }
    }
}

private struct PendingDeletionPhoto: Identifiable {
    let asset: PHAsset

    var id: String {
        asset.localIdentifier
    }
}
