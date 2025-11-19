import Foundation
import SwiftData

@Model
final class NotificationSoundEntity {
    @Attribute(.unique) var id: UUID
    /// カスタム通知音ファイルの URL 文字列（file://...）。デフォルト時は Library/Sounds/notification.wav か nil
    var soundURL: String?
    /// デフォルト音源かどうか
    var isDefault: Bool
    /// 設定画面表示用のファイル名（カスタム時）。未設定なら URL から推定
    var displayName: String?
    /// 最終更新日時
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        soundURL: String? = nil,
        isDefault: Bool = true,
        displayName: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.soundURL = soundURL
        self.isDefault = isDefault
        self.displayName = displayName
        self.updatedAt = updatedAt
    }
}

