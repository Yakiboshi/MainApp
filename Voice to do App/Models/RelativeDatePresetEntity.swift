import Foundation
import SwiftData

/// キーパッド画面の「日付プリセット」用の相対日時プリセット。
/// - hours または days のどちらか一方を利用する（hours 優先）。
@Model
final class RelativeDatePresetEntity {
    var id: UUID
    var title: String
    /// 時間ベースのプリセットかどうか（true: hours を使用, false: days を使用）
    var isHourBased: Bool
    /// 時間ベースのときの時間数（0.5〜24.0 など）
    var hours: Double?
    /// 日数ベースのときの日数（8〜365 など）
    var days: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isHourBased: Bool,
        hours: Double? = nil,
        days: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isHourBased = isHourBased
        self.hours = hours
        self.days = days
        self.createdAt = createdAt
    }
}

