import Foundation
import UserNotifications
import SwiftData

@MainActor
final class LocalNotificationManager: NSObject {
    static let shared = LocalNotificationManager()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Pending summary

    struct PendingSummary {
        var mainMessageIds: Set<String>
        var snoozeMessageIds: Set<String>
    }

    func fetchPendingSummary(completion: @escaping (PendingSummary) -> Void) {
        center.getPendingNotificationRequests { requests in
            var mainIds = Set<String>()
            var snoozeIds = Set<String>()

            for req in requests {
                let id = req.identifier
                if id.contains("-main-") {
                    if let mid = LocalNotificationManager.messageId(from: id) {
                        mainIds.insert(mid)
                    }
                } else if id.contains("-snooze-") {
                    if let mid = LocalNotificationManager.messageId(from: id) {
                        snoozeIds.insert(mid)
                    }
                } else if let mid = req.content.userInfo["messageId"] as? String {
                    // 旧形式のIDでも userInfo から拾う
                    if let kind = req.content.userInfo["kind"] as? String {
                        if kind == "main" { mainIds.insert(mid) }
                        if kind == "snooze" { snoozeIds.insert(mid) }
                    }
                }
            }

            DispatchQueue.main.async {
                completion(PendingSummary(mainMessageIds: mainIds, snoozeMessageIds: snoozeIds))
            }
        }
    }

    private static func messageId(from identifier: String) -> String? {
        // "<uuid>-main-0" / "<uuid>-snooze-0" を想定
        if let range = identifier.range(of: "-main-") {
            return String(identifier[..<range.lowerBound])
        }
        if let range = identifier.range(of: "-snooze-") {
            return String(identifier[..<range.lowerBound])
        }
        return nil
    }

    // MARK: - Main alarm (25 notifications)

    func scheduleMainAlarm(for recording: RecordingEntity, in context: ModelContext) {
        let messageId = recording.id.uuidString
        // まずこのIDに紐づく既存 main 通知を削除
        cancelMainNotifications(for: messageId) { [weak self] in
            self?.enqueueMainNotifications(for: recording)
        }
    }

    private func enqueueMainNotifications(for recording: RecordingEntity) {
        let messageId = recording.id.uuidString
        let now = Date()
        let baseInterval = max(0.5, recording.recordedAt.timeIntervalSince(now))

        for i in 0..<25 {
            let content = UNMutableNotificationContent()
            content.title = "着信予定があります"
            content.body = "録音メッセージの再生時間です"
            content.categoryIdentifier = "CALL_INCOMING"
            content.userInfo = [
                "messageId": messageId,
                "kind": "main",
                "index": i
            ]

            if let sound = NotificationSoundProvider.currentNotificationSoundName() {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            } else {
                content.sound = .default
            }

            let interval = baseInterval + TimeInterval(7 * i)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let identifier = "\(messageId)-main-\(i)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    private func cancelMainNotifications(for messageId: String, completion: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.contains("\(messageId)-main-") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
            DispatchQueue.main.async { completion?() }
        }
    }

    // MARK: - Snooze (9 notifications, global max 4)

    func canScheduleSnooze(for recording: RecordingEntity,
                           completion: @escaping (Bool, Int) -> Void) {
        let targetId = recording.id.uuidString
        fetchPendingSummary { summary in
            let activeSnoozeIds = summary.snoozeMessageIds
            let alreadyForTarget = activeSnoozeIds.contains(targetId)
            let activeCount = activeSnoozeIds.count
            let remaining = max(0, 4 - activeCount)
            let can = (!alreadyForTarget && remaining > 0)
            completion(can, remaining)
        }
    }

    func scheduleSnooze(for recording: RecordingEntity,
                        in context: ModelContext,
                        completion: ((Bool, Int) -> Void)? = nil) {
        canScheduleSnooze(for: recording) { [weak self] can, remaining in
            guard can else {
                completion?(false, remaining)
                return
            }
            self?.enqueueSnoozeNotifications(for: recording) {
                // スヌーズ登録後の残枠を再計算して返す
                self?.fetchPendingSummary { summary in
                    let activeCount = summary.snoozeMessageIds.count
                    let newRemaining = max(0, 4 - activeCount)
                    completion?(true, newRemaining)
                }
            }
        }
    }

