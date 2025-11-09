録音＋ローカル通知 実装ToDo（起動時に権限取得）

目的
- 通信画面から遷移後、録音を自動開始し、停止で保存＋指定日時にローカル通知を登録する。
- 権限（マイク・ローカル通知）は「アプリ起動時」に確認・要求する（未許可時は起動直後にリクエスト）。

前提 / ポリシー
- UI: SwiftUI、永続化: SwiftData、録音: AVAudioRecorder、通知: UserNotifications。
- 録音ファイルはアプリ Documents 配下に .m4a（AAC）で保存。
- 通知サウンドは `localsound.mp3` があれば使用（無ければ .default）。
- 既存の `PermissionManager` を使用し、起動時に通知・マイク権限をまとめて要求する。

作成/更新ファイル
- RecordingEntity.swift（SwiftData モデル: 録音のメタ情報を保存）
- AudioRecorderViewModel.swift（録音開始/停止の管理とAVAudioSession設定）
- NotificationManager.swift（通知作成；PermissionManagerと責務分離）
- RecordingView.swift（録音画面。自動録音開始→停止→保存→通知）
- AudioPlayView.swift（録音画面への引き渡しを `RecordingView(date:)` に統一）
- Voice_to_do_AppApp.swift（`.modelContainer(for:)` に RecordingEntity を追加）
- Info.plist（`NSMicrophoneUsageDescription` を追加）

実装ToDo
- [ ] 権限（起動時）
  - [ ] `ContentView` 起動時に `PermissionManager.requestLaunchPermissions()` を呼ぶ（通知・マイク）。
  - [ ] 拒否時のUI指針: 録音画面入場時にガイダンスと設定アプリ誘導を表示（実装は任意）。
- [ ] モデル（SwiftData）
  - [ ] `RecordingEntity` を定義
    - [ ] `id: UUID`、`recordedAt: Date`、`fileName: String`、`duration: Double`
  - [ ] `.modelContainer(for: [既存, RecordingEntity.self])` に更新
- [ ] 録音VM
  - [ ] `AudioRecorderViewModel` を実装
    - [ ] `startRecording(for date: Date)`
      - [ ] Documents配下に `recording_<epoch>.m4a` を作成
      - [ ] `AVAudioSession` を `.playAndRecord` で有効化（終了時に解除）
      - [ ] AAC/44.1kHz/2ch/High で `AVAudioRecorder` を `.record()`
      - [ ] `@Published isRecording = true`、開始時刻保持
    - [ ] `stopRecording() -> (fileName: String, duration: Double)?`
      - [ ] `.stop()`、経過秒を算出、ファイル名返却
      - [ ] 後片付け（セッション状態の整理）
- [ ] 通知管理
  - [ ] `NotificationManager.scheduleNotification(for:)`
    - [ ] `UNCalendarNotificationTrigger` を作成
    - [ ] サウンド: `UNNotificationSound(named: "localsound.mp3")` があれば使用、無ければ `.default`
    - [ ] `userInfo["recordingId"]` などを付与できる拡張性（任意）
- [ ] 録音画面
  - [ ] `RecordingView(date: Date)` に統一（`scheduledDate` → `date`）
  - [ ] `onAppear` で `recorder.startRecording(for: date)` を呼ぶ
  - [ ] 画面下部「録音終了」ボタンで
    - [ ] `stopRecording()` → `RecordingEntity` 作成・保存 → `NotificationManager.scheduleNotification(for: date)` → 画面を閉じる
  - [ ] 状態表示（録音中/停止中）と簡易の経過時間（任意）
- [ ] AudioPlayView 連携
  - [ ] 再生完了で `RecordingView(date:)` に切替（現状のフルスクリーン遷移は維持）
- [ ] 依存リソース/設定
  - [ ] `localsound.mp3` をバンドルに追加（任意。無ければデフォルト音）
  - [ ] Info.plist に `NSMicrophoneUsageDescription` を追加

動作確認チェックリスト
- [ ] アプリ起動時に通知・マイク権限を要求（初回のみ）
- [ ] 通信→録音遷移で自動的に録音が開始される
- [ ] 「録音終了」でファイルが Documents に保存される（.m4a）
- [ ] `RecordingEntity` が SwiftData に保存される
- [ ] 予定日時にローカル通知が発火する（任意サウンド設定も確認）
- [ ] 権限拒否時に適切なガイダンスが表示される（任意）

メモ/考慮事項
- 既存のキー音などは `.ambient`、録音は `.playAndRecord` とカテゴリ差があるため、切替タイミングで競合しないようにする。
- 通知音にカスタム音を使う場合、ファイル長やフォーマットの制約に注意（30秒以内など）。
- 将来：録音メタと予定日時を紐付ける識別子（`recordingId`）を通知 userInfo に載せ、ディープリンクで着信画面を開く拡張が可能。
