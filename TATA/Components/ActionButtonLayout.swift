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
