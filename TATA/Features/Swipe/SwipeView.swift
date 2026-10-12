import SwiftUI
import Photos

struct SwipeView: View {
    private enum DragAxis {
        case horizontal
        case vertical
    }

    private let swipeThreshold: CGFloat = 80
    private let transitionDuration: Double = 0.28

    @ObservedObject
    var model: SwipeViewModel

    @AppStorage("autoplayLivePhotos")
    private var autoplayLivePhotos = true

    @AppStorage("autoplayVideos")
    private var autoplayVideos = true

    @State private var offset: CGSize = .zero
    @State private var dragAxis: DragAxis?

    @State private var isTransitioning = false
    @State private var settlingDirection: CGSize = .zero

    private var direction: CGSize { isTransitioning ? settlingDirection : offset }

    private var isReversing: Bool {
        dragAxis == .horizontal && direction.width > 0 && model.previous != nil
    }

    private var isAdvancing: Bool {
        model.current != nil && (
            (dragAxis == .horizontal && direction.width < 0)
                || (dragAxis == .vertical && direction.height < 0)
        )
    }

    private func progress(in size: CGSize) -> CGFloat {
        let distance = dragAxis == .vertical ? -offset.height : abs(offset.width)
        let extent = dragAxis == .vertical ? size.height : size.width
        return min(max(distance / max(extent, 1), 0), 1)
    }

    init(model: SwipeViewModel) {
        self.model = model
    }

    var body: some View {
        GeometryReader { safeAreaProxy in
            GeometryReader { proxy in
                let progress = progress(in: proxy.size)
                let shrinksCurrent = isReversing || (isAdvancing && dragAxis == .vertical)
                ZStack {
                    Color(uiColor: .systemBackground)

                    if let next = model.next {
                        MediaView(asset: next, showsPlaybackButton: false)
                            .id(next.localIdentifier)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .scaleEffect(0.8 + 0.2 * progress, anchor: .center)
                            .opacity(isAdvancing ? Double(progress) : 0)
                            .allowsHitTesting(false)
                    }

                    Group {
                        if let current = model.current {
                            MediaView(
                                asset: current,
                                showsPlaybackButton: true,
                                playsAnimatedImages: true,
                                autoplaysLivePhoto: autoplayLivePhotos,
                                autoplaysVideo: autoplayVideos
                            )
                            .id(current.localIdentifier)
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
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(shrinksCurrent ? 1 - 0.2 * progress : 1, anchor: .center)
                    .opacity(isReversing ? Double(1 - progress) : 1)
                    .offset(isAdvancing ? offset : .zero)
                    .zIndex(1)

                    if let previous = model.previous {
                        MediaView(asset: previous, showsPlaybackButton: false)
                            .id(previous.localIdentifier)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .offset(x: -proxy.size.width * (1 - progress))
                            .opacity(isReversing ? 1 : 0)
                            .allowsHitTesting(false)
                            .zIndex(2)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(dragGesture(in: proxy.size))
            }
            .ignoresSafeArea(.container, edges: .vertical)
            .overlay(alignment: .topLeading) {
                if let asset = model.current {
                    MediaInfoOverlay(asset: asset)
                        .padding(.top, safeAreaProxy.safeAreaInsets.top + 6)
                        .padding(.leading, 16)
                }
            }
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isTransitioning else { return }
                if dragAxis == nil {
                    let x = abs(value.translation.width)
                    let y = abs(value.translation.height)
                    guard max(x, y) > 8 else { return }
                    dragAxis = x >= y ? .horizontal : .vertical
                }
                switch dragAxis {
                case .horizontal:
                    let x = value.translation.width
                    guard (x > 0 && model.previous != nil) || (x < 0 && model.current != nil) else {
                        offset = .zero
                        return
                    }
                    offset = CGSize(width: min(max(x, -size.width), size.width), height: 0)
                case .vertical:
                    // Downward drags have no assigned action or media transform.
                    offset = model.current == nil ? .zero : CGSize(
                        width: 0,
                        height: max(min(value.translation.height, 0), -size.height)
                    )
                case nil:
                    break
                }
            }
            .onEnded { value in
                guard !isTransitioning else { return }
                if dragAxis == .vertical, value.translation.height < -swipeThreshold, model.current != nil {
                    complete(to: CGSize(width: 0, height: -size.height), action: model.markCurrentForDeletion)
                } else if dragAxis == .horizontal, value.translation.width < -swipeThreshold, model.current != nil {
                    complete(to: CGSize(width: -size.width, height: 0), action: model.moveNext)
                } else if dragAxis == .horizontal, value.translation.width > swipeThreshold, model.previous != nil {
                    complete(to: CGSize(width: size.width, height: 0), action: model.movePrevious)
                } else {
                    complete(to: .zero, action: {})
                }
            }
    }

    private func complete(to destination: CGSize, action: @escaping () -> Void) {
        settlingDirection = offset
        isTransitioning = true
        withAnimation(
            .timingCurve(0.22, 1, 0.36, 1, duration: transitionDuration),
            completionCriteria: .removed
        ) {
            offset = destination
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                action()
                offset = .zero
                dragAxis = nil
                isTransitioning = false
            }
        }
    }
}

#Preview {
    ContentView()
}
