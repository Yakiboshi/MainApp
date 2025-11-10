ナビ第二段（予定→履歴→留守電）実装に向けたToDo一覧です。キーパッド画面のUIには一切変更を加えません。

【前提・共通ルール】
- NavigationStackとTabViewが競合しない構造にする（各画面はNavigationStack直下に、全面TabView(.page)を配置）。
- 画面上部に`safeAreaInset(.top)`でスペースを確保（検索バー/並び替えボタンの置き場・UIのみ。機能は後で導入）。
- 3画面（予定/履歴/留守電）はSwiftDataの一覧を「ナビ上の全領域」に表示。
- 削除はスワイプで実装。DB削除に加え、Documents内の音声ファイルも削除する。
- 履歴への反映タイミングは「通話開始時（着信画面の応答ボタン押下時）」とする（通話終了時ではない）。
- 留守電から遷移して着信画面で「拒否」した場合は、スヌーズのローカル通知を再登録しない。
- SwiftDataモデルは破壊的変更を避け、後から拡張しやすい形にする。

【モデル拡張（最小）】
- `RecordingEntity` に以下を追加（既存参照先に影響しないようデフォルト値/オプショナルで導入）
  - `status: String` 例: "scheduled" | "answered" | "missed"（既定: "scheduled"）
  - `answeredAt: Date?`（応答時刻）
  - `inVoicemailInbox: Bool`（留守電受信箱に入っているか、既定: false）
- 予定日時は当面 `recordedAt` を流用（名称変更はせず、将来的に `scheduledAt` 追加で置換可能な設計）。

【導入順1: 予定（Planned）】
- 一覧UI
  - `PlannedPlaceholderView` を実装：`NavigationStack` 配下に上部インセット（検索/並び替え置き場・UIのみ）＋ 全面 `TabView(style: .page)`（当面1ページ）＋ 中に `List`。
  - フェッチ条件：`status == "scheduled"` かつ `recordedAt > now` を基本に抽出。
- セル操作
  - タップで編集画面 `PlannedDetailView` へ遷移（タイトル/アフターメッセージ/スヌーズ/必要なら日時の編集）。
  - 画面下部に「完了」「キャンセル」。完了で保存し閉じる、キャンセルは変更破棄で閉じる。
  - スワイプ削除：DB削除＋Documents内の音声ファイル削除＋（可能であれば）該当メッセージIDの通知取消。

【導入順2: 履歴（History）】
- 一覧UI
  - `HistoryPlaceholderView` を実装：構造は予定と同様。フェッチは `status == "answered"`、並びは `answeredAt` の新しい順。
- セル操作
  - タップで`HistoryDetailView`へ（当面はタイトルのみ表示、閲覧専用）。
  - スワイプ削除：DB削除＋音声ファイル削除。
- 反映タイミング
  - 着信画面の「応答」ボタン押下時に即座に `status = "answered"`, `answeredAt = now`, `inVoicemailInbox = false` を更新（履歴へ反映）。

【導入順3: 留守電（Voicemail）】
- 一覧UI
  - `VoicemailPlaceholderView` を実装：構造は予定と同様。フェッチは `status == "missed"` または `inVoicemailInbox == true` を対象。
- セル操作（タップ）
  - 対象メッセージの擬似着信画面へ遷移できるようにする（`IncomingCallView` へ、留守電起点であることを渡す）。
  - 留守電起点で「応答」→ 即時に `status = "answered"`, `answeredAt = now`, `inVoicemailInbox = false` を更新し履歴へ反映。
  - 留守電起点で「拒否」→ スヌーズのローカル通知は再登録しない。
- セル操作（スワイプ）
  - そのまま履歴へ移行（アーカイブ扱い）：`status = "answered"`, `answeredAt = now`, `inVoicemailInbox = false` に更新。

【通話フロー連携（変更点）】
- `IncomingCallView`
  - 応答ボタン押下時に即時で履歴反映（上記の状態更新を実施）→ その後 `CallConversationView` へ遷移。
  - 留守電起点フラグを受け取り、拒否時にスヌーズ再登録をスキップ。
- `NotificationRouter`
  - 必要に応じて「留守電起点」フラグを保持/伝播できるプロパティを追加。

【後追い（このToDo後に導入）】
- 検索バー・並び替えボタンの実装（UIは今回で土台のみ）。
- 予定編集で日時を変更した際の「通知の再スケジュール」。
- 履歴/留守電のセルデザイン強化（アイコン/日時/バッジなど）。

以上を順に実装します。キーパッド画面のUIは変更しません。
