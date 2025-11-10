import Foundation
import SwiftData
import UserNotifications

enum VoicemailMigrator {
    // 条件を満たす scheduled レコードを留守電へ移行
    // 条件: (now >= recordedAt + grace) かつ 同一messageIdの保留通知が0件
    static func migrateIfNeeded(context: ModelContext, graceSeconds: TimeInterval = 15) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let allIds = reqs.map { $0.identifier }
            let now = Date()
            DispatchQueue.main.async {
                do {
                    let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.status == "scheduled" })
                    let items = try context.fetch(fd)
                    var changed = false
                    for rec in items {
                        // 予定時刻が少し過ぎている
                        if now.timeIntervalSince(rec.recordedAt) >= graceSeconds {
                            // 保留通知にこのIDが含まれていなければ、未応答と見なす
                            let prefix = rec.id.uuidString + "_"
                            let hasAnyPending = allIds.contains(where: { $0.hasPrefix(prefix) || $0 == rec.id.uuidString })
                            if !hasAnyPending {
                                rec.status = "missed"
                                rec.inVoicemailInbox = true
                                changed = true
                            }
                        }
                    }
                    if changed { try? context.save() }
                } catch { }
            }
        }
    }
}

