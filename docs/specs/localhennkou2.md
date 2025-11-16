#  実現したい仕様

### ◆ 1. ローカル通知の上限

iPhone のローカル通知は **最大64件まで同時に登録可能**。

---

### ◆ 2. 各着信（1件）が持つローカル通知数は動的に変化

**現在登録されている総着信件数（本体アラーム + スヌーズ含む）を N とする**

```
通知数_per_call = floor(64 ÷ N)
```

### ◆ 3. 特別ルール（あなたの要望）

* **登録件数が1件 or 2件の場合** → 通知回数は **25回で固定**
* **3件以上の場合** → 上記の `64 ÷ N` を使用 (余りは除く（小数点以下は切り捨て）)
* 通知間隔はすべて **7秒間隔**
* 通知はすべて **擬似着信画面を開く**

---

### ◆ 4. 状況が変わるたびに再計算する

以下の時に、**既存の通知をすべてキャンセル → 新ルールで再登録**する：

* 新しい着信（タスク）が保存された時
* 既存の着信が削除された時
* **アプリを開いた時（自動更新）**
* **着信に応答した時（そのデータは再通知対象から外す）**

---

#  設計概要

SwiftUI + SwiftData で構築している擬似着信アプリに、
登録されている着信データ（本体＋スヌーズ）に応じて
ローカル通知の総数が64件以内に収まるように自動調整するロジックを実装してください。

### 2. 全着信を取得し、必要通知数を計算

```
N = 現在保存されている CallItem の総数（スヌーズ含む）

if N == 1 or N == 2:
    notificationsPerCall = 25
else:
    notificationsPerCall = floor(64 / N)
```

### 3. 通知生成ロジック

各 CallItem について

```
for i in 0..<notificationsPerCall {
    triggerTime = fireDate + (7 * i) 秒
}
```

として UNCalendarNotificationTrigger または UNTimeIntervalNotificationTrigger を使って登録してください。

---

### 4. 再計算 & 再登録タイミング

以下のタイミングで実行する関数を1つ作成して呼び出してください：

```
func refreshAllNotifications()
```

呼び出し箇所

* 新規着信保存後
* 着信削除後
* アプリ起動時（SceneDelegate / scenePhase .active）
* 着信に応答して擬似着信画面が開いた時
  　→ そのデータは再通知の対象外にする（isCompleted = true 等を付ける）

---

### 5. 手順

#### (1) まず既存の通知を全て削除

```swift
UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
```

#### (2) SwiftData から CallItem を全件取得

完了済みのものは除外する。

#### (3) `notificationsPerCall` を計算

上記 N に応じた式で計算。

#### (4) 各 CallItem に `notificationsPerCall` 分の通知を作成し登録

identifier は

```
"call_\(callItem.id)_\(index)"
```

のように一意にする。

---

### 6. 擬似着信画面へ遷移

通知タップ時に以下の画面へ遷移してください：

```swift
InComingView(callID: UUID)
```

通知の userInfo に id を入れる：

```swift
content.userInfo = ["id": callItem.id.uuidString]
```

AppDelegate または SceneDelegate の didReceive で
この ID を読み取り適切に遷移させる。

---

### 7. 特記事項

* 1 or 2件のみの場合は常に25回固定（短すぎ/長すぎ防止のため）
* 3件以上なら 64 ÷ N を使用
* 通知間隔は7秒
* 音声ファイルは CallItem.audioURL に保存されている
* 音源は25秒に自動トリミングしたものを再生すること

---

# ✅ 実際に必要なコード例

### ▼ 計算＋再登録メイン関数

```swift
func refreshAllNotifications(context: ModelContext) {
    let items = try! context.fetch(FetchDescriptor<CallItem>())
        .filter { !$0.isCompleted }

    let count = items.count
    guard count > 0 else {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        return
    }

    let perCall: Int
    if count == 1 || count == 2 {
        perCall = 25
    } else {
        perCall = max(1, 64 / count)
    }

    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()

    for item in items {
        for i in 0..<perCall {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.sound = UNNotificationSound(named: .init("localsound.mp3"))
            content.userInfo = ["id": item.id.uuidString]

            let triggerDate = item.fireDate.addingTimeInterval(Double(i) * 7)
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(triggerDate.timeIntervalSinceNow, 1),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "call_\(item.id)_\(i)",
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }
}
```

---

