import SwiftUI

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

    @State private var isShowingPendingDeletions = false
    @State private var selectedTab: AppTab = .swipe
    @State private var isRefreshingMediaLibrary = false
    @State private var refreshGeneration = 0
    @State private var showsRefreshConfirmation = false
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
                        refreshMediaLibrary: refreshMediaLibrary,
                        isRefreshing: isRefreshingMediaLibrary,
                        presentUserGuide: {
                            isShowingUserGuide = true
                        }
                    )
                }
            }

            if selectedTab == .swipe,
               (swipeModel.current != nil
                || !deletionManager.pendingAssets.isEmpty) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
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
                    }
                    .padding(.bottom, PendingDeletionLayout.buttonBottomInset)
                }

            if showsRefreshConfirmation {
                Label("Media Library Refreshed", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .label))
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .accessibilityAddTraits(.isStaticText)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
            }

            if showsRefreshSuggestion {
                HStack(spacing: 10) {
                    Label(
                        "New media may be available",
                        systemImage: "photo.badge.plus"
                    )
                    .font(.subheadline.weight(.semibold))

                    Button("Refresh") {
                        dismissRefreshSuggestion()
                        refreshMediaLibrary()
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .accessibilityHint("Refreshes your media library")
                }
                .foregroundStyle(Color(uiColor: .label))
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .frame(height: 40)
                .glassEffect(.regular, in: .capsule)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .padding(.bottom, refreshSuggestionBottomInset)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsRefreshSuggestion)
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
        dismissRefreshSuggestion()
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
                categoriesModel.replace(with: albums, assets: assets)
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

    private var refreshSuggestionBottomInset: CGFloat {
        if selectedTab == .swipe, swipeModel.current != nil {
            return PendingDeletionLayout.buttonBottomInset
                + PendingDeletionLayout.buttonHeight + 20
        }

        return PendingDeletionLayout.buttonBottomInset
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            backgroundedAt = .now
            dismissRefreshSuggestion()
        case .active:
            guard let backgroundedAt,
                  Date.now.timeIntervalSince(backgroundedAt) >= 5 * 60,
                  deletionManager.pendingAssets.isEmpty,
                  selectedTab != .settings else {
                return
            }

            self.backgroundedAt = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                showsRefreshSuggestion = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                dismissRefreshSuggestion()
            }
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
