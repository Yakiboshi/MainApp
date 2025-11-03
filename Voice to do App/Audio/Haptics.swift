import UIKit

enum Haptics {
    static func lightTap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

