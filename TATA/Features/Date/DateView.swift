import SwiftUI
import Photos

struct DateView: View {
    @ObservedObject var model: DateViewModel
    @ObservedObject var deletionManager: DeletionManager
    @Binding var isShowingPendingDeletions: Bool

    @AppStorage(TimelineGrouping.storageKey)
    private var timelineGrouping = TimelineGrouping.date.rawValue

    private var grouping: TimelineGrouping {
        TimelineGrouping(rawValue: timelineGrouping) ?? .date
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if model.sections.isEmpty {
                        ContentUnavailableView(
                            "No Media",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text(
                                "Your photo library doesn't contain media with a date."
                            )
                        )
                    } else {
                        List {
                            ForEach(model.sections) { section in
                                Section(sectionTitle(for: section)) {
                                    ForEach(section.periods) { period in
                                        NavigationLink {
                                            DateDayGridView(
                                                period: period,
                                                deletionManager: deletionManager,
                                                refreshTimeline: {
                                                    model.reload(grouping: grouping)
                                                }
                                            )
                                        } label: {
                                            DateTimelineRow(
                                                period: period,
                                                grouping: grouping,
                                                deletionManager: deletionManager
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }

                if !deletionManager.pendingAssets.isEmpty {
                    Button {
                        isShowingPendingDeletions = true
                    } label: {
                        Text("Pending Deletions (\(deletionManager.pendingAssets.count))")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(height: PendingDeletionLayout.buttonHeight)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel("Pending Deletions")
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Timeline")
        }
        .onAppear {
            model.reload(grouping: grouping)
        }
        .onChange(of: timelineGrouping) {
            model.reload(grouping: grouping)
        }
    }

    private func sectionTitle(for section: TimelineMediaSection) -> String {
        switch grouping {
        case .date, .week:
            section.date.formatted(.dateTime.year().month(.wide))
        case .month:
            section.date.formatted(.dateTime.year())
        }
    }
}

private struct DateTimelineRow: View {
    let period: TimelineMediaPeriod
    let grouping: TimelineGrouping
    @ObservedObject var deletionManager: DeletionManager

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        HStack(spacing: 12) {
            DateMediaCollage(assets: Array(period.assets.prefix(3)))

            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle)
                    .font(.body.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Text(mediaSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .id(mediaSummary)
                    .transition(.opacity)
                    .contentTransition(.opacity)
                    .animation(
                        .easeInOut(duration: 0.2),
                        value: mediaSummary
                    )
            }
        }
        .padding(.vertical, 4)
    }

    private var dayTitle: String {
        switch grouping {
        case .date:
            if calendar.isDateInToday(period.date) {
                return "Today"
            }

            if calendar.isDateInYesterday(period.date) {
                return "Yesterday"
            }

            return period.date.formatted(.dateTime.month(.abbreviated).day())
        case .week:
            return "Week of \(period.date.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return period.date.formatted(.dateTime.month(.wide))
        }
    }

    private var subtitle: String? {
        switch grouping {
        case .date:
            return period.date.formatted(.dateTime.weekday(.wide).day())
        case .week:
            guard let endDate = calendar.date(
                byAdding: .day,
                value: 6,
                to: period.date
            ) else {
                return nil
            }
            return "\(period.date.formatted(.dateTime.month(.abbreviated).day())) – \(endDate.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return period.date.formatted(.dateTime.year())
        }
    }

    private var mediaSummary: String {
        let pendingIdentifiers = Set(
            deletionManager.pendingAssets.map(\.localIdentifier)
        )
        let visibleAssets = period.assets.filter {
            !pendingIdentifiers.contains($0.localIdentifier)
        }
        var components: [String] = []

        let photoCount = visibleAssets.filter { $0.mediaType == .image }.count
        let videoCount = visibleAssets.filter { $0.mediaType == .video }.count

        if photoCount > 0 {
            components.append("\(photoCount) photos")
        }

        if videoCount > 0 {
            components.append("\(videoCount) videos")
        }

        return components.isEmpty ? "No media" : components.joined(separator: " · ")
    }
}

private struct DateMediaCollage: View {
    let assets: [PHAsset]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(assets, id: \.localIdentifier) { asset in
                MediaView(
                    asset: asset,
                    targetSize: CGSize(width: 240, height: 240),
                    contentMode: .fill
                )
                .frame(width: 24, height: 64)
                .clipped()
            }
        }
        .frame(width: 76, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DateDayGridView: View {
    let period: TimelineMediaPeriod
    @ObservedObject var deletionManager: DeletionManager
    let refreshTimeline: () -> Void

    @State private var isSelecting = false
    @State private var selectedAssetIdentifiers = Set<String>()
    @State private var selectedPhoto: DatePhoto?
    @State private var didChangePendingDeletions = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 3
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(visibleAssets, id: \.localIdentifier) { asset in
                        DateDayGridCell(
                            asset: asset,
                            isSelecting: isSelecting,
                            isSelected: selectedAssetIdentifiers.contains(
                                asset.localIdentifier
                            )
                        ) {
                            toggleSelection(for: asset)
                        } previewAction: {
                            selectedPhoto = DatePhoto(asset: asset)
                        }
                    }
                }
            }

            if isSelecting {
                Button(role: .destructive) {
                    moveSelectionToPendingDeletions()
                } label: {
                    Label(
                        "Move to Pending Deletions",
                        systemImage: "trash"
                    )
                    .padding(.horizontal, 18)
                    .frame(height: PendingDeletionLayout.buttonHeight)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(.red)
                .foregroundStyle(.white)
                .disabled(selectedAssetIdentifiers.isEmpty)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle(periodTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSelecting ? "Done" : "Select") {
                    isSelecting.toggle()
                    if !isSelecting {
                        selectedAssetIdentifiers.removeAll()
                    }
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationStack {
                MediaPhotoPreviewSheet(asset: photo.asset)
            }
        }
        .onDisappear {
            guard didChangePendingDeletions else {
                return
            }
            Task { @MainActor in
                refreshTimeline()
            }
        }
    }

    private var visibleAssets: [PHAsset] {
        let pendingIdentifiers = Set(
            deletionManager.pendingAssets.map(\.localIdentifier)
        )
        return period.assets.filter {
            !pendingIdentifiers.contains($0.localIdentifier)
        }
    }

    private func toggleSelection(for asset: PHAsset) {
        guard isSelecting else {
            return
        }

        if !selectedAssetIdentifiers.insert(asset.localIdentifier).inserted {
            selectedAssetIdentifiers.remove(asset.localIdentifier)
        }
    }

    private func moveSelectionToPendingDeletions() {
        for asset in visibleAssets where selectedAssetIdentifiers.contains(
            asset.localIdentifier
        ) {
            deletionManager.add(asset, source: .date)
        }
        selectedAssetIdentifiers.removeAll()
        isSelecting = false
        didChangePendingDeletions = true
    }

    private var periodTitle: String {
        period.date.formatted(.dateTime.year().month(.wide).day())
    }
}

private struct DateDayGridCell: View {
    let asset: PHAsset
    let isSelecting: Bool
    let isSelected: Bool
    let action: () -> Void
    let previewAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                mediaContent(in: proxy)

                if isSelecting {
                    Button(action: action) {
                        hitTarget(in: proxy)
                    }
                    .buttonStyle(.plain)
                } else if isStaticPhoto {
                    Button(action: previewAction) {
                        hitTarget(in: proxy)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var isStaticPhoto: Bool {
        asset.mediaType == .image
            && !asset.mediaSubtypes.contains(.photoLive)
    }

    private func mediaContent(in proxy: GeometryProxy) -> some View {
        MediaView(
            asset: asset,
            showsPlaybackButton: !isSelecting,
            targetSize: CGSize(width: 600, height: 600),
            contentMode: .fill
        )
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipped()
        .overlay {
            if isSelecting {
                Color.accentColor.opacity(isSelected ? 0.25 : 0)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .white)
                    .shadow(radius: 2)
                    .padding(8)
            }
        }
    }

    private func hitTarget(in proxy: GeometryProxy) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
    }
}

private struct DatePhoto: Identifiable {
    let asset: PHAsset

    var id: String {
        asset.localIdentifier
    }
}

#Preview {
    ContentView()
}
