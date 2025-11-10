import Foundation
import UserNotifications

final class AppNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationCenterDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // フォアグラウンドでもバナー＋サウンドを許可
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let messageId = info["messageId"] as? String
        // 擬似着信画面へディープリンク（通常通知からは留守電起点ではない）
        NotificationRouter.shared.openIncomingCall(messageId: messageId, fromVoicemail: false)
        completionHandler()
    }
}
