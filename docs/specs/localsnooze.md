localsnooze.md 実装計画（ToDo）
=============================

目的：既存の擬似着信アプリの仕様・データ構造を壊さずに、docs/specs/localsnooze.md の通知キュー＋スヌーズ仕様を満たす実装を行う。

前提
----
- アラームの実体は SwiftData の `RecordingEntity`（予定時刻は `recordedAt`）とする。
- 既存の通知入口は `NotificationManager.scheduleNotification(for:messageId:)` と `scheduleSnooze(...)`、通知タップ時のルートは `AppNotificationCenterDelegate` → `NotificationRouter.openIncomingCall`。
- 留守電判定は `VoicemailMigrator` が「recordedAt 経過 ＋ pending 通知なし」で行っている。
- これらの既存インターフェイスを可能な限り維持しつつ、内部実装を新しい「通知キュー管理システム（LocalNotificationManager）」に差し替える。

1. 設計整理（責務とIDルール）
----------------------------
- 「アラーム」の定義を整理し、`RecordingEntity`＋`status`＋`inVoicemailInbox` を中心に扱うことを明文化する。
- 通知のID・userInfo のルールを決める。
  - 本体 25 回通知: `"<messageId>-main-<0...24>"`。
  - スヌーズ 9 回通知: `"<messageId>-snooze-<0...8>"`。
  - `userInfo`: `["messageId": messageId, "kind": "main"|"snooze", "index": i]`。
- 「同時に予約できる本体アラームは 1 件」「スヌーズは最大 4 件・各 9 通知」として、合計 25 + 9×4 = 61 通知以内に収まる前提でロジックを設計する。

2. LocalNotificationManager の新規実装
-----------------------------------
- 新規ファイル `LocalNotificationManager.swift` を追加し、以下を実装する。
  - `@MainActor final class LocalNotificationManager: NSObject`。
  - `static let shared` シングルトン。
  - コアAPI：
    - `scheduleMainAlarm(for recording: RecordingEntity, in context: ModelContext)`  
      - 1件の `RecordingEntity` に対して 7 秒間隔×25 回の通知を登録。
      - 既にその messageId の main 通知があればキャンセルしてから再登録。
    - `scheduleSnooze(for recording: RecordingEntity, in context: ModelContext)`  
      - 1件の `RecordingEntity` に対して 7 秒間隔×9 回のスヌーズ通知を登録。
      - スヌーズ開始時刻は `Date() + snoozeSeconds`（既存の `snoozeMin` を用いる）とし、その時刻から 7 秒ごとに 9 通知を並べる。
    - `refreshQueue(in context: ModelContext)`  
      - SwiftData から「status が scheduled で recordedAt が未来」のレコードを取得し、recordedAt 昇順で並べる。
      - UNUserNotificationCenter の pending 通知を解析し、「本体アラームとして現在予約中の messageId セット」と「スヌーズ中の messageId セット」を把握。
      - 本体アラームについて：
        - main 通知を持つ messageId が 0 件 → キュー先頭（最も早い recordedAt）だけ main を新規予約。
        - main 通知を持つ messageId が複数 → 未来の最も早い 1 件だけを残し、他は main 通知をキャンセル。
      - 予約済みだが DB から削除された messageId が存在する場合 → その通知をキャンセルし、再度ロジックを評価。
    - `convertExpiredToVoicemail(in context: ModelContext)`  
      - 既存の `VoicemailMigrator.migrateIfNeeded` を内部から呼び出すか、同等のロジックを内包し、  
        「recordedAt を一定時間過ぎ、かつ main 通知が1件も残っていない scheduled レコード」を `status = "missed"`, `inVoicemailInbox = true` に更新。
    - `handleNotificationFinished(for messageId: String, in context: ModelContext)`  
      - 何らかのきっかけ（通知キャンセル、削除など）で main 通知群が消えたタイミングで呼び出すヘルパ。
      - 内部で `convertExpiredToVoicemail` → `refreshQueue` を連続して実行し、次の本体アラームを 1 件だけ予約する。
- UNUserNotificationCenter とのブリッジヘルパ：
  - `fetchPendingSummary(completion:)` を用意し、pending 通知から  
    - main 用 messageId セット  
    - snooze 用 messageId セット  
    を算出して返す（ID 文字列 or userInfo.kind から判定）。

3. Snooze 制約（1件1回＋アプリ全体4件）の実装
------------------------------------------
- LocalNotificationManager 内に以下を実装する。
  - `func canScheduleSnooze(for recording: RecordingEntity, completion: @escaping (Bool, Int) -> Void)`  
    - UNUserNotificationCenter の pending 通知を解析し：
      - 対象 recording の messageId について、`-snooze-` を含む ID が 1 件でもあれば「そのレコードにはスヌーズを追加できない」と判定。
      - 全 pending 通知から snooze 中の messageId セットを作り、その件数を `activeSnoozeCount` とする。
      - グローバル残枠 = `max(0, 4 - activeSnoozeCount)` を計算。
    - `(canSchedule, globalRemaining)` をコールバックする。
