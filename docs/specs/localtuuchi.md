ローカル通知 仕様（v1）

目的
- 指定日時に擬似着信を発生させ、アプリ内の擬似着信画面へ誘導する。
- 通知音はアプリ同梱のカスタム音源を再生し、気づきを高める。

基本動作
- 予約: `UNCalendarNotificationTrigger` で日時を指定してローカル通知を登録する。
- 通知タップ: アプリ起動（または復帰）後、対象IDをもとに擬似着信画面へ遷移する。
- アクション（将来拡張）: 通知に「応答」「拒否」アクションを付与し、拒否時はスヌーズ再登録、応答時は再生へ遷移する。

サウンド仕様
- 使用音源: `Voice to do App/Audio/KeypadSounds/ks035.wav`（25秒にトリミング）
- 実装: `UNNotificationSound(named: UNNotificationSoundName("ks035.wav"))` を設定。見つからない場合は `.default` にフォールバック。
- 注意: カスタム通知音は30秒以内を推奨。再生不可の端末がある場合は `.caf/.aiff/.wav` への変換を検討。詳細は `docs/specs/localtuuchisound.md` 参照。

ペイロード（userInfo）
- 付与例:
- `"messageId": String`（または `"recordingId"`）
- `"category": "CALL_INCOMING"`
- これにより起動時ルーティング（擬似着信画面へのディープリンク）が可能。

カテゴリ/アクション（オプション）
- Category ID: `CALL_INCOMING`
- Actions:
- `ANSWER_ACTION`（応答）
- `DECLINE_ACTION`（拒否）
- ハンドリング: `UNUserNotificationCenterDelegate` の `didReceive response` で `actionIdentifier` を判定し、応答なら再生画面、拒否ならスヌーズ再登録。

バッジ
- 予約時点ではバッジ変更なし。
- 不達/未応答で留守電受信箱へ入ったタイミングで未読数のバッジを更新（加算/再生で減算）。

タイムゾーン
- DBはUTCで保持し、表示はローカル。ローカル通知登録時はローカルの `Date` を用いる（`UNCalendarNotificationTrigger` はローカル基準）。

権限
- アプリ起動時に通知・マイク権限を確認・要求する（PermissionManager）。
- 拒否時は録音・通知の各UIで再案内と設定アプリ誘導を表示（将来実装）。

実装ToDo
- サウンドアセット
- `Voice to do App/Audio/KeypadSounds/ks035.wav` をアプリターゲットに追加（Target Membership 有効化）。
- 長さ/フォーマットのチェック（30秒以内が目安）。
- 通知カテゴリ登録
- アプリ起動時に `UNNotificationCategory(identifier: "CALL_INCOMING", actions: [...], intentIdentifiers: [], options: [])` を登録。
- スケジュールAPIの整備（NotificationManager）
- `scheduleNotification(for date: Date, messageId: String)` を定義。
- `content.sound = UNNotificationSound(named: ..."ks035.wav")` を設定、`userInfo` に `messageId` を付与。
- `UNCalendarNotificationTrigger` で登録。
- デリゲート/ルーティング
- `UNUserNotificationCenter.current().delegate = ...` を設定（App起動時）。
- `willPresent` でフォアグラウンド受信時の表示ポリシー（banner/sound）を許可。
- `didReceive response` で `messageId` を取得し、擬似着信画面へ遷移。`DECLINE_ACTION` の場合はスヌーズ再登録。
- バッジ連携
- 留守電受信箱投入時に未読数を計算し `applicationIconBadgeNumber` を更新。

テスト観点
- 近未来（1〜2分後）で通知を予約し、以下を確認。
- 通知が時刻どおりに表示される。
- カスタム音 `ks035.wav` が鳴る（無い場合はデフォルト）。
- 通知タップで擬似着信画面へ遷移する（`messageId` の引き回し）。
- （実装時）アクション「拒否」でスヌーズ再登録、「応答」で再生へ遷移。
- 留守電投入でバッジが増え、消化で減る。

補足
- 将来、通知の `userInfo` に `snoozeIntervalMin` などを含め、拒否時スヌーズ処理をシンプルにする。
- iOSの節電/再起動などで通知が遅延する可能性があるため、起動時に未配信を救済し留守電へ振替えるスキャン処理を検討する。
ローカル通知 仕様（v1.1）

目的
- 指定日時に擬似着信を発生させ、アプリ内の擬似着信画面（または再生画面）へ誘導する。
- 通知音としてカスタム音源 `ks035.wav` を再生し、気づきを高める。

