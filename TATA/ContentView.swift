import SwiftUI

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
    private var timelineModel: TimelineViewModel

    @StateObject
    private var albumModel: AlbumViewModel

    @State private var isShowingPendingDeletions = false
    @State private var selectedTab: AppTab = .swipe
    @State private var isRefreshingMediaLibrary = false
    @State private var refreshGeneration = 0
    @State private var showsRefreshConfirmation = false

    init() {
        let deletionManager = DeletionManager()
        _deletionManager = StateObject(wrappedValue: deletionManager)
        _swipeModel = StateObject(
            wrappedValue: SwipeViewModel(
                deletionManager: deletionManager
            )
        )
        _timelineModel = StateObject(wrappedValue: TimelineViewModel())
        _albumModel = StateObject(wrappedValue: AlbumViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Swipe", systemImage: "hand.draw", value: .swipe) {
                    mediaTabContent {
                        SwipeView(model: swipeModel)
                            .id(refreshGeneration)
                    }
                }

                Tab("Timeline", systemImage: "calendar", value: .date) {
                    mediaTabContent {
                        TimelineView(
                            model: timelineModel,
                            deletionManager: deletionManager,
                            isShowingPendingDeletions: $isShowingPendingDeletions
                        )
                        .id(refreshGeneration)
                    }
                }

                Tab("Albums", systemImage: "photo.stack", value: .albums) {
                    mediaTabContent {
                        AlbumsView(
                            model: albumModel,
                            deletionManager: deletionManager,
                            isShowingPendingDeletions: $isShowingPendingDeletions
                        )
                        .id(refreshGeneration)
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView(
                        deletionManager: deletionManager,
                        refreshMediaLibrary: refreshMediaLibrary,
                        isRefreshing: isRefreshingMediaLibrary
                    )
                }
            }

            if selectedTab == .swipe,
               (swipeModel.current != nil
                || !deletionManager.pendingAssets.isEmpty) {
                HStack(spacing: 12) {
                    if swipeModel.current != nil {
                        if let asset = swipeModel.current {
                            MediaShareButton(asset: asset)
                                .accessibilityLabel("Share Current Media")
                        }
                    }

                    if !deletionManager.pendingAssets.isEmpty {
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
                        }

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

            if showsRefreshConfirmation {
                Label("Media Library Refreshed", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .label))
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Color(uiColor: .systemGray5))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .accessibilityAddTraits(.isStaticText)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
            }
        }
        .sheet(isPresented: $isShowingPendingDeletions) {
            PendingDeletionSheet(deletionManager: deletionManager)
        }
    }

    @ViewBuilder
    private func mediaTabContent<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isRefreshingMediaLibrary {
            ProgressView("Refreshing Media Library…")
        } else {
            content()
        }
    }

    private func refreshMediaLibrary() {
        guard !isRefreshingMediaLibrary else {
            return
        }

        isRefreshingMediaLibrary = true
        showsRefreshConfirmation = false
        isShowingPendingDeletions = false
        deletionManager.clearPendingAssets()

        DispatchQueue.global(qos: .userInitiated).async {
            let assets = PhotoService.shared.fetchAssetSnapshot()
            let albums = PhotoService.shared.fetchAlbumSnapshot()

            DispatchQueue.main.async {
                swipeModel.reset(with: assets)
                timelineModel.reload(
                    assets: assets,
                    grouping: currentTimelineGrouping
                )
                albumModel.replace(with: albums)
                refreshGeneration += 1
                isRefreshingMediaLibrary = false

                withAnimation(.easeInOut(duration: 0.2)) {
                    showsRefreshConfirmation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsRefreshConfirmation = false
                    }
                }
            }
        }
    }

    private var currentTimelineGrouping: TimelineGrouping {
        TimelineGrouping(
            rawValue: UserDefaults.standard.string(
                forKey: TimelineGrouping.storageKey
            ) ?? TimelineGrouping.date.rawValue
        ) ?? .date
    }
}

#Preview {
    ContentView()
}
