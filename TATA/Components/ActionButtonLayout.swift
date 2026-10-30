import SwiftUI
import Combine
import CoreGraphics
import UIKit

/// Shared height for primary actions and joined media action bars.
enum ActionButtonLayout {
    static let height: CGFloat = 52
}

/// Feedback for explicit actions; browsing and background updates stay silent.
@MainActor
enum ActionFeedback {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

@MainActor
final class BlockingActionController: ObservableObject {
    @Published private(set) var message: String?

    func run(message: String, operation: @escaping @MainActor () async -> Void) {
        guard self.message == nil else { return }
        self.message = message
        Task { @MainActor in
            defer { self.message = nil }
            // Give the confirmation dialog time to dismiss and the pill to appear.
            try? await Task.sleep(for: .milliseconds(250))
            await operation()
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}

struct BlockingActionOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
            HStack(spacing: 12) {
                ProgressView()
                Text(message)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .combine)
        }
    }
}

extension View {
    /// Keep playback and layout alive while hiding only the viewing controls.
    func mediaChromeHidden(_ hidden: Bool) -> some View {
        opacity(hidden ? 0 : 1)
            .allowsHitTesting(!hidden)
            .accessibilityHidden(hidden)
            .animation(.easeInOut(duration: 0.2), value: hidden)
    }
}