サウンド仕様
- 使用音源: `Voice to do App/Audio/KeypadSounds/ks035.wav`
- 実装: `UNNotificationSound(named: UNNotificationSoundName("ks035.wav"))`
- フォールバック: 上記が見つからない場合は `.default`
- 注意: iOS のカスタム通知音は概ね 30 秒以内が推奨。再生不可端末がある場合は `.caf/.aiff/.wav` の検討。

基本フロー
1) 予約: `UNCalendarNotificationTrigger` で日時を指定しローカル通知を登録
2) 受信: 指定時刻にバナー/ロック画面表示（フォアグラウンド時の表示方針は delegate で制御）
3) タップ: アプリ起動/復帰 → `userInfo` の ID を参照して擬似着信画面へディープリンク
4) （将来）アクション: 通知上の「応答」「拒否」アクションにより、再生またはスヌーズ再登録

ペイロード（userInfo）
- 付与キー例:
  - `messageId: String`（または `recordingId`）
  - `category: "CALL_INCOMING"`
- 目的: タップ/アクション時に対象を特定し、アプリ内ルーティングに利用する。

カテゴリ/アクション（拡張用）
- Category ID: `CALL_INCOMING`
- Actions:
  - `ANSWER_ACTION`（応答）
  - `DECLINE_ACTION`（拒否 → スヌーズ再登録）
- 処理: `UNUserNotificationCenterDelegate` の `didReceive response` で `actionIdentifier` を分岐。

バッジ
- 予約時は変更なし。
- 未応答/不達で留守電受信箱に入った時点で未読数をアプリアイコンのバッジに反映。

権限
- アプリ起動時に通知/マイク権限をまとめて要求（既存 `PermissionManager.requestLaunchPermissions()` を使用）。
- 拒否時は録音/通知の各画面で再案内と設定アプリ誘導（将来実装）。

実装 ToDo（このプロジェクトでの具体項目）
- サウンドアセット
  - [ ] `Voice to do App/Audio/KeypadSounds/localsound.mp3` をアプリターゲットに追加（Target Membership 有効化）。
  - [ ] 長さ/フォーマットを確認（≤30 秒目安）。
- NotificationManager 強化
  - [ ] `scheduleNotification(for date: Date, messageId: String?)` に拡張（`userInfo` に ID 付与）。
  - [ ] `content.sound = UNNotificationSound(named: UNNotificationSoundName("localsound.mp3"))` を常時適用（存在確認してフォールバック）。
- カテゴリ/アクション登録（任意）
  - [ ] 起動時に `UNNotificationCategory(identifier: "CALL_INCOMING", actions: [...], intentIdentifiers: [], options: [])` を登録。
- デリゲート/ルーティング
  - [ ] `UNUserNotificationCenter.current().delegate = ...` を `App` 起動時に設定。
  - [ ] `willPresent` でフォアグラウンド受信時の表示形式（banner/sound/badge）を許可。
  - [ ] `didReceive response` で `messageId` を取得し、擬似着信画面へ遷移。`DECLINE_ACTION` はスヌーズ再登録。
- バッジ連携
  - [ ] 留守電受信箱投入/消化に応じて `UIApplication.shared.applicationIconBadgeNumber` を更新。

テスト観点
- [ ] 1〜2 分後の日時で予約し、通知が正時に到達する。
- [ ] `localsound.mp3` が鳴る（無い場合はデフォルト）。
- [ ] 通知タップで擬似着信画面へ遷移（`messageId` 連携）。
- [ ] （実装時）アクション「拒否」でスヌーズ再登録、「応答」で再生へ遷移。
- [ ] 留守電投入でバッジが増え、再生で減る。

補足
- 将来、通知 `userInfo` に `snoozeIntervalMin` などを含め、拒否時スヌーズをシンプルに実装可能。
- 端末の再起動/省電力等により通知が遅延する可能性があるため、起動時に未配信を救済し留守電へ振替えるスキャン処理を検討。

ローカル通知 仕様（v1.2 変更点）

目的
- 指定時刻から20秒おきに連続して計10回通知を発火させる。

実装
- `UNTimeIntervalNotificationTrigger` を用い、基準時刻（指定日時）からの相対時間で 0s/20s/40s/.../180s の10件を個別登録。
- リクエストIDは `"<messageId>_<seq>"` とし、`userInfo` に `messageId`, `category: "CALL_INCOMING"`, `seq` を付与。
- サウンドは常時 `ks035.wav`（存在しない場合は `.default`）。
- 通知タップで擬似着信画面にディープリンク（画面は仮実装）。
