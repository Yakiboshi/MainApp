import Foundation
import SwiftData
import UserNotifications

enum VoicemailMigrator {
    // 条件を満たす scheduled レコードを留守電へ移行
    // 条件: (now >= recordedAt + 動的grace) かつ 同一messageIdの保留通知が0件
    static func migrateIfNeeded(context: ModelContext, graceSeconds: TimeInterval = 15) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let allIds = reqs.map { $0.identifier }
            let now = Date()
            DispatchQueue.main.async {
                do {
                    let fd = FetchDescriptor<RecordingEntity>()
                    let all = try context.fetch(fd)
                    // 通知対象となる scheduled レコードのみを対象にする（留守電 inbox 済みは除外）
                    let scheduled = all.filter { ($0.status ?? "scheduled") == "scheduled" && !$0.inVoicemailInbox }

                    // 現在の N と perCall を算出
                    let count = scheduled.count
                    guard count > 0 else { return }

                    let perCall: Int
                    if count == 1 || count == 2 {
                        perCall = 25
                    } else {
                        perCall = max(1, 64 / count)
                    }

                    // 1件あたりの鳴動幅 + 追加猶予
                    let ringSpan = 7 * max(perCall - 1, 0)
                    let dynamicGrace = TimeInterval(ringSpan) + graceSeconds

                    var changed = false
                    for rec in scheduled {
                        // 予定時刻が少し過ぎている
                        if now.timeIntervalSince(rec.recordedAt) >= dynamicGrace {
                            // 保留通知にこのIDが含まれていなければ、未応答と見なす
                            let id = rec.id.uuidString
                            // 旧形式: "<id>-main-*" / "<id>-snooze-*"
                            // 新形式: "call_<id>_<index>"
                            let hasAnyPending = allIds.contains {
                                $0.contains("\(id)-main-") ||
                                $0.contains("\(id)-snooze-") ||
                                $0 == id ||
                                $0.hasPrefix("call_\(id)_")
                            }
                            if !hasAnyPending {
                                rec.status = "missed"
                                rec.inVoicemailInbox = true
                                rec.isSnoozed = false
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
