import Foundation
import UserNotifications
import AVFoundation

final class NotificationManager {
    static let shared = NotificationManager()

    // 仕様変更: 指定時刻から20秒間隔で計10回通知を登録
    // 通知音は ks035.wav（存在かつ30秒以内であれば）を適用。無ければ .default。
    func scheduleNotification(for date: Date, messageId: String? = nil) {
        let baseId = messageId ?? UUID().uuidString
        let center = UNUserNotificationCenter.current()

        // 10回分を20秒間隔で手動スケジュール（繰り返しは60秒未満不可のため）
        let now = Date()
        let baseInterval = max(0.5, date.timeIntervalSince(now))

        for i in 0..<10 {
            let content = UNMutableNotificationContent()
            content.title = "着信予定があります"
            content.body = "録音メッセージの再生時間です"
            content.categoryIdentifier = "CALL_INCOMING"

            if let sound = NotificationSoundProvider.currentNotificationSoundName() {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            } else {
                content.sound = .default
            }

            var info: [AnyHashable: Any] = [:]
            info["messageId"] = baseId
            info["category"] = "CALL_INCOMING"
            info["seq"] = i
            content.userInfo = info

            let interval = baseInterval + TimeInterval(20 * i)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let requestId = "\(baseId)_\(i)"
            let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

            center.add(request) { error in
                if let error = error {
                    print("Failed to schedule notification (\(requestId)): \(error)")
                }
            }
        }
    }
}
