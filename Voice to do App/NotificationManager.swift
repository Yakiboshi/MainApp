import Foundation
import UserNotifications
import SwiftData

/// 既存コードから呼ばれる薄いラッパー。
/// 実際のローカル通知の挙動は LocalNotificationManager が担当する。
final class NotificationManager {
    static let shared = NotificationManager()

    // 互換API（現在は未使用）：古い呼び出し元との互換のため残しているが、
    // 実際の通知スケジュールは RecordingView / PlannedDetailView から
    // LocalNotificationManager.refreshQueue(...) を直接呼び出す。
    func scheduleNotification(for date: Date, messageId: String? = nil) {
        // 新実装では何もしない
    }

    // 着信画面遷移時：残りの同一メッセージIDの通知をキャンセル（未配信分）し、配信済みも取り除く
    func cancelAllNotifications(for messageId: String?) {
        guard let mid = messageId, !mid.isEmpty else { return }
        LocalNotificationManager.shared.cancelAllNotifications(for: mid)
    }

    // スヌーズ登録: LocalNotificationManager に委譲
    func scheduleSnooze(for messageId: String, snoozeSeconds: TimeInterval = 60) {
        // 旧API互換のため残しているが、実際には IncomingCallView から
        // LocalNotificationManager.scheduleSnooze(...) を直接呼ぶ。
    }

    func scheduleSnooze(at date: Date, for messageId: String) {
        // date は現状未使用（RecordingEntity.snoozeMin を優先）
        scheduleSnooze(for: messageId)
    }
}