- `scheduleSnooze(for recording: ...)` は、上記 `canScheduleSnooze` を使って以下を満たす。
  - グローバル残枠が 0 の場合は何も登録しない。
  - 対象 recording にすでに snooze 通知がある場合も登録しない。
  - 実際に登録した場合のみ `completion(true, newRemaining)` のような形で UI 側が残り回数を更新できるようにする。
  - 「ボタン右下の残り回数」はグローバル残枠（4 - 現在のスヌーズ件数）のみ表示する。

4. NotificationManager との統合（ラッパー化）
-----------------------------------------
- 既存 `NotificationManager.swift` の役割を「古い実装」から「LocalNotificationManager への薄いラッパー」に変更する。
  - `scheduleNotification(for date: Date, messageId: String?)`  
    - 引数から messageId を受け取り、SwiftData から対応する `RecordingEntity` を取得。
    - LocalNotificationManager の `refreshQueue(...)` を呼び出す形に変更し、「新規予約されたレコードも含めてキューを再構築」するようにする。  
    - 今後、個別の日時指定による直接 UNUserNotificationCenter 予約は LocalNotificationManager 側のみで行う。
  - `cancelAllNotifications(for messageId: String?)`  
    - ID ルール（`-main-` / `-snooze-`）に合わせて main/snooze の両方をキャンセルするユーティリティとして維持。
  - `scheduleSnooze(for messageId: String, snoozeSeconds: TimeInterval)` / `scheduleSnooze(at:for:)`  
    - SwiftData から `RecordingEntity` を解決し、LocalNotificationManager の `scheduleSnooze` を呼ぶように変更。
    - 内部では `snoozeSeconds` より `recording.snoozeMin` を優先し、開始時刻を決める。
- これにより、`RecordingView.finishAndProceed()`・`PlannedDetailView.saveAndClose()`・`VoicemailMigrator` などの呼び出し元は既存APIのままでも、新実装に移行できる。

5. アプリ起動時のキュー初期化
---------------------------
- `Voice_to_do_AppApp` 初期化処理内（`Voice_to_do_AppApp.swift`）に、LocalNotificationManager の初期化呼び出しを追加。
  - 例：`LocalNotificationManager.shared.bootstrap(modelContainer:)` のようなメソッドで
    - UNUserNotificationCenter の delegate を LocalNotificationManager に設定（既存の AppNotificationCenterDelegate の役割と競合しない形で統合を検討）。
    - アプリ起動時に `convertExpiredToVoicemail` と `refreshQueue` を一度走らせる。
- 既存の `AppNotificationCenterDelegate` が行っている「通知タップ→擬似着信画面へのルート」処理は維持しつつ、将来的には LocalNotificationManager の delegate 実装内から `NotificationRouter` を呼び出す形に寄せていく。

6. IncomingCallView（着信画面）の更新
----------------------------------
- レイアウト：
  - 既存の「拒否」「応答」2ボタン構成を「拒否｜再通知｜応答」の3ボタン構成に変更（`IncomingCallView.swift`）。
  - 再通知ボタンは白地 × 黒い繰り返しマーク＋その下に小さく白文字で「スヌーズ」と表示。
  - ボタン右下には「グローバル残枠（4 - 現在のスヌーズ件数）」を表示（例：`残り 3`）。
    - LocalNotificationManager.canScheduleSnooze の `globalRemaining` を使ってテキスト更新。
    - グローバル残枠が 0 の場合はボタンを無効化し、ビジュアルもグレーアウト。
- 振る舞い：
  - 拒否ボタン：
    - 残りの本体通知・スヌーズ通知をすべてキャンセル。
    - 対象レコードを `status = "missed"`, `inVoicemailInbox = true` に更新して保存。
    - `NotificationRouter` 経由でキーパッドタブへ戻る。
  - 再通知ボタン：
    - LocalNotificationManager.canScheduleSnooze で可否とグローバル残枠を確認。
    - 可の場合のみ LocalNotificationManager.scheduleSnooze を実行し、成功時に残枠表示を更新。
    - 実行後はキーパッド画面に遷移（`NotificationRouter.switchToTab(2)` 等）。
  - 応答ボタン：
    - 既存の通話開始処理（ステータス更新、ルーティング）は維持。
    - 副作用として main/snooze 通知をキャンセルし、必要に応じて LocalNotificationManager.handleNotificationFinished を呼ぶ。
- `onAppear` で：
  - 対象 recording を読み込み、タイトルやサブテキスト表示を維持。
  - LocalNotificationManager.canScheduleSnooze を呼び出し、初回のグローバル残枠表示とボタン有効/無効を決定。

