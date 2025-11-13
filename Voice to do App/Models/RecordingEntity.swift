import Foundation
import SwiftData

@Model
final class RecordingEntity {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    // 録音ファイルを保存した日時（着信画面での表示に使用）
    // 既存データ互換のため Optional（導入前レコードは nil）
    var savedAt: Date? = nil
    var fileName: String
    var duration: Double
    // 詳細設定（任意）
    var title: String?
    // タイトルが自動生成（空白時の代替）かどうか
    var isAutoTitle: Bool = false
    var afterMessage: String?
    var snoozeMin: Int?
    // 追加項目（詳細登録画面対応）
    var linkURLString: String? = nil           // https:// のみ
    var iconImageData: Data? = nil             // 円形アイコン画像（PNG/JPEGのバイト列）
    @Relationship(deleteRule: .cascade) var tasks: [RecordingTaskEntity] = [] // ToDo（子）
    // タスクの締切（相対指定・どちらかの概念）
    var deadlineHours: Int? = nil
    var deadlineMinutes: Int? = nil
    var deadlineDays: Int? = nil
    // ステータス管理（将来の拡張を考慮し Optional。既存ストアの軽量マイグレーションを通すため）
    // "scheduled" | "answered" | "missed" を想定。nil は未設定として扱い、UI側で "scheduled" と同等に扱う
    var status: String? = nil
    // 応答時刻（履歴並び替えに使用）
    var answeredAt: Date? = nil
    // 留守電受信箱に入っているか（missed との併用可）
    var inVoicemailInbox: Bool = false

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        savedAt: Date? = nil,
        fileName: String,
        duration: Double,
        title: String? = nil,
        isAutoTitle: Bool = false,
        afterMessage: String? = nil,
        snoozeMin: Int? = nil,
        status: String = "scheduled",
        answeredAt: Date? = nil,
        inVoicemailInbox: Bool = false,
        linkURLString: String? = nil,
        iconImageData: Data? = nil,
        tasks: [RecordingTaskEntity] = [],
        deadlineHours: Int? = nil,
        deadlineMinutes: Int? = nil,
        deadlineDays: Int? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.savedAt = savedAt
        self.fileName = fileName
        self.duration = duration
        self.title = title
        self.isAutoTitle = isAutoTitle
        self.afterMessage = afterMessage
        self.snoozeMin = snoozeMin
        self.status = status
        self.answeredAt = answeredAt
        self.inVoicemailInbox = inVoicemailInbox
        self.linkURLString = linkURLString
        self.iconImageData = iconImageData
        self.tasks = tasks
        self.deadlineHours = deadlineHours
        self.deadlineMinutes = deadlineMinutes
        self.deadlineDays = deadlineDays
    }
}

@Model
final class RecordingTaskEntity {
    @Attribute(.unique) var id: UUID
    var text: String
    var isDone: Bool
    init(id: UUID = UUID(), text: String = "", isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}
