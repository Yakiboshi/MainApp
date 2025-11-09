通信→録音 実装ToDo（v1）

目的
- docs/specs/tuusin.md の #通信画面 → #録音画面 の最小フローを実装する
  - 画面遷移後に接続音を自動再生し、再生完了で録音画面へ自動遷移
  - 音源ファイル名に依存せず差し替え可能な設計にする

前提 / 使用条件
- SwiftUI を使用する
- 音声再生は AVFoundation の AVAudioPlayer を使用する
- 再生完了検知は AVAudioPlayerDelegate を用いる
- Xcode プロジェクトに mp3 を追加し Target Membership を有効化（ファイル名は可変に対応）
- アプリ起動時に「マイク（音声入力）」と「ローカル通知」の権限を確認し、未許可ならその場で要求する（初回）

作成ファイル
- AudioPlayerViewModel.swift（再生ロジック＋delegate／完了コールバック）
- AudioPlayView.swift（通信画面：再生開始と完了時の自動遷移を管理）
- RecordingView.swift（録音画面：本タスクではスタブ。次タスクで実録音を実装）
- PermissionManager.swift（権限確認・要求のユーティリティ：通知／マイク）

実装ToDo
- [ ] AudioPlayerViewModel
  - [ ] `playSound(fileName:ext:onFinish:)` を実装（存在しない/失敗時は `onFinish` を即時実行）
  - [ ] `AVAudioPlayerDelegate.audioPlayerDidFinishPlaying` で完了をハンドル
  - [ ] 必要に応じ `AVAudioSession` を `.playback` で設定
- [ ] PermissionManager（起動時の権限確認）
  - [ ] ローカル通知: `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])`
  - [ ] マイク: `AVAudioSession.sharedInstance().requestRecordPermission` で録音許可を確認・要求
  - [ ] いずれか拒否時は案内（設定アプリ遷移導線）を返せるインターフェースにする
  - [ ] 初回のみ要求、結果は保持（必要に応じて AppStorage など）
- [ ] AudioPlayView（通信画面）
  - [ ] 受け取り: `scheduledAt: Date`（DESTINATIONTIME）、`soundName: String`（デフォルト例: "callSound"）
  - [ ] `onAppear` で `player.playSound` を開始し、完了クロージャで `RecordingView` へ遷移
  - [ ] UI: 「接続中…」テキスト＋`ProgressView`。コード内コメントで「再生開始/遷移箇所」を明示
  - [ ] 再生失敗時は小さな遅延（例 0.3s）後にフォールバック遷移
- [ ] RecordingView（録音画面・スタブ）
  - [ ] 受け取り: `scheduledAt: Date`
  - [ ] 中央に録音時間プレースホルダ、下部に「録音終了」ボタンを配置（次工程で実装置換）
  - [ ] コードコメントで「自動録音開始/停止/保存」の挿入ポイントを示す
- [ ] 依存リソース
  - [ ] 接続音 mp3 をバンドルへ追加（例: `callSound.mp3`）。後でファイル名を変えても動作すること
  - [ ] Info.plist に `NSMicrophoneUsageDescription` を追加し、ユーザーに目的を明確化

画面間データ受け渡し
- `AudioPlayView(scheduledAt:soundName:)` → 再生完了 → `RecordingView(scheduledAt:)`
- 将来拡張を見据え、`CallContext(scheduledAt: Date)` の導入を検討（任意）

動作確認チェックリスト
- [ ] 通信画面に遷移すると接続音が自動再生される
- [ ] 再生完了で自動的に録音画面に遷移する
- [ ] 音源ファイル名を変更しても再生→遷移が成立する（汎用化）
- [ ] 音源が見つからない/再生失敗時もフォールバック遷移でフローが継続する
- [ ] アプリ起動時に通知・マイクの権限要求が行われる（初回）
- [ ] 通知拒否時: スケジュール時にリマインド表示（設定アプリ誘導）
- [ ] マイク拒否時: 録音画面遷移前/開始前にガイダンス表示（設定アプリ誘導）

補足
- 実録音（自動開始/時間表示/停止/保存/通知予約）は `docs/specs/rokuon.md` を参照し次タスクで実装
- コメント方針: 各ファイルに「再生開始」「完了検知」「遷移」「録音開始予定箇所」を日本語コメントで明示
- 権限UIの文言はプロダクト方針に合わせて簡潔に（例: マイク用途=メッセージ録音、通知用途=擬似着信の通知）
