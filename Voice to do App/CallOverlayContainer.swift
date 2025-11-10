import SwiftUI

struct CallOverlayContainer: View {
    @ObservedObject private var router = NotificationRouter.shared

    var body: some View {
        Group {
            if let mid = router.showAfterCallForMessageId {
                AfterCallView(messageId: mid)
            } else if let mid = router.callMessageId {
                CallConversationView(messageId: mid)
            } else if let mid = router.incomingMessageId {
                IncomingCallView(messageId: mid)
            } else {
                EmptyView()
            }
        }
        .ignoresSafeArea()
    }
}

