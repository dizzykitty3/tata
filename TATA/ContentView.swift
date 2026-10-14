import SwiftUI
import Photos

struct ContentView: View {
    private enum AppTab: Hashable {
        case swipe
        case date
        case categories
        case settings
    }

    @StateObject
    private var deletionManager: DeletionManager

    @StateObject
    private var swipeModel: SwipeViewModel

    @StateObject
    private var timelineModel: TimelineViewModel

    @StateObject
    private var categoriesModel: CategoriesViewModel

    @AppStorage(MediaAction.storageKey) private var actionOrder = MediaAction.defaultOrder
    @AppStorage(MediaAction.hiddenStorageKey) private var hiddenActions = ""

    @StateObject private var playbackControl = MediaPlaybackControl()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShowingPendingDeletions = false
    @State private var selectedTab: AppTab = .swipe
    @State private var isRefreshingMediaLibrary = false
    @State private var shouldSuggestLatestAfterRefresh = false
    @State private var refreshGeneration = 0
    @State private var showsRefreshSuggestion = false
    @State private var backgroundedAt: Date?

    @AppStorage(UserGuideSheet.hasCompletedStorageKey)
    private var hasCompletedUserGuide = false

    @State private var isShowingUserGuide = false

    @Environment(\.scenePhase)
    private var scenePhase

    init() {
        let deletionManager = DeletionManager()
        _deletionManager = StateObject(wrappedValue: deletionManager)
        _swipeModel = StateObject(
            wrappedValue: SwipeViewModel(
                deletionManager: deletionManager
            )
        )
        _timelineModel = StateObject(wrappedValue: TimelineViewModel())
        _categoriesModel = StateObject(wrappedValue: CategoriesViewModel())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Swipe", systemImage: "hand.draw", value: .swipe) {
                    mediaTabContent {
                        SwipeView(model: swipeModel, playbackControl: playbackControl)
                            .id(refreshGeneration)
                    }
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 20) {
                            refreshSuggestion
                            swipeActions
                        }
                        .padding(.bottom, 16)
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

                Tab("Categories", systemImage: "square.grid.2x2", value: .categories) {
                    mediaTabContent {
                        CategoriesView(
                            model: categoriesModel,
                            deletionManager: deletionManager,
                            isShowingPendingDeletions: $isShowingPendingDeletions
                        )
                        .id(refreshGeneration)
                    }
                }

                Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView(
                        deletionManager: deletionManager,
                        presentUserGuide: {
                            isShowingUserGuide = true
                        },
                        clearKeptMediaAndReturnToLatest: swipeModel.clearKeptMediaAndReturnToLatest
                    )
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .defaultAdaptableTabBarPlacement(.sidebar)


        }
        .animation(.easeInOut(duration: 0.2), value: showsRefreshSuggestion)
        .task(id: showsRefreshSuggestion) {
            guard showsRefreshSuggestion else { return }
            do {
                try await Task.sleep(for: .seconds(5))
                try Task.checkCancellation()
                dismissRefreshSuggestion()
            } catch {}
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onAppear {
            if !hasCompletedUserGuide {
                isShowingUserGuide = true
            }
        }
        .sheet(isPresented: $isShowingPendingDeletions) {
            PendingDeletionSheet(deletionManager: deletionManager)
        }
        .sheet(isPresented: $isShowingUserGuide) {
            UserGuideSheet {
                hasCompletedUserGuide = true
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var refreshSuggestion: some View {
        if showsRefreshSuggestion {
            HStack(spacing: 10) {
                Label(
                    "Continue from the latest media",
                    systemImage: "photo.badge.plus"
                )
                .font(.subheadline.weight(.semibold))

                Button("Back to Latest") {
                    dismissRefreshSuggestion()
                    selectedTab = .swipe
                    swipeModel.returnToLatest()
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .accessibilityHint("Returns to the newest media in Swipe")
            }
            .foregroundStyle(Color(uiColor: .label))
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 40)
            .glassEffect(.regular, in: .capsule)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private var availableSwipeActions: [MediaAction] {
        MediaAction.visibleActions(order: actionOrder, hidden: hiddenActions).filter { action in
            switch action {
            case .playback:
                guard let asset = swipeModel.current else { return false }
                return asset.mediaType == .video || asset.mediaSubtypes.contains(.photoLive)
            case .favorite, .share:
                return swipeModel.current != nil
            case .undo:
                return deletionManager.hasPendingAssets(from: .swipe)
            case .pendingDeletions:
                return !deletionManager.pendingAssets.isEmpty
            case .delete:
                return false
            }
        }
    }

    @ViewBuilder
    private var swipeActions: some View {
        if !availableSwipeActions.isEmpty {
            HStack(spacing: 0) {
                ForEach(availableSwipeActions) { action in
                    swipeAction(action)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }

    @ViewBuilder
    private func swipeAction(_ action: MediaAction) -> some View {
        switch action {
        case .playback:
            if let asset = swipeModel.current,
               asset.mediaType == .video || asset.mediaSubtypes.contains(.photoLive) {
                MediaPlaybackButton(control: playbackControl)
            }
        case .favorite:
            if let asset = swipeModel.current { MediaFavoriteButton(asset: asset) }
        case .share:
            if let asset = swipeModel.current {
                MediaShareButton(asset: asset)
                    .accessibilityLabel("Share Current Media")
            }
        case .undo:
            if deletionManager.hasPendingAssets(from: .swipe) {
                Button { swipeModel.undoLastDeletion() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3)
                        .frame(width: ActionButtonLayout.height, height: ActionButtonLayout.height)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Undo Last Deletion")
            }
        case .pendingDeletions:
            if !deletionManager.pendingAssets.isEmpty {
                Button { isShowingPendingDeletions = true } label: {
                    Label("\(deletionManager.pendingAssets.count)", systemImage: "trash")
                            .monospacedDigit()
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(height: ActionButtonLayout.height)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("View Pending Deletions")
                    .accessibilityValue("\(deletionManager.pendingAssets.count) items")
            }
        case .delete:
            EmptyView()
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

    private func refreshMediaLibrary(suggestLatest: Bool) {
        shouldSuggestLatestAfterRefresh = shouldSuggestLatestAfterRefresh || suggestLatest
        guard !isRefreshingMediaLibrary else {
            return
        }

        isRefreshingMediaLibrary = true
        dismissRefreshSuggestion()

        DispatchQueue.global(qos: .userInitiated).async {
            let assets = PhotoService.shared.fetchAssetSnapshot()
            let albums = PhotoService.shared.fetchAlbumSnapshot()

            DispatchQueue.main.async {
                swipeModel.reset(with: assets)
                timelineModel.reload(
                    assets: assets,
                    grouping: currentTimelineGrouping
                )
                categoriesModel.replace(with: albums, assets: assets)
                refreshGeneration += 1
                isRefreshingMediaLibrary = false

                let suggestLatest = shouldSuggestLatestAfterRefresh
                shouldSuggestLatestAfterRefresh = false
                if suggestLatest && scenePhase == .active && swipeModel.canReturnToLatest {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsRefreshSuggestion = true
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

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            backgroundedAt = .now
            dismissRefreshSuggestion()
        case .active:
            guard let backgroundedAt else {
                return
            }

            self.backgroundedAt = nil
            guard Date.now.timeIntervalSince(backgroundedAt) > 5 * 60 else {
                return
            }

            refreshMediaLibrary(
                suggestLatest: true
            )
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func dismissRefreshSuggestion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showsRefreshSuggestion = false
        }
    }
}

#Preview {
    ContentView()
}
