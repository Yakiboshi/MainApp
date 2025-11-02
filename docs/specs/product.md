# プロジェクトの概要
未来の自分へ、まるで電話がかかってくるようにボイスメッセージを届けるアプリ。中央の“発信”ボタンから未来の日時を設定し、接続音のあとに録音。指定日時になると通知→アプリ内で擬似着信画面を表示し、再生できる。

本ドキュメントは、画面一覧、主要フロー、情報設計、データモデル（SwiftData）、通知・録音の技術方針、開発スコープをまとめる。

---

## 変更点サマリ（本更新で反映）
- 擬似着信画面は「応答」と「拒否」の2ボタンのみ
- 拒否時は録音プレビューで事前設定したスヌーズ時間でローカル通知を自動再登録
- 不達（未応答/タイムアウト）時は「留守電リスト」に入り、1回再生で留守電リストから消え履歴へ移動
- 留守電がある場合はアプリアイコンに留守電数のバッジを表示
- ホーム下部に5ボタン: 設定 / 履歴リスト / ホーム / 着信予定リスト（編集） / 留守電リスト
- 履歴リストは削除可能。ブックマークで消えないように固定可能
- 未来日時入力のクイックリスト/DatePickerはキーパッド「0の左のボタン」押下時のみ小ウィンドウで表示
- 録音プレビューで設定: タイトル（未入力時は「（日時）への電話」）、アフターメッセージ、スヌーズ時間（デフォ10分）
- 録音上限はデフォ3分。アプリ設定で変更可能
- データベースは SwiftData を使用

---

## 主要ユーザー体験（フロー）
- 新規作成: ホーム → 中央ボタン → キーパッドで日時設定 → 「発信」 → 接続音 → 自動録音開始 → 停止 → プレビュー（タイトル/アフターメッセージ/スヌーズ設定）→ 保存（スケジュール確定）
- 着信→再生: 指定日時にローカル通知 → 通知タップ → 擬似着信画面 → 応答 → 再生 → 完了（履歴へ）
- 着信→拒否: 擬似着信画面で「拒否」 → そのメッセージのスヌーズ時間で自動的にローカル通知を再登録
- 不達→留守電: 指定時刻から一定時間応答が無い（アプリ未起動/タイムアウト）→ 留守電リストに登録・バッジ加算 → ホーム下部の留守電ボタンからリストへ → 1回再生でリストから消え履歴へ移動
- 履歴整理: 履歴リストで削除/一括整理。ブックマークした項目は保持
- 編集/削除: 着信予定リストから日時やタイトルを編集/削除

---

## 画面一覧
- ホーム: 中央の新規“発信”ボタン、次の予定、最近の履歴ダイジェスト。画面下部に5ボタン（設定/履歴/ホーム/着信予定/留守電）
- 未来日時入力（キーパッド）: 電話キーパッド風。0の左の補助ボタンで小ウィンドウ（クイック/DatePicker）
- 録音（接続中→録音中）: 接続音→録音、波形、残り時間、停止
- 録音プレビュー: 再生、タイトル、アフターメッセージ、スヌーズ時間（デフォ10分）、再録音、保存
- 着信予定リスト（編集）: 今後の“着信”予定一覧、編集/削除/並び替え
- 擬似着信: フルスクリーン風、2ボタン（応答/拒否）のみ
- 再生: 大きめプレイヤー、完了、共有（任意）
- 留守電リスト: 不達や未応答のメッセージ一覧。1回再生で履歴へ移動。バッジ連動
- 履歴リスト: 過去の着信履歴。削除/一括整理、ブックマークで保持
- 設定: 通知/マイク許可、効果音、スヌーズ既定、録音上限（デフォ3分）、アイコンバッジ、バックアップ等
- オンボーディング/許可誘導: 初回の説明→通知/マイク権限
- エラー/権限画面: 許可未取得、保存失敗、ストレージ不足 など

---

## 画面詳細（主要UI要素）

### ホーム
- 中央ボタン（新規“発信”）
- 次の予定1件（日時・タイトル・簡易操作）
- 最近の履歴数件（再生/共有）
- 画面下部の5ボタン（左→右）
  - 設定
  - 履歴リスト
  - ホーム
  - 着信予定リスト（編集）
  - 留守電リスト（未読数バッジ）

### 未来日時入力（キーパッド）
- 3×4 キーパッド（0-9、削除、OK）
- 「0の左のボタン」（補助ボタン）: 押下時のみ小ウィンドウで以下を表示
  - クイック: +10分 / +1時間 / 今夜 / 明朝 / 週末
  - DatePicker（システムコンポーネント）
