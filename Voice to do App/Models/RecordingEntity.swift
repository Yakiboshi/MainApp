import Foundation
import SwiftData

@Model
final class RecordingEntity {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    var fileName: String
    var duration: Double
    // 詳細設定（任意）
    var title: String?
    var afterMessage: String?
    var snoozeMin: Int?
    // ステータス管理（将来の拡張を考慮して String）
    // "scheduled" | "answered" | "missed" を想定（既定は "scheduled"）
    var status: String
    // 応答時刻（履歴並び替えに使用）
    var answeredAt: Date?
    // 留守電受信箱に入っているか（missed との併用可）
    var inVoicemailInbox: Bool

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        fileName: String,
        duration: Double,
        title: String? = nil,
        afterMessage: String? = nil,
        snoozeMin: Int? = nil,
        status: String = "scheduled",
        answeredAt: Date? = nil,
        inVoicemailInbox: Bool = false
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.fileName = fileName
        self.duration = duration
        self.title = title
        self.afterMessage = afterMessage
        self.snoozeMin = snoozeMin
        self.status = status
        self.answeredAt = answeredAt
        self.inVoicemailInbox = inVoicemailInbox
    }
}
