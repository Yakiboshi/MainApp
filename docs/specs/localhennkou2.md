localhennkou2.md 実装ToDo（新版）
================================

目的
----
- 既存の SwiftData モデル（`RecordingEntity`）と通知ルート（`userInfo["messageId"]` → `NotificationRouter.openIncomingCall`）を最大限維持したまま、
  ローカル通知 64 件上限に収まる動的な通知再スケジューリングを導入する。
- スヌーズ仕様をシンプルに再設計し、旧来の「通知キュー＋スヌーズ上限（localsnooze）」実装を廃止する。
- 「スヌーズ中」ラベルは残しつつ、「埋もれ警告」は廃止する。
- 通知回数が 64 / N によって減るケースを考慮し、留守電（Voicemail）への移行タイミングを調整する。

基本仕様（再確認）
------------------
- iOS ローカル通知の上限は「同時 64 件」。
- N = 現在ローカル通知の対象となる `RecordingEntity` 件数（`status == "scheduled"` かつ `inVoicemailInbox == false` とする）。
- 各レコードに割り当てる通知回数 `perCall` は以下とする:
  - N == 1 or N == 2 → `perCall = 25`
  - N >= 3 → `perCall = floor(64 / N)`（最低 1 件は鳴るよう `max(1, 64 / N)`）
- 通知間隔は 7 秒固定。
- すべての通知は「擬似着信画面（`IncomingCallView`）」を開く。
- 通知の `userInfo` キーは現行どおり `["messageId": recording.id.uuidString]` を使う。

スヌーズ仕様（新）
-----------------
- スヌーズは「同じ `RecordingEntity` の予定時刻を未来へずらす」挙動とする。
  - `recordedAt = Date() + TimeInterval((recording.snoozeMin ?? defaultSnoozeMin) * 60)`
  - 変更後は `status` を `"scheduled"` のまま維持する。
- 「スヌーズ中」ラベルは、`RecordingEntity` に新たに追加する `isSnoozed: Bool`（デフォルト false）で管理する。
  - スヌーズボタン押下時: `isSnoozed = true`
  - 応答/拒否/留守電移行/編集による予定変更など、通知の役割を終えたタイミングで `isSnoozed = false` に戻す。
- 旧仕様の「スヌーズ 1 件あたり 9 通知」「アプリ全体でスヌーズ 4 件まで」「残りスヌーズ枠表示」はすべて廃止する。

Voicemail への移行タイミング
---------------------------
- 旧仕様: `graceSeconds`（デフォルト 15 秒）経過 かつ ペンディング通知が 0 件になった scheduled レコードを「未応答」とみなし、`status = "missed"`, `inVoicemailInbox = true` にしていた。
- 新仕様では、通知回数が `perCall` に応じて変動するため、「鳴り切るまでの時間＋猶予」を考慮する:
  - 1 件のレコードについて、通知が鳴る時間幅は概ね `ringSpan = 7 * max(perCall - 1, 0)` 秒。
  - `graceSecondsDynamic = ringSpan + 15`（最後の通知から 15 秒程度の猶予）を目安とする。
- 実装イメージ:
  - `VoicemailMigrator` 内で、現在の N と `perCall` を算出し、`graceSecondsDynamic` を求める。
  - ある `RecordingEntity` について  
    `now >= recordedAt + graceSecondsDynamic` かつ ペンディング通知に `messageId` が 1 つも含まれなければ、
    そのレコードを `status = "missed"`, `inVoicemailInbox = true`, `isSnoozed = false` に更新する。

再スケジューリングのトリガー
------------------------
- 以下のタイミングで「ローカル通知を一度全削除 → 現在の N に基づき再登録」を行う:
  - 新しい録音（`RecordingEntity`）が保存されたとき（RecordingView 完了時）。
  - 既存の録音が削除されたとき。
  - 録音の予定時刻（`recordedAt`）が変更されたとき。
  - スヌーズボタン押下で `recordedAt` を未来へ再設定したとき。
  - 着信に「応答」して通話に進んだとき。
  - 着信を「拒否」して留守電扱いにしたとき。
  - アプリ起動時、および `scenePhase == .active` になったとき。