7. 予定リスト・編集画面の仕様反映
------------------------------
- `PlannedPlaceholderView`：
  - セルのサブテキストを「データ作成日時（savedAt）」から「着信日時（recordedAt）」のみに変更。
  - LocalNotificationManager から「現在 main アラームとして予約されている基準時刻 T」を取得できるようにし、  
    - `recordedAt` が T+60秒, T+120秒, T+180秒 のいずれかと一致するレコードについて：
      - 着信日時の文字色を黄色にする。
      - その下に灰色の小さなテキスト「前の着信に埋もれて発信されない可能性があります。」を表示。
- `PlannedDetailView`（予定編集画面）：
  - 予定日時を変更した際、`recordedAt` を更新した上で、LocalNotificationManager.refreshQueue を呼び出してキューを再構築。
  - 通知の直接再登録は NotificationManager（→ LocalNotificationManager）が行うため、既存の API 呼び出しを内部実装変更で吸収。

8. 同時刻予約バリデーション（キーパッド＋予定編集）
-----------------------------------------------
- 「同じ時刻で 2 件以上の予約が存在しない」ことを保証する。
- キーパッド（`AppTabsView`）：
  - `onOk` 内で `destination.toDate()` を `scheduledAt` として算出。
  - SwiftData から「status が scheduled で recordedAt == scheduledAt」のレコードを検索し、  
    - 一件でも存在する場合は `DestinationTime` 表示を赤色（既存の `destinationForegroundColor` を拡張）にし、Call ボタンのアクションを無効化。
  - 既存の「形式的な日付エラー」チェック（年・月・日上限など）と組み合わせて、`hasImmediateInvalid` に「同時刻重複」の判定を追加。
- 予定編集画面（`PlannedDetailView`）：
  - `isFutureDate` に加え、「他レコードとの重複がないか」を確認する `isUniqueScheduledDate` を追加。
  - 自分以外の `RecordingEntity` で `recordedAt == scheduledAt` のものが存在する場合は、エラーメッセージを表示し、完了ボタンを無効化（opacity 低下）。
  - レコード削除時は DB から対象が消えるだけで、次回バリデーション時に自然と「空き」扱いになるため、特別な解除処理は不要。

9. 削除・留守電移行時の通知キャンセル・キュー更新
---------------------------------------------
- 予定リストからの削除処理（`PlannedPlaceholderView.delete(_:)`）を拡張。
  - 既存の `NotificationManager.cancelAllNotifications(for:)` を呼び出した後、  
    LocalNotificationManager.handleNotificationFinished を呼んでキューを再構築。
- 留守電移行（`VoicemailMigrator` または LocalNotificationManager.convertExpiredToVoicemail）：
  - main 通知が 0 件で recordedAt を一定時間過ぎたレコードを「missed + inVoicemailInbox」にし、  
    その後 `refreshQueue` を呼んで次の本体アラームを 1 件だけ予約。
- スヌーズ中に削除された場合も、`cancelAllNotifications` で snooze 通知を含めてキャンセルし、  
  `handleNotificationFinished` でキューを整理する。

10. 動作確認シナリオ
-------------------
- 単一アラーム：
  - 未来の日時で録音 → 保存 → main 25 通知が 7 秒間隔で発行されること。
  - 通知のどれかをタップすると擬似着信画面に遷移し、以降の main/snooze 通知がキャンセルされること。
- キュー動作：
  - A・B・C の 3 件を未来時刻で作成し、常に「最も早い 1 件」だけが main として予約されていること。
  - A の通知完了 or 削除 or 留守電移行後に、B が main として自動登録されること。
- スヌーズ：
  - 再通知ボタンを押すと、`snoozeMin` に応じた時間後に 7秒×9回の短期通知が鳴ること。
  - 同一レコードで 2 回連続のスヌーズ登録ができないこと（1回目が終了するまでは不可）。
  - 同時に 5 件以上のスヌーズを登録しようとすると、4 件目までは成功し 5 件目はボタン無効で登録されないこと。
  - ボタン右下の「残り回数」が常に「グローバル残枠（4 − 現在のスヌーズ件数）」を表示すること。
- 同時刻予約バリデーション：
  - 既に A が 2025-01-01 10:00 で登録されている状態で、同じ時刻をキーパッドから入力すると DESTINATIONTIME が赤色になりコール不可になること。
  - 予定編集画面でも既存の別レコードと時刻が被ると完了ボタンが押せないこと。
  - 重複の元になっていたレコードを削除すると、その時刻で再び新規登録・編集完了が可能になること。

この ToDo に沿って、まず LocalNotificationManager の実装と NotificationManager ラッパー化から着手し、その後 IncomingCallView・予定リスト・バリデーションの順で UI 側へ反映していく。
