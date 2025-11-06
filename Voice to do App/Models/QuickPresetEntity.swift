import Foundation
import SwiftData

@Model
final class QuickPresetEntity {
    var id: UUID
    var title: String
    var daysOffset: Int // 1..7 typically
    var hour: Int // 0..23
    var minute: Int // 0..59
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(), title: String, daysOffset: Int, hour: Int, minute: Int, createdAt: Date = .now, updatedAt: Date = .now, lastUsedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.daysOffset = daysOffset
        self.hour = hour
        self.minute = minute
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }
}
