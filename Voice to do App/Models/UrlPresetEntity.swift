import Foundation
import SwiftData

@Model
final class UrlPresetEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var urlString: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = createdAt
    }
}

