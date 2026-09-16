import SwiftUI
import Photos

struct SwipeView: View {
    private enum DragAxis {
        case horizontal
        case vertical
    }

    private let swipeThreshold: CGFloat = 100
    private let transitionDuration: Double = 0.18

    @ObservedObject
    var model: SwipeViewModel

    @State private var offset: CGSize = .zero
    @State private var dragAxis: DragAxis?
    @State private var includedAlbumTitles: [String] = []
    @State private var showsAllIncludedAlbums = false

    private var transitionProgress: Double {
        guard let dragAxis else {
            return 0
        }

        let distance: CGFloat
        switch dragAxis {
        case .horizontal:
            distance = abs(offset.width)
        case .vertical:
            distance = abs(offset.height)
         }

        return min(max(Double(distance / 500), 0), 1)
    }

    init(model: SwipeViewModel) {
        self.model = model
    }

    var body: some View {
        GeometryReader { safeAreaProxy in
            GeometryReader { proxy in
                ZStack {
                    Color(uiColor: .systemBackground)

                    if let previous = model.previous {
                        MediaView(
                            asset: previous,
                            showsPlaybackButton: false
                        )
                        .id(previous.localIdentifier)
                        .opacity(
                            dragAxis == .horizontal && offset.width > 0
                                ? transitionProgress
                                : 0
                        )
                    }

                    if let next = model.next {
                        MediaView(
                            asset: next,
                            showsPlaybackButton: false
                        )
                        .id(next.localIdentifier)
                        .opacity(
                            dragAxis == .vertical
                                || (dragAxis == .horizontal && offset.width < 0)
                                ? transitionProgress
                                : 0
                        )
                    }

                    if let current = model.current {
                        MediaView(
                            asset: current,
                            showsPlaybackButton: true
                        )
                        .id(current.localIdentifier)
                        .background {
                            Color(uiColor: .systemBackground)
                                .opacity(offset == .zero ? 1 : 0)
                        }
                        .offset(offset)
                        .opacity(1 - transitionProgress)
                    } else {
                        ContentUnavailableView(
                            "No Media",
                            systemImage: "photo.on.rectangle.angled",
                            description: Text(
                                model.previous == nil
                                    ? "Your photo library doesn't contain any media."
                                    : "You've reached the end of your media."
                            )
                        )
                        .offset(
                            model.previous == nil ? .zero : offset
                        )
                        .opacity(
                            model.previous == nil
                                ? 1
                                : 1 - transitionProgress
                        )
                    }
                }
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height
                )
                .position(
                    x: proxy.size.width / 2,
                    y: proxy.size.height / 2
                )
                .contentShape(Rectangle())
                .gesture(dragGesture)
            }
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                if !includedAlbumTitles.isEmpty {
                    includedAlbumsPills()
                        .padding(.top, safeAreaProxy.safeAreaInsets.top + 12)
                        .padding(.leading, 16)
                }
            }
        }
        .task(id: model.current?.localIdentifier) {
            loadIncludedAlbums()
        }
    }

    @ViewBuilder
    private func includedAlbumsPills() -> some View {
        let displayedTitles = showsAllIncludedAlbums
            ? includedAlbumTitles
            : Array(includedAlbumTitles.prefix(2))

        VStack(alignment: .leading, spacing: 6) {
            ForEach(displayedTitles, id: \.self) { title in
                Text("Included in \(title)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Color(uiColor: .systemGray).opacity(0.55),
                        in: Capsule()
                    )
            }

            if includedAlbumTitles.count > 2, !showsAllIncludedAlbums {
                Button {
                    showsAllIncludedAlbums = true
                } label: {
                    Text("…")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Color(uiColor: .systemGray).opacity(0.55),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show all included albums")
            }
        }
    }

    private func loadIncludedAlbums() {
        guard let asset = model.current else {
            includedAlbumTitles = []
            showsAllIncludedAlbums = false
            return
        }

        let albums = PHAssetCollection.fetchAssetCollectionsContaining(
            asset,
            with: .album,
            options: nil
        )

        includedAlbumTitles = (0..<albums.count).compactMap { index in
            albums.object(at: index).localizedTitle
        }
        showsAllIncludedAlbums = false
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragAxis == nil {
                    let horizontalDistance = abs(value.translation.width)
                    let verticalDistance = abs(value.translation.height)

                    if max(horizontalDistance, verticalDistance) > 8 {
                        dragAxis = horizontalDistance >= verticalDistance
                            ? .horizontal
                            : .vertical
                    }
                }

                if let dragAxis {
                    switch dragAxis {
                    case .horizontal:
                        offset = CGSize(
                            width: value.translation.width,
                            height: 0
                        )
                    case .vertical:
                        offset = CGSize(
                            width: 0,
                            height: value.translation.height
                        )
                    }
                } else {
                    offset = value.translation
                }
            }
            .onEnded { value in
                let x = value.translation.width
                let y = value.translation.height

                guard let dragAxis else {
                    resetDrag()
                    return
                }

                if dragAxis == .vertical, y < -swipeThreshold {
                    delete()
                } else if dragAxis == .horizontal, x < -swipeThreshold {
                    next()
                } else if dragAxis == .horizontal, x > swipeThreshold {
                    previous()
                } else {
                    resetDrag()
                }
            }
    }

    private func resetDrag() {
        withAnimation {
            offset = .zero
        }
        dragAxis = nil
    }

    private func next() {
        guard model.current != nil else {
            resetDrag()
            return
        }

        withAnimation(.easeOut(duration: transitionDuration)) {
            offset.width = -500
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + transitionDuration
        ) {
            model.moveNext()
            offset = .zero
            dragAxis = nil
        }
    }

    private func previous() {
        guard model.previous != nil else {
            resetDrag()
            return
        }

        withAnimation(.easeOut(duration: transitionDuration)) {
            offset.width = 500
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + transitionDuration
        ) {
            model.movePrevious()
            offset = .zero
            dragAxis = nil
        }
    }

    private func delete() {
        withAnimation {
            offset.height = -500
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + transitionDuration
        ) {
            model.markCurrentForDeletion()
            offset = .zero
            dragAxis = nil
        }
    }
}

#Preview {
    ContentView()
}
