ローカル通知サウンド設計（v1）

目的
- 拡張子の互換性問題を回避し、確実に鳴るローカル通知サウンドを提供する。
- 将来はユーザーが内蔵サウンドから選択できるよう拡張（任意）。

前提と制約（iOS）
- カスタム通知音はアプリのバンドル内に配置され、長さはおおむね30秒以下である必要がある。
- ランタイムでユーザーが任意ファイルを通知音として登録することはできない（バンドル外は不可）。
- フォアグラウンド受信時のサウンドは `UNUserNotificationCenterDelegate.willPresent` で許可が必要。

現行仕様（このプロジェクト）
- 使用音源: `Voice to do App/Audio/KeypadSounds/ks035.wav`
- 長さ: 25秒（30秒以下の推奨値に収める）。長い場合は OS 側でデフォルトにフォールバックするため、事前にトリミングしてバンドルへ。
- 実装: `UNNotificationSound(named: UNNotificationSoundName("ks035.wav"))`
- フォールバック: ファイルが無い、または30秒超の場合は `.default` を適用。

実装詳細
- NotificationManager から集中管理のサウンド取得関数を呼び出す。
  - `NotificationSoundProvider.currentNotificationSoundName() -> String?`
  - バンドル存在と長さ(≤30s)を検証し、`"ks035.wav"` を返す。条件を満たさなければ `nil` を返し `.default` を採用。
- 受信時表示: フォアグラウンドでも `[.banner, .list, .sound]` を返してサウンドを許可。

将来拡張（設計）
- 内蔵サウンドの選択
  - 設定画面で「内蔵サウンド」一覧から選択（例: `ks035.wav`, `bell.caf`, `tone.aiff`）。
  - 選択結果は UserDefaults または SwiftData（AppSettings）へ保存。
  - `NotificationSoundProvider` が選択結果を参照して返却。
- ユーザー音源の扱い
  - iOSの制約上、OSの通知音として任意ファイルを即時採用できない。
  - 将来は「擬似着信画面（アプリ内）」の着信音には任意ファイルを再生可能（アプリ前景・復帰後）。
  - OS通知の音は「内蔵（バンドル）サウンド」の範囲で選択式とする。

テスト観点
- 1〜2分後でスケジュールし、通知が到達し音が鳴ること。
- ファイルを30秒超に差し替えた場合は `.default` にフォールバックすること。
- フォアグラウンドでもバナー＋音が鳴ること（delegate 有効）。

関連ファイル
- `Voice to do App/NotificationManager.swift`
- `Voice to do App/NotificationSoundProvider.swift`
- `Voice to do App/NotificationCenterDelegate.swift`
