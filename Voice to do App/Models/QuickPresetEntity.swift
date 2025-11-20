import Foundation
import SwiftData

@Model
final class QuickPresetEntity {
    var id: UUID
    var title: String
    var daysOffset: Int // 1..7 typically（絶対日時プリセット用の日数オフセット）
    var hour: Int // 0..23（絶対日時プリセット用の時）
    var minute: Int // 0..59（絶対日時プリセット用の分）
    // 相対時刻プリセット用のフラグとパラメータ（hours または days のどちらか片方を使用）
    var isRelative: Bool = false
    var relativeHours: Double?
    var relativeDays: Int?
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        daysOffset: Int,
        hour: Int,
        minute: Int,
        isRelative: Bool = false,
        relativeHours: Double? = nil,
        relativeDays: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.daysOffset = daysOffset
        self.hour = hour
        self.minute = minute
        self.isRelative = isRelative
        self.relativeHours = relativeHours
        self.relativeDays = relativeDays
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }
}