- 入力フォーマット: YYYY/MM/DD HH:MM（自動フォーマット/プレースホルダ）
- バリデーション: 過去不可、最小間隔、上限期間

### 録音（接続中→録音中）
- 接続音（ミュート設定可）→ 録音自動開始
- 波形、経過/残り、ミュート/一時停止、停止
- 上限時間: デフォ3分（設定で変更可）

### 録音プレビュー（詳細設定）
- 再生シーク、再録音、保存（スケジュール確定）
- 設定できる項目（任意）
  - タイトル（未入力時は「（日時）への電話」を自動設定）
  - アフターメッセージ（応答直後に画面表示する短文）
  - スヌーズ時間（デフォ10分。拒否時や明示スヌーズに利用）

### 着信予定リスト（編集）
- セル: タイトル、予定日時、残り時間、クイック操作（編集/削除）
- 並び替え/フィルタ（今日/今週/すべて）

### 擬似着信
- フルスクリーン風: アイコン、タイトル、予定時刻
- ボタン: 応答 / 拒否（2ボタンのみ）
- 拒否動作: 対象メッセージのスヌーズ時間でローカル通知を自動再登録

### 再生
- 大きめコントロール、完了、共有
- 応答後に「アフターメッセージ」を画面表示（数秒のトースト/モーダル）

### 留守電リスト
- 不達/未応答（タイムアウト）で入る受信箱
- 1回再生で留守電リストから削除し、履歴へ移動
- 未読数をアプリアイコンのバッジに反映

### 履歴リスト
- 過去の着信履歴。削除/一括整理が可能
- ブックマーク（固定）で整理対象から除外

### 設定
- 権限（通知/マイク）状況、効果音 ON/OFF
- スヌーズ既定（デフォ10分）、録音上限（デフォ3分）
- アイコンバッジ ON/OFF
- バックアップ（ローカル出力）

---

## 情報設計（IA/ナビゲーション）
- 下部5ボタンの固定ナビ: 設定 / 履歴 / ホーム / 着信予定 / 留守電
- 中央FAB（またはホーム中央ボタン）で新規作成
- ディープリンク: 通知 → 擬似着信画面（messageId 指定）
- アクセシビリティ: キーパッド補助ボタンで DatePicker、VoiceOver 対応

---

## 状態遷移（メッセージ）
- Draft（作成中）→ Recording（録音中）→ Preview（確認中）→ Scheduled（予約済）
- Triggered（通知発火）→ Ringing（擬似着信表示）→
  - 応答: Playing（再生中）→ Played（再生済）
  - 拒否: Snoozed（再通知待ち）
  - タイムアウト: VoicemailInbox（留守電受信箱）
- VoicemailInbox（未読）→ Played（再生済・履歴へ）

---

## データモデル（SwiftData）
ローカルデータベースには SwiftData を用いる。音声はアプリサンドボックスに保存し、SwiftData はメタデータ/通知/受信箱状態を管理する。

### ストレージ
- 音声: m4a (AAC) 48kHz（ファイル名は `Message.id.m4a` を推奨）
- DB: SwiftData（代表インデックス: `scheduledAt`, `status`, `inVoicemailInbox`）

### モデル定義例
```swift
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: String
    var title: String
    var note: String?
    var afterMessage: String? // 応答直後に表示する短文
    var scheduledAt: Date
    var createdAt: Date
    var updatedAt: Date
    var status: Status
    var durationSec: Int?
    var filePath: String // 相対パス推奨（App Sandbox 内）
    var waveformThumb: Data?
    var notificationId: String?
    var snoozeIntervalMin: Int // デフォルト 10 分
    var tags: [String]
    var timezoneIdentifier: String
    var inVoicemailInbox: Bool // 留守電受信箱に入っているか
    var isBookmarked: Bool // 履歴固定

    init(
        id: String = UUID().uuidString,
        title: String,
        note: String? = nil,
        afterMessage: String? = nil,
        scheduledAt: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        status: Status = .scheduled,
        durationSec: Int? = nil,
        filePath: String,
        waveformThumb: Data? = nil,
        notificationId: String? = nil,
        snoozeIntervalMin: Int = 10,
        tags: [String] = [],
        timezoneIdentifier: String = TimeZone.current.identifier,
        inVoicemailInbox: Bool = false,
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.afterMessage = afterMessage
        self.scheduledAt = scheduledAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.durationSec = durationSec
        self.filePath = filePath
        self.waveformThumb = waveformThumb
        self.notificationId = notificationId
        self.snoozeIntervalMin = snoozeIntervalMin
        self.tags = tags
        self.timezoneIdentifier = timezoneIdentifier
        self.inVoicemailInbox = inVoicemailInbox
        self.isBookmarked = isBookmarked
    }
}

enum Status: String, Codable, CaseIterable {
    case draft
    case recording
    case preview
    case scheduled
    case triggered
    case ringing
    case playing
    case snoozed
    case voicemailInbox
    case played
    case archived
}

@Model
final class AppSettings {
    var recordMaxSec: Int // デフォルト 180 (= 3分)
    var defaultSnoozeMin: Int // デフォルト 10
    var soundsEnabled: Bool
    var badgeEnabled: Bool // アプリアイコンのバッジ

    init(
        recordMaxSec: Int = 180,
        defaultSnoozeMin: Int = 10,
        soundsEnabled: Bool = true,
        badgeEnabled: Bool = true
    ) {
        self.recordMaxSec = recordMaxSec
        self.defaultSnoozeMin = defaultSnoozeMin
        self.soundsEnabled = soundsEnabled
        self.badgeEnabled = badgeEnabled
    }
}
```

