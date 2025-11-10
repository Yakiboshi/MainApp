import Foundation
import Combine

final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    @Published var incomingMessageId: String? = nil

    func openIncomingCall(messageId: String?) {
        DispatchQueue.main.async {
            self.incomingMessageId = messageId ?? ""
        }
    }

    func dismissIncomingCall() {
        DispatchQueue.main.async {
            self.incomingMessageId = nil
        }
    }
}

