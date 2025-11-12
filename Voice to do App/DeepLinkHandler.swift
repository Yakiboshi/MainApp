import Foundation

enum DeepLinkHandler {
    // Supported samples:
    // v2do://incoming/<uuid>
    // v2do://call/<uuid>
    // v2do://after/<uuid>
    // v2do://tab/<0-4>
    static func handle(_ url: URL) {
        // Accept only our expected scheme if present; allow testing with other schemes during development
        if let scheme = url.scheme, !scheme.isEmpty, scheme.lowercased() != "v2do" { return }

        let host = (url.host ?? "").lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let segments = path.split(separator: "/").map(String.init)

        switch host {
        case "incoming":
            // v2do://incoming/<uuid>
            if let mid = segments.first, !mid.isEmpty { NotificationRouter.shared.openIncomingCall(messageId: mid, fromVoicemail: false) }

        case "call":
            // v2do://call/<uuid>
            if let mid = segments.first, !mid.isEmpty { NotificationRouter.shared.presentCall(for: mid) }

        case "after":
            // v2do://after/<uuid>
            if let mid = segments.first, !mid.isEmpty { NotificationRouter.shared.presentAfterCall(for: mid) }

        case "tab":
            // v2do://tab/<index>
            if let idxStr = segments.first, let idx = Int(idxStr) { NotificationRouter.shared.switchToTab(idx) }

        default:
            // Also support path-first form: v2do:///<verb>/<uuid>
            if segments.count >= 1 {
                let verb = segments[0].lowercased()
                let param = segments.count >= 2 ? segments[1] : nil
                switch verb {
                case "incoming": if let mid = param, !mid.isEmpty { NotificationRouter.shared.openIncomingCall(messageId: mid, fromVoicemail: false) }
                case "call": if let mid = param, !mid.isEmpty { NotificationRouter.shared.presentCall(for: mid) }
                case "after": if let mid = param, !mid.isEmpty { NotificationRouter.shared.presentAfterCall(for: mid) }
                case "tab": if let p = param, let idx = Int(p) { NotificationRouter.shared.switchToTab(idx) }
                default: break
                }
            }
        }
    }
}