---

## 通知/擬似着信の実装方針（iOS）
- ローカル通知: `UNCalendarNotificationTrigger` で予約（`content.userInfo["messageId"]` を付与）
- 通知タップ: ディープリンクで擬似着信画面へ遷移
- 擬似着信UI: 2ボタンのみ（応答/拒否）
  - 応答: プレイヤーへ遷移、`afterMessage` を再生開始時に画面表示
  - 拒否: `snoozeIntervalMin` 分後に再通知を登録（既存通知をキャンセルし再登録）
- タイムアウト（未応答/不達）: `inVoicemailInbox = true` にして受信箱へ。バッジを未読数に更新
- バッジ: 新規留守電追加で加算、留守電を再生・消化で減算（`UIApplication.shared.applicationIconBadgeNumber` または通知 `badge`）
- タイムゾーン: DB は UTC ベース保持、表示はローカル
- 端末 OFF/低電力: 起動時に未配信メッセージを走査し留守電へ振替・救済通知

---

## 権限/オンボーディング
- 初回: コンセプト → 通知許可 → マイク許可（用途説明付）
- 許可拒否時: iOS 設定アプリへの導線と「あとで」
- 再要求: 録音開始前/予約前など必要時のみ丁寧に再ガイダンス

---

## バリデーション/エラー設計
- 日時入力: 過去不可、上限（例: 1年）
- 録音: 権限なし/ストレージ不足/上限超過（録音停止）。上限はデフォ3分、設定で変更
- 通知: 許可なし/上限数超過 → 直近のみ保持 or 整理を促す
- 再生: ファイル欠損 → 復旧案内（バックアップから復元/無効化）

---

## 非機能要件
- オフライン完結（必須機能はネット不要）
- アプリサイズ/起動速度/電池配慮（バックグラウンド常駐なし）
- プライバシー: ローカル保存既定、外部送信なし。共有時のみユーザ操作でエクスポート
- セキュリティ: アプリロック（Face ID/Passcode）、バックアップ暗号化オプション

---

## 技術スタック
- iOS（MVP 対象）: SwiftUI + AVFoundation + UserNotifications + SwiftData
- 将来拡張（任意）: 文字起こし（Speech）、ウィジェット、Siri/ショートカット

---

## 開発スコープ（MVP → 拡張）
### MVP
- 未来日時入力（キーパッド＋補助ボタンの小ウィンドウ: クイック/DatePicker）
- 接続音 → 録音（3分デフォ） → プレビュー（タイトル/アフターメッセージ/スヌーズ）→ 保存（SwiftData 登録）
- ローカル通知 → 通知タップ → 擬似着信（応答/拒否）
- 拒否時の自動スヌーズ再登録
- 不達→留守電リスト投入、バッジ加算、1回再生で履歴へ
- 下部5ボタンナビ（設定/履歴/ホーム/着信予定/留守電）

### 次段
- タグ/検索、共有、バックアップ（iCloud Drive 等へのエクスポート）、アプリロック、細かな自動整理ルール

### 将来
- 文字起こし、スマート提案（クイック日時候補）、ウィジェット、Siri/ショートカット連携

---

## 補足（キーパッド補助ボタンの挙動）
- 位置: 数字「0」の左のボタン
- 押下時のみ小ウィンドウをポップ表示し、クイック設定と DatePicker を提示
- 小ウィンドウ外タップや OK で閉じる。アクセシビリティ向けに VoiceOver ヒントを付与

---

## 確認事項（現状確定）
- 擬似着信は通知→アプリ内全画面で表現（OK）
- 録音上限はデフォ3分、設定で変更可（OK）
- ローカル完結型（OK）
