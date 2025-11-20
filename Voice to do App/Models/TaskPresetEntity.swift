import Foundation
import SwiftData

@Model
final class TaskPresetEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    @Relationship(deleteRule: .cascade) var items: [TaskPresetItemEntity] = []
    var deadlineHours: Int?
    var deadlineMinutes: Int?
    var deadlineDays: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        items: [TaskPresetItemEntity] = [],
        deadlineHours: Int? = nil,
        deadlineMinutes: Int? = nil,
        deadlineDays: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.deadlineHours = deadlineHours
        self.deadlineMinutes = deadlineMinutes
        self.deadlineDays = deadlineDays
        self.createdAt = createdAt
    }
}

@Model
final class TaskPresetItemEntity {
    @Attribute(.unique) var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

