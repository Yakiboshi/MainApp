import Foundation
import UserNotifications
import SwiftData

@MainActor
final class LocalNotificationManager: NSObject {
    static let shared = LocalNotificationManager()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Public API

    /// すべての pending 通知を一度クリアし、現在の RecordingEntity から 64 件制限に収まるよう再スケジュールする
    func refreshAllNotifications(in context: ModelContext) {
        // 先に留守電への移行判定を実行（graceSeconds は後続で動的調整する）
        VoicemailMigrator.migrateIfNeeded(context: context)

        // 既存 pending 通知を全削除
        center.removeAllPendingNotificationRequests()

        do {
            let fd = FetchDescriptor<RecordingEntity>()
            let all = try context.fetch(fd)

            let now = Date()
            // 通知対象: 「未来の」scheduled かつ 留守電受信箱に入っていないもの
            // 過去時刻の予定は新たに鳴らさず、VoicemailMigrator 側で未応答扱いにする
            let scheduled = all.filter {
                ($0.status ?? "scheduled") == "scheduled" && !$0.inVoicemailInbox && $0.recordedAt > now
            }
            let count = scheduled.count
            guard count > 0 else { return }

            let perCall: Int
            if count == 1 || count == 2 {
                perCall = 25
            } else {
                perCall = max(1, 64 / count)
            }

            // 履歴＋留守電由来のベースバッジ値（現在の SwiftData 状態から算出）
            let counts = AppBadgeManager.compute(using: context)
            let baseBadge = counts.history + counts.voicemail

            for (index, rec) in scheduled.enumerated() {
                let messageId = rec.id.uuidString
                for i in 0..<perCall {
                    let content = UNMutableNotificationContent()
                    if let title = rec.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        content.title = title
                    } else {
                        content.title = "着信予定があります"
                    }
                    content.body = "録音メッセージの再生時間です"
                    content.categoryIdentifier = "CALL_INCOMING"
                    content.userInfo = [
                        "messageId": messageId
                    ]

                    if let sound = NotificationSoundProvider.currentNotificationSoundName() {
                        content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
                    } else {
                        content.sound = .default
                    }

                    let baseTime = rec.recordedAt
                    let triggerTime = baseTime.addingTimeInterval(TimeInterval(7 * i))
                    let interval = max(triggerTime.timeIntervalSince(now), 1)
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                    let identifier = "call_\(messageId)_\(i)"

                    // 各着信の「最後の通知」にだけバッジ値を付与する。
                    // index は 0 始まりなので +1 し、ベース（履歴+留守電）に加算した値を設定する。
                    if i == perCall - 1 {
                        let badgeValue = baseBadge + (index + 1)
                        content.badge = NSNumber(value: badgeValue)
                    }

                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    center.add(request, withCompletionHandler: nil)
                }
            }
        } catch {
            // フェッチ失敗時は何もしない
        }
    }

    /// 指定した messageId に紐づく pending/delivered 通知をすべて削除する
    func cancelAllNotifications(for messageId: String) {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter {
                    if let mid = $0.content.userInfo["messageId"] as? String, mid == messageId {
                        return true
                    }
                    return $0.identifier.hasPrefix("call_\(messageId)_") || $0.identifier == messageId
                }
                .map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .filter {
                    if let mid = $0.request.content.userInfo["messageId"] as? String, mid == messageId {
                        return true
                    }
                    let id = $0.request.identifier
                    return id.hasPrefix("call_\(messageId)_") || id == messageId
                }
                .map { $0.request.identifier }
            self.center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// スヌーズ: recordedAt を未来にずらし、isSnoozed を true にしてから全体を再スケジュール
    func scheduleSnooze(for recording: RecordingEntity, in context: ModelContext) {
        let now = Date()
        let minutes = recording.snoozeMin ?? 10
        let newDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        recording.recordedAt = newDate
        recording.isSnoozed = true
        try? context.save()
        // スヌーズ後の予定を反映し、バッジベースも更新
        _ = AppBadgeManager.refresh(using: context)
        refreshAllNotifications(in: context)
    }
}