    private func enqueueSnoozeNotifications(for recording: RecordingEntity,
                                            completion: (() -> Void)? = nil) {
        let messageId = recording.id.uuidString
        let now = Date()
        let snoozeMinutes = recording.snoozeMin ?? 10
        let startDate = now.addingTimeInterval(TimeInterval(snoozeMinutes * 60))
        let baseInterval = max(0.5, startDate.timeIntervalSince(now))

        for i in 0..<9 {
            let content = UNMutableNotificationContent()
            content.title = "再通知: \(recording.title ?? "")"
            content.body = "録音メッセージの再生時間です"
            content.categoryIdentifier = "CALL_INCOMING"
            content.userInfo = [
                "messageId": messageId,
                "kind": "snooze",
                "index": i
            ]

            if let sound = NotificationSoundProvider.currentNotificationSoundName() {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            } else {
                content.sound = .default
            }

            let interval = baseInterval + TimeInterval(7 * i)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let identifier = "\(messageId)-snooze-\(i)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
        completion?()
    }

    func cancelAllNotifications(for messageId: String) {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.contains("\(messageId)-main-") || $0.contains("\(messageId)-snooze-") || $0 == messageId }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications
                .map { $0.request.identifier }
                .filter { $0.contains("\(messageId)-main-") || $0.contains("\(messageId)-snooze-") || $0 == messageId }
            self.center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    // MARK: - Queue management

    func refreshQueue(in context: ModelContext) {
        fetchPendingSummary { [weak self] summary in
            guard let self else { return }
            do {
                let fd = FetchDescriptor<RecordingEntity>()
                var all = try context.fetch(fd)
                // scheduled かつ 未来のものだけを対象
                let now = Date()
                all = all.filter { ($0.status ?? "scheduled") == "scheduled" && $0.recordedAt > now }
                all.sort { $0.recordedAt < $1.recordedAt }

                // 既に main がある場合は最も早い1件だけ残し、それ以外の main をキャンセル
                var activeMainIds = summary.mainMessageIds
                if !activeMainIds.isEmpty {
                    // DBに存在するIDだけに絞る
                    let validIds = Set(all.map { $0.id.uuidString })
                    activeMainIds = activeMainIds.intersection(validIds)
                }

                if activeMainIds.count > 1 {
                    // 最も早い recordedAt のものだけを残し、それ以外は main をキャンセル
                    let idToRecording: [String: RecordingEntity] = Dictionary(uniqueKeysWithValues: all.map { ($0.id.uuidString, $0) })
                    let sorted = activeMainIds.compactMap { idToRecording[$0] }.sorted { $0.recordedAt < $1.recordedAt }
                    if let keep = sorted.first {
                        let keepId = keep.id.uuidString
                        for mid in activeMainIds where mid != keepId {
                            self.cancelMainNotifications(for: mid, completion: nil)
                        }
                        return
                    }
                }

                if activeMainIds.isEmpty {
                    // main が無ければ、最も早い1件だけ main を新規予約
                    if let next = all.first {
                        self.scheduleMainAlarm(for: next, in: context)
                    }
                }
            } catch {
                // 失敗時は何もしない
            }
        }
    }

    // MARK: - Voicemail migration + queue advance

    func convertExpiredToVoicemail(in context: ModelContext,
                                   graceSeconds: TimeInterval = 15) {
        VoicemailMigrator.migrateIfNeeded(context: context, graceSeconds: graceSeconds)
    }

    func handleNotificationFinished(for messageId: String, in context: ModelContext) {
        // main/snooze の通知を整理し、留守電移行 → 次の本体予約
        convertExpiredToVoicemail(in: context)
        refreshQueue(in: context)
    }
}