ToDo 1: LocalNotificationManager の全面リファクタ
-----------------------------------------------
- [ ] 旧 `LocalNotificationManager` の設計（main/snooze 通知の 25 回 + 9 回、キュー先頭 1 件のみ main、`PendingSummary` 等）を廃止する。
- [ ] 新しい中核 API を定義する:
  - `func refreshAllNotifications(in context: ModelContext)`
    - `VoicemailMigrator` を使って留守電移行を先に実行（後述の動的 graceSeconds を使用）。
    - `UNUserNotificationCenter.current().removeAllPendingNotificationRequests()` で pending を全削除。
    - SwiftData から通知対象となる `RecordingEntity` を取得し（`status == "scheduled" && !inVoicemailInbox`）、N を算出。
    - N == 0 なら何も登録せず終了。
    - `perCall` を上記ルールで計算（N == 1 or 2 → 25、N >= 3 → max(1, 64 / N)）。
    - 各レコードについて `0..<perCall` ループを回し、
      - `baseTime = recordedAt`
      - `triggerTime = baseTime + TimeInterval(7 * i)`
      - `timeInterval = max(triggerTime.timeIntervalSinceNow, 1)` として `UNTimeIntervalNotificationTrigger` を生成。
      - `UNMutableNotificationContent` を組み立て:
        - `content.userInfo["messageId"] = recording.id.uuidString`
        - タイトル・本文・サウンドは現行実装（`NotificationSoundProvider` 等）を踏襲。
      - `identifier = "call_\(recording.id.uuidString)_\(i)"` を用いて `UNNotificationRequest` を登録。
  - `func cancelAllNotifications(for messageId: String)`  
    - 現行の `cancelAllNotifications` を、`"call_\(messageId)_"` パターンと `userInfo["messageId"]` の両方を見て削除する形に調整。
  - `func scheduleSnooze(for recording: RecordingEntity, in context: ModelContext)`  
    - 上記「新スヌーズ仕様」に従い、`recordedAt` と `isSnoozed` を更新し保存したあと、`refreshAllNotifications(in:)` を呼ぶだけのシンプルな実装にする。
- [ ] 不要になるメソッド/構造体を削除:
  - `PendingSummary` / `fetchPendingSummary(...)`
  - `scheduleMainAlarm(...)` / `enqueueMainNotifications(...)` / `cancelMainNotifications(...)`
  - グローバル 4 件制限付きの `canScheduleSnooze(...)`, 旧 `enqueueSnoozeNotifications(...)`
  - `refreshQueue(...)`, `convertExpiredToVoicemail(...)`, `handleNotificationFinished(...)`

ToDo 2: VoicemailMigrator の動的 graceSeconds 対応
----------------------------------------------
- [ ] `VoicemailMigrator.migrateIfNeeded(context:graceSeconds:)` を拡張し、内部で N と `perCall` を算出できるようにする。
  - `context.fetch(FetchDescriptor<RecordingEntity>())` から、`status == "scheduled"` かつ `!inVoicemailInbox` のものを抽出して N を算出。
  - 上記ルールで `perCall` を決める（N == 0 のときは何も移行しない）。
  - `ringSpan = 7 * max(perCall - 1, 0)`、`graceSecondsDynamic = ringSpan + 15` を求める。
- [ ] 各レコードごとに、
  - `now >= recordedAt + graceSecondsDynamic`
  - かつ `UNUserNotificationCenter` の pending に対応する `messageId` が 1 つも含まれていない
  - を満たすものを `status = "missed"`, `inVoicemailInbox = true`, `isSnoozed = false` に更新する。
- [ ] `LocalNotificationManager.refreshAllNotifications(in:)` および `ContentView` の起動時/フォアグラウンド復帰時は、固定値の `graceSeconds` ではなく、この動的ロジックを使う。

ToDo 3: RecordingEntity モデルの最小拡張
-------------------------------------
- [ ] `RecordingEntity` に `isSnoozed: Bool = false` を追加する（既存ストア互換のためデフォルト false）。
- [ ] スヌーズ開始時に `isSnoozed = true`、以下のタイミングで `false` に戻す:
  - 応答時（`status = "answered"` 設定時）。
  - 拒否時（`status = "missed"`, `inVoicemailInbox = true` 設定時）。
  - VoicemailMigrator による自動未応答判定時。
  - 予定日時編集で `recordedAt` を現在から大きく変更した場合（仕様次第で必要に応じて）。

