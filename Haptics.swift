import UIKit

enum Haptics {
    enum Kind { case soft, rigid, error }
    static func play(_ kind: Kind) {
        switch kind {
        case .soft:  UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
