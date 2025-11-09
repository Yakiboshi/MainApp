ローカル通知 仕様（v1）

目的
- 指定日時に擬似着信を発生させ、アプリ内の擬似着信画面へ誘導する。
- 通知音はアプリ同梱のカスタム音源を再生し、気づきを高める。

基本動作
- 予約: `UNCalendarNotificationTrigger` で日時を指定してローカル通知を登録する。
- 通知タップ: アプリ起動（または復帰）後、対象IDをもとに擬似着信画面へ遷移する。
- アクション（将来拡張）: 通知に「応答」「拒否」アクションを付与し、拒否時はスヌーズ再登録、応答時は再生へ遷移する。

サウンド仕様
- 使用音源: `Voice to do App/Audio/KeypadSounds/localsound.mp3` を通知サウンドとして使用する。
- 実装: `UNNotificationSound(named: UNNotificationSoundName("localsound.mp3"))` を設定。見つからない場合は `.default` にフォールバック。
- 注意: カスタム通知音は30秒以内を推奨。再生不可の端末がある場合は `.caf/.aiff/.wav` への変換を検討。

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
- `Voice to do App/Audio/KeypadSounds/localsound.mp3` をアプリターゲットに追加（Target Membership 有効化）。
- 長さ/フォーマットのチェック（30秒以内が目安）。
- 通知カテゴリ登録
- アプリ起動時に `UNNotificationCategory(identifier: "CALL_INCOMING", actions: [...], intentIdentifiers: [], options: [])` を登録。
- スケジュールAPIの整備（NotificationManager）
- `scheduleNotification(for date: Date, messageId: String)` を定義。
- `content.sound = UNNotificationSound(named: ..."localsound.mp3")` を設定、`userInfo` に `messageId` を付与。
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
- カスタム音 `localsound.mp3` が鳴る（無い場合はデフォルト）。
- 通知タップで擬似着信画面へ遷移する（`messageId` の引き回し）。
- （実装時）アクション「拒否」でスヌーズ再登録、「応答」で再生へ遷移。
- 留守電投入でバッジが増え、消化で減る。

補足
- 将来、通知の `userInfo` に `snoozeIntervalMin` などを含め、拒否時スヌーズ処理をシンプルにする。
- iOSの節電/再起動などで通知が遅延する可能性があるため、起動時に未配信を救済し留守電へ振替えるスキャン処理を検討する。
