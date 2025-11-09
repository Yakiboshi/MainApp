import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    func scheduleNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "着信予定があります"
        content.body = "録音メッセージの再生時間です"

        // カスタムサウンドがあれば使用
        if Bundle.main.url(forResource: "localsound", withExtension: "mp3") != nil {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("localsound.mp3"))
        } else {
            content.sound = .default
        }

        let components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                // MVP: ログのみ
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}

