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

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        fileName: String,
        duration: Double,
        title: String? = nil,
        afterMessage: String? = nil,
        snoozeMin: Int? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.fileName = fileName
        self.duration = duration
        self.title = title
        self.afterMessage = afterMessage
        self.snoozeMin = snoozeMin
    }
}
