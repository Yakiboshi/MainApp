import Foundation
import SwiftData

@Model
final class SoundFile {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var fileURL: URL
    var duration: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        fileURL: URL,
        duration: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.duration = duration
        self.createdAt = createdAt
    }
}

