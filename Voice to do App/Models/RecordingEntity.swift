import Foundation
import SwiftData

@Model
final class RecordingEntity {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    var fileName: String
    var duration: Double

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        fileName: String,
        duration: Double
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.fileName = fileName
        self.duration = duration
    }
}

