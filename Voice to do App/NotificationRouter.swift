import Foundation
import Combine

final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    @Published var incomingMessageId: String? = nil
    @Published var requestedTabIndex: Int? = nil
    @Published var showAfterCallForMessageId: String? = nil

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

    func switchToTab(_ index: Int) {
        DispatchQueue.main.async {
            self.requestedTabIndex = index
        }
    }

    func presentAfterCall(for messageId: String) {
        DispatchQueue.main.async {
            self.showAfterCallForMessageId = messageId
        }
    }
}