ToDo 4: NotificationManager / ContentView / 各画面からの呼び出し整理
-------------------------------------------------------------
- [ ] `NotificationManager.scheduleNotification(...)` は今後も未使用のまま（互換 API として保持）で問題ない。
- [ ] `NotificationManager.cancelAllNotifications(for:)` は、内部で `LocalNotificationManager.cancelAllNotifications(for:)` を呼ぶ現行方針を維持し、新しい ID パターンにも対応する。
- [ ] `ContentView`:
  - `.task` 内および `scenePhase == .active` で呼んでいる  
    `VoicemailMigrator.migrateIfNeeded(...)` と `LocalNotificationManager.refreshQueue(...)` を、  
    `LocalNotificationManager.refreshAllNotifications(in:)` に一本化（内部で VoicemailMigrator を呼ぶ実装にするか、事前に動的 grace 版を呼んでから `refreshAllNotifications` を実行）。
- [ ] `RecordingView.finishAndProceed()`:
  - 録音保存後に呼んでいる `LocalNotificationManager.refreshQueue(...)` を `refreshAllNotifications(in:)` に置き換える。
- [ ] `PlannedDetailView.saveAndClose()`:
  - `recordedAt` 変更時の `NotificationManager.cancelAllNotifications(for:)` は維持。
  - その後の `LocalNotificationManager.refreshQueue(...)` を `refreshAllNotifications(in:)` に変更。
- [ ] `PlannedPlaceholderView.delete(_:)`:
  - `NotificationManager.cancelAllNotifications(for:)` の後に呼んでいる `LocalNotificationManager.handleNotificationFinished(...)` を削除し、代わりに `refreshAllNotifications(in:)` を呼ぶ。
  - `updateMainBaseDate()` 呼び出しは、後述の UI リファクタに応じて整理（不要なら削除）。
- [ ] `IncomingCallView`:
  - `onAppear` で行っている「残りのローカル通知キャンセル → handleNotificationFinished(...)」を、  
    「該当 ID の通知キャンセル → `LocalNotificationManager.refreshAllNotifications(in:)`」に変更（Voicemail 移行は `VoicemailMigrator` 側に任せる）。
  - 「拒否」ボタン押下時に `status = "missed"`, `inVoicemailInbox = true`, `isSnoozed = false` をセットした後で `refreshAllNotifications(in:)` を呼ぶ。
  - 「応答」ボタン押下時に `status = "answered"`, `answeredAt = now`, `inVoicemailInbox = false`, `isSnoozed = false` をセットし、`refreshAllNotifications(in:)` を呼ぶ。
  - スヌーズボタンは、旧 `canScheduleSnooze` ベースではなく、新 `scheduleSnooze(for:in:)` を呼ぶだけの形に変更する。

ToDo 5: スヌーズ UI・埋もれ警告 UI の整理
-------------------------------------
- [ ] `IncomingCallView`:
  - スヌーズボタンの「残り回数（グローバル残枠）」表示を削除する。
  - `canSnooze` / `globalSnoozeRemaining` / `LocalNotificationManager.canScheduleSnooze(...)` 呼び出しを削除。
  - スヌーズボタンは常にタップ可能（必要であれば簡単なガードのみ）とし、押下時に `LocalNotificationManager.scheduleSnooze(for:in:)` を呼ぶ。
- [ ] `PlannedPlaceholderView`:
  - 「スヌーズ中」ラベルの表示条件を、`snoozedIds` セットではなく `entity.isSnoozed` に変更する。
  - `updateMainBaseDate()` 内の `fetchPendingSummary` 依存、および `isHazard(...)` / `mainBaseDate` / 「埋もれ警告」テキストを丸ごと削除。
  - `snoozedIds` は DB の `isSnoozed` をもとに計算するか、必要なければプロパティごと削除。

ToDo 6: テスト・確認シナリオ
-------------------------
- [ ] 単一レコード（N = 1）で、25 回の通知が 7 秒間隔で登録されることを `getPendingNotificationRequests` で確認する。
- [ ] 複数レコード（N = 2, 3, 4, 10 等）で、`perCall` が仕様どおりになり、合計通知数が 64 件以内に収まることを確認する。
- [ ] 応答/拒否/削除/スヌーズ/日時編集の各操作後に、該当レコードへの通知が再計算され、不要な通知が残らないことを確認する。
- [ ] スヌーズボタン押下で `recordedAt` が期待どおり未来にシフトし、リストに「スヌーズ中」ラベルが表示されることを確認する。
- [ ] しばらく放置して通知が鳴り終わったレコードが、自動で `status = "missed"`, `inVoicemailInbox = true` に移行し、留守電タブから再生できることを確認する。
- [ ] N が大きく `perCall` が少ないケースでも、`graceSecondsDynamic` により「最後の通知終了＋猶予時間」後に留守電へ正しく移行することを確認する。

