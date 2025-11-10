import Foundation
import AVFoundation
import CoreMedia

enum NotificationSoundProvider {
    // 現行の通知音ファイル名（Bundle内）。将来は設定から選択可能に拡張。
    private static let defaultName = "ks035"
    private static let defaultExt = "wav"
    private static let maxDuration: TimeInterval = 30.0 // Apple推奨上限

    // UNNotificationSoundName に渡すファイル名（"name.ext"）を返す。使用不可の場合は nil。
    static func currentNotificationSoundName() -> String? {
        guard let url = Bundle.main.url(forResource: defaultName, withExtension: defaultExt) else {
            return nil
        }
        // 長さチェック（>30秒は不可のため .default にフォールバック）
        if let duration = audioDuration(at: url), duration <= maxDuration {
            return "\(defaultName).\(defaultExt)"
        }
        return nil
    }

    // 将来: ユーザー選択の内蔵サウンドやカスタム候補を返すAPIに拡張予定

    private static func audioDuration(at url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
}
