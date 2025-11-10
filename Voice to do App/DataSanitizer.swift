import Foundation
import SwiftData
import UserNotifications

enum DataSanitizer {
    private static let flagKey = "dataSanitizer_v1_done"

    static func runIfNeeded(context: ModelContext) {
        // 既に実行済みならスキップ
        if UserDefaults.standard.bool(forKey: flagKey) { return }
        sanitize(context: context)
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    static func sanitize(context: ModelContext) {
        do {
            let fd = FetchDescriptor<RecordingEntity>()
            let items = try context.fetch(fd)
            var changedAny = false

            for rec in items {
                var changed = false
                // status の正規化
                let allowed = ["scheduled", "answered", "missed"]
                if !allowed.contains(rec.status ?? "") {
                    rec.status = "scheduled"
                    changed = true
                }

                // answered なのに answeredAt が無い場合は補完（recordedAt を既定として使用）
                if (rec.status ?? "") == "answered" && rec.answeredAt == nil {
                    rec.answeredAt = rec.recordedAt
                    changed = true
                }

                // missed の受信箱フラグ補正／それ以外は false
                if (rec.status ?? "") == "missed" {
                    if rec.inVoicemailInbox == false { rec.inVoicemailInbox = true; changed = true }
                } else {
                    if rec.inVoicemailInbox == true { rec.inVoicemailInbox = false; changed = true }
                }

                if changed { changedAny = true }
            }

            if changedAny { try? context.save() }
        } catch {
            // 失敗時は何もしない（初期化の邪魔をしない）
        }
    }
}
