

ローカル通知にバッジ機能を追加し、未達着信のみリセットできるようにしてください

---

### 🧠 要件説明：

SwiftUI + SwiftData で作成している擬似着信アプリに、
**「各着信の最後の通知だけアプリアイコンにバッジを付ける」機能** を追加してください。
また、アプリを開いたりバックグラウンドから復帰したときに、
**他機能のバッジを消さずに未達着信のバッジだけをリセット** できるようにしてください。

---

### 💡 具体的な仕様：

1. **各着信データ（CallItem）**

   * id: UUID
   * fireDate: Date
   * title: String
   * isCompleted: Bool（応答済みかどうか）

2. **通知登録時（refreshAllNotifications関数内）**

   * 各着信の最後のローカル通知（例：25回中の最後）にだけ
     `content.badge = NSNumber(value: 1)` を設定する。
   * 最後の通知を「未達着信」としてカウントし、
     `UserDefaults.standard.set(unhandledCount, forKey: "CallBadgeCount")`
     に保存する。
   * 実際のバッジ数は `UIApplication.shared.applicationIconBadgeNumber += unhandledCount` で反映する。

3. **アプリ起動時・フォアグラウンド復帰時**

   * ScenePhaseの `.active` で `resetCallBadgesOnly()` を呼び出す。

   * 関数の内容は以下の通り：

     ```swift
     func resetCallBadgesOnly() {
         let defaults = UserDefaults.standard
         let callBadgeCount = defaults.integer(forKey: "CallBadgeCount")
         let totalBadge = UIApplication.shared.applicationIconBadgeNumber
         let remainingBadge = max(totalBadge - callBadgeCount, 0)
         UIApplication.shared.applicationIconBadgeNumber = remainingBadge
         defaults.set(0, forKey: "CallBadgeCount")
     }
     ```

   * これにより、他機能のバッジ（例：別通知機能で付与されたもの）は残しつつ、
     着信未対応バッジだけをリセットできるようにする。

---

### ✅ 期待する動作：

* 各着信の最後の通知だけバッジがつく
* バッジは「未対応着信数」に応じて増加
* アプリを開く／復帰した時に未達バッジのみ消える
* 他機能のバッジには影響しない


