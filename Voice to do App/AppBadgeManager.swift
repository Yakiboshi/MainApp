import Foundation
import SwiftData
import UIKit

enum AppBadgeManager {
    private static let totalKey = "AppIconBadgeTotal"

    /// SwiftData の内容からバッジ数を再計算し、アプリアイコンと UserDefaults に反映する
    @MainActor
    static func refresh(using context: ModelContext) -> (history: Int, voicemail: Int) {
        do {
            let fd = FetchDescriptor<RecordingEntity>()
            let items = try context.fetch(fd)
            let history = items.filter { ($0.status ?? "scheduled") == "answered" && !$0.tasks.isEmpty && $0.tasks.contains(where: { !$0.isDone }) }.count
            let voicemail = items.filter { (($0.status ?? "scheduled") == "missed" || $0.inVoicemailInbox) }.count
            let total = history + voicemail

            #if os(iOS)
            UIApplication.shared.applicationIconBadgeNumber = total
            #endif
            UserDefaults.standard.set(total, forKey: totalKey)

            return (history, voicemail)
        } catch {
            return (0, 0)
        }
    }

    /// 最後に保存した合計バッジ数を取得（アプリ未起動時の推定ベースとして利用）
    static func storedTotal() -> Int {
        UserDefaults.standard.integer(forKey: totalKey)
    }
}

