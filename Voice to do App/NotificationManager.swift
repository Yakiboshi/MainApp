import Foundation
import UserNotifications
import AVFoundation

final class NotificationManager {
    static let shared = NotificationManager()

    // 仕様変更: 指定時刻から7秒間隔で計25回通知を登録
    // 通知音は ks035.wav（存在かつ7秒以内であれば）を適用。無ければ .default。
    func scheduleNotification(for date: Date, messageId: String? = nil) {
        let baseId = messageId ?? UUID().uuidString
        let center = UNUserNotificationCenter.current()

        // 25回分を7秒間隔で手動スケジュール（繰り返しは60秒未満不可のため）
        let now = Date()
        let baseInterval = max(0.5, date.timeIntervalSince(now))

        for i in 0..<25 {
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

            let interval = baseInterval + TimeInterval(7 * i)
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

    // 着信画面遷移時：残りの同一メッセージIDの通知をキャンセル（未配信分）し、配信済みも取り除く
    func cancelAllNotifications(for messageId: String?) {
        guard let mid = messageId, !mid.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map { $0.identifier }.filter { $0.hasPrefix("\(mid)_") || $0 == mid }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
        center.getDeliveredNotifications { notes in
            let ids = notes.map { $0.request.identifier }.filter { $0.hasPrefix("\(mid)_") || $0 == mid }
            if !ids.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    // デバッグ用スヌーズ: 既定60秒後に再スケジュール
    func scheduleSnooze(for messageId: String, snoozeSeconds: TimeInterval = 60) {
        let next = Date().addingTimeInterval(snoozeSeconds)
        scheduleNotification(for: next, messageId: messageId)
    }

    // 将来: 各メッセージのスヌーズ日時指定に対応
    func scheduleSnooze(at date: Date, for messageId: String) {
        scheduleNotification(for: date, messageId: messageId)
    }
}
