import Foundation
import AVFoundation
import UserNotifications
import AVKit

// 通知／マイク権限の確認・要求ユーティリティ
enum PermissionManager {
    static func requestLaunchPermissions(completion: ((Bool, Bool) -> Void)? = nil) {
        var notifOK = false
        var micOK = false
        let group = DispatchGroup()

        // 通知
        group.enter()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            notifOK = granted
            group.leave()
        }

        // マイク
        group.enter()
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            micOK = granted
            group.leave()
        }

        group.notify(queue: .main) {
            completion?(notifOK, micOK)
        }
    }

    // 任意: カメラ権限（撮影機能を実装した時に使用）
    static func requestCameraPermission(completion: ((Bool) -> Void)? = nil) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion?(granted) }
        }
    }
}
