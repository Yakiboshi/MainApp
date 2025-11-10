import Foundation
import Combine
import SwiftUI

final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    @Published var incomingMessageId: String? = nil
    @Published var requestedTabIndex: Int? = nil
    @Published var showAfterCallForMessageId: String? = nil
    @Published var showIntermediateForRecordingId: UUID? = nil
    @Published var callMessageId: String? = nil

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
            // 画面遷移は無アニメーションで
            withAnimation(nil) { self.showAfterCallForMessageId = messageId }
        }
    }

    func presentIntermediate(for recordingId: UUID) {
        DispatchQueue.main.async {
            withAnimation(nil) { self.showIntermediateForRecordingId = recordingId }
        }
    }

    func dismissIntermediate() {
        DispatchQueue.main.async {
            withAnimation(nil) { self.showIntermediateForRecordingId = nil }
        }
    }

    func dismissAfterCall() {
        DispatchQueue.main.async {
            withAnimation(nil) { self.showAfterCallForMessageId = nil }
        }
    }

    func presentCall(for messageId: String) {
        DispatchQueue.main.async {
            withAnimation(nil) { self.callMessageId = messageId }
        }
    }

    func dismissCall() {
        DispatchQueue.main.async {
            withAnimation(nil) { self.callMessageId = nil }
        }
    }

    var hasAnyCallOverlay: Bool {
        incomingMessageId != nil || callMessageId != nil || showAfterCallForMessageId != nil
    }
}
