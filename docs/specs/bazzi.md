🎯 タイトル

「最後の通知にタスク数＋未達着信数を合算したバッジを付与し、フォアグラウンド時に再集計する機能を実装してください」

🧠 概要説明

SwiftUI + SwiftData で開発しているアプリにて、
着信（ローカル通知）とタスクの未完了数を合算してアプリアイコンにバッジ表示したいです。

ローカル通知は各着信に対して複数回（7秒間隔）登録されていますが、
最後の通知だけ に、
「現在のタスク数＋1（未達着信分）」の値をアプリアイコンバッジとして表示してください。

また、アプリがフォアグラウンドに戻った時に、
タスク数＋未達着信数 を再集計してバッジを更新するようにしてください。

⚙️ 実装仕様
1. バッジ設定ロジック

通知登録関数内で、各着信の最後の通知だけにバッジを設定します。

バッジ値は次のように決定します：

バッジ数 = 現在のタスク数 + 1


（タスクが3件ある場合 → 最後の通知で badge = 4）

他の通知（途中の通知）にはバッジを付けません。

2. 再集計ロジック（アプリ起動／フォアグラウンド復帰時）

SwiftData からタスク・未達着信を再集計し、
以下の関数でバッジを更新してください。

💻 サンプルコード
import SwiftUI
import UserNotifications

// MARK: - 通知登録時の例
func scheduleCallNotifications(callItem: CallItem, taskCount: Int) {
    let center = UNUserNotificationCenter.current()
    let perCall = 25
    let interval: TimeInterval = 7

    for i in 0..<perCall {
        let content = UNMutableNotificationContent()
        content.title = callItem.title
        content.sound = UNNotificationSound(named: .init("localsound.mp3"))
        content.userInfo = ["id": callItem.id.uuidString]

        // 最後の通知にのみバッジを設定
        if i == perCall - 1 {
            content.badge = NSNumber(value: taskCount + 1)
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: callItem.fireDate.timeIntervalSinceNow + (interval * Double(i)),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "call_\(callItem.id)_\(i)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }
}

// MARK: - バッジ再集計関数
func updateAppBadge(taskCount: Int, unhandledCalls: Int) {
    let totalBadge = taskCount + unhandledCalls
    UIApplication.shared.applicationIconBadgeNumber = totalBadge
    UserDefaults.standard.set(totalBadge, forKey: "AppBadgeCount")
}

// MARK: - ScenePhase監視で再集計
struct BadgeUpdater: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let taskCount: Int
    let unhandledCalls: Int

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    updateAppBadge(taskCount: taskCount, unhandledCalls: unhandledCalls)
                }
            }
    }
}

// MARK: - 使用例
struct ContentView: View {
    @State private var taskCount = 3
    @State private var unhandledCalls = 1

    var body: some View {
        Text("Main App")
            .modifier(BadgeUpdater(taskCount: taskCount, unhandledCalls: unhandledCalls))
    }
}

✅ 期待する動作

通知登録時に、最後の通知のみ badge = (タスク数 + 1) が設定される

通知発火時にその合計バッジがアプリアイコンに反映される

アプリをフォアグラウンドに戻した際に、
SwiftData上の最新タスク数・未達着信数から再計算して更新される

他機能のバッジとは干渉しない


