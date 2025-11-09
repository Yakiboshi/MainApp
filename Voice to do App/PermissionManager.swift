import Foundation
import AVFoundation
import UserNotifications

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
}

