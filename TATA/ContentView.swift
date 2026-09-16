import SwiftUI
import UIKit

struct ContentView: View {
    private enum AppTab: Hashable {
        case swipe
        case date
        case albums
        case settings
    }

    @StateObject
    private var deletionManager: DeletionManager

    @StateObject
    private var swipeModel: SwipeViewModel

    @StateObject
    private var dateModel: DateViewModel

    @State private var isShowingPendingDeletions = false
    @State private var selectedTab: AppTab = .swipe
    @State private var sharedMedia: SharedMedia?
    @State private var isPreparingShare = false

    init() {
        let deletionManager = DeletionManager()
        _deletionManager = StateObject(wrappedValue: deletionManager)
        _swipeModel = StateObject(
            wrappedValue: SwipeViewModel(
                deletionManager: deletionManager
            )
        )
        _dateModel = StateObject(wrappedValue: DateViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Swipe", systemImage: "hand.draw", value: .swipe) {
                    SwipeView(
                        model: swipeModel
                    )
                }

                Tab("Date", systemImage: "calendar", value: .date) {
                    DateView(
                        model: dateModel,
                        deletionManager: deletionManager,
                        isShowingPendingDeletions: $isShowingPendingDeletions
                    )
                }

                Tab("Albums", systemImage: "photo.stack", value: .albums) {
                    EmptyView()
                }

                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView()
                }
            }

            if selectedTab == .swipe,
               (swipeModel.current != nil
                || !deletionManager.pendingAssets.isEmpty) {
                HStack(spacing: 12) {
                    if swipeModel.current != nil {
                        Button {
                            prepareShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .frame(
                                    width: PendingDeletionLayout.buttonHeight,
                                    height: PendingDeletionLayout.buttonHeight,
                                    alignment: .center
                                )
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .tint(.blue)
                        .disabled(isPreparingShare)
                        .accessibilityLabel("Share Current Media")
                    }

                    if deletionManager.hasPendingAssets(from: .swipe) {
                        Button {
                            swipeModel.undoLastDeletion()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.title3)
                                .frame(
                                    width: PendingDeletionLayout.buttonHeight,
                                    height: PendingDeletionLayout.buttonHeight,
                                    alignment: .center
                                )
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Undo Last Deletion")

                        Button {
                            isShowingPendingDeletions = true
                        } label: {
                            Text(
                                "Pending Deletions (\(deletionManager.pendingAssets.count))"
                            )
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(
                                height: PendingDeletionLayout.buttonHeight
                            )
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .accessibilityLabel("Pending Deletions")
                    }
                }
                .frame(height: PendingDeletionLayout.buttonHeight)
                .padding(.bottom, PendingDeletionLayout.buttonBottomInset)
            }
        }
        .sheet(isPresented: $isShowingPendingDeletions) {
            PendingDeletionSheet(deletionManager: deletionManager)
        }
        .sheet(item: $sharedMedia) { media in
            ActivityShareSheet(fileURL: media.fileURL) {
                try? FileManager.default.removeItem(at: media.fileURL)
                sharedMedia = nil
            }
        }
    }

    private func prepareShare() {
        guard let asset = swipeModel.current else {
            return
        }

        isPreparingShare = true
        PhotoService.shared.requestShareFile(asset: asset) { fileURL in
            isPreparingShare = false

            if let fileURL {
                sharedMedia = SharedMedia(fileURL: fileURL)
            }
        }
    }
}

private struct SharedMedia: Identifiable {
    let id = UUID()
    let fileURL: URL
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    let completion: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion()
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

#Preview {
    ContentView()
}
