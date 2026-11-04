import SwiftUI

/// A pinch changes only the media transform; the player keeps its identity.
private struct HiddenMediaZoom: ViewModifier {
    let enabled: Bool
    let assetID: String?
    @State private var saved = Zoom()
    @State private var viewport: CGSize = .zero
    @State private var drag: CGSize = .zero
    @GestureState private var pinch: MagnifyGesture.Value?

    private struct Zoom {
        var scale: CGFloat = 1
        var anchor: UnitPoint = .center

        func moved(by delta: CGSize, in size: CGSize) -> Self {
            guard scale > 1, size.width > 0, size.height > 0 else { return self }
            // scaleEffect translates by (1 - scale) * anchor * viewport.
            func shifted(_ anchor: CGFloat, _ distance: CGFloat, _ extent: CGFloat) -> CGFloat {
                min(max(anchor - distance / ((scale - 1) * extent), 0), 1)
            }
            return Zoom(scale: scale, anchor: UnitPoint(
                x: shifted(anchor.x, delta.width, size.width),
                y: shifted(anchor.y, delta.height, size.height)
            ))
        }

        func applying(_ pinch: MagnifyGesture.Value?) -> Self {
            guard let pinch else { return self }
            let next = min(max(scale * pinch.magnification, 1), 5)
            guard next > 1 else { return Zoom() }
            let ratio = next / scale
            func coordinate(_ old: CGFloat, _ focus: CGFloat) -> CGFloat {
                min(max((ratio * (scale - 1) * old + (ratio - 1) * focus) / (next - 1), 0), 1)
            }
            return Zoom(scale: next, anchor: UnitPoint(
                x: coordinate(anchor.x, pinch.startAnchor.x),
                y: coordinate(anchor.y, pinch.startAnchor.y)
            ))
        }
    }

    func body(content: Content) -> some View {
        let zoom = enabled ? saved.applying(pinch).moved(by: drag, in: viewport) : Zoom()
        content
            .scaleEffect(zoom.scale, anchor: zoom.anchor)
            .clipped()
            .contentShape(Rectangle())
            .highPriorityGesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { saved = saved.applying($0) },
                isEnabled: enabled && assetID != nil
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { viewport = $0 }
            .gesture(
                SingleFingerDrag(enabled: enabled && assetID != nil && saved.scale > 1) { drag = $0 } ended: { translation in
                    saved = saved.moved(by: translation, in: viewport)
                    drag = .zero
                } cancelled: { drag = .zero }
            )
            .onChange(of: enabled) { _, _ in saved = Zoom(); drag = .zero }
            .onChange(of: assetID) { _, _ in saved = Zoom(); drag = .zero }
    }
}

extension View {
    func hiddenMediaZoom(enabled: Bool, assetID: String?) -> some View {
        modifier(HiddenMediaZoom(enabled: enabled, assetID: assetID))
    }
}

/// Only one finger may initiate browsing, deletion, or panning.
struct SingleFingerDrag: UIGestureRecognizerRepresentable {
    let enabled: Bool
    let changed: (CGSize) -> Void
    let ended: (CGSize) -> Void
    let cancelled: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.isEnabled = enabled
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = enabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let point = recognizer.translation(in: recognizer.view)
        let translation = CGSize(width: point.x, height: point.y)
        switch recognizer.state {
        case .began, .changed: changed(translation)
        case .ended: ended(translation)
        case .cancelled, .failed: cancelled()
        default: break
        }
    }
}
