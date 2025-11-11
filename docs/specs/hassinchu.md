## 録音画面 ToDo（.voiceChat 準拠）

完成イメージ: `docs/specs/hassinchuuUI.png`

### 1) 背景/レイアウト
- [ ] 背景は AudioPlayView と同じ黒系グラデーション（全面 `ignoresSafeArea()`）。
- [ ] `GeometryReader` で高さを参照し、要素を比率配置。
- [ ] 上1/3: 経過時間 `MM:SS` を白・大きめ・`.monospacedDigit()` で中央配置。
- [ ] 中央: 実音声連動の波形（白線、スクロール風）。
- [ ] 波形直下: 「残り時間 mm:ss」白テキスト。
- [ ] さらに下（下から1/3付近）: 「入力切替」ボタン（白丸、黒の `waveform.circle`、下に「切り替え」）。
- [ ] 最下部1/6: 丸ボタン3つ（左→右）キャンセル/一時停止or再開/終了 + 各ラベル。

### 2) AudioRecorderViewModel 拡張（機能）
- [ ] セッション: `.playAndRecord` + `mode: .voiceChat`、`options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]`。
- [ ] メータリング: `isMeteringEnabled = true`、50ms タイマーで `averagePower` 取得→0…1 に正規化→簡易スムージング（例: `level = level*0.8 + new*0.2`）。
- [ ] 公開値: `@Published level: Double`、`elapsedSec: Int`、`remainingSec: Int`、`isPaused: Bool`。
- [ ] 上限: `maxDurationSec = 180`（暫定定数）。1秒タイマーで経過/残り更新、満了で自動 `stopRecording()`。
- [ ] 制御: `pause() / resume()`（録音再開に対応）。`cancel()`（停止＋生成ファイル削除＋セッション解除）。
- [ ] 割り込み: `AVAudioSession.interruptionNotification` 監視。`.began` で自動一時停止、`.ended` は `shouldResume` なら自動再開。
- [ ] ルート変化/異常: `routeChange`/`mediaServicesWereReset` 監視。重大時は録音中止（キャンセル同等）。

### 3) 入力切替（Bluetooth対応）
- [ ] `AudioRouteManager` を追加（`availableInputs` 取得、`setPreferredInput(_:)` で切替、`selectedInput` 公開）。
- [ ] RecordingView からボタンタップで `confirmationDialog` を提示し、選択で即切替。
- [ ] 画面に「現在の入力: xxx」を白テキストで表示。

### 4) 波形ビュー（軽量）
- [ ] `Canvas` または `Shape` + リングバッファ（120〜180サンプル）で水平方向に流れる線を描画。
- [ ] `level` をもとに中心を基点とした上下対称の白線を更新、アニメは `.linear(duration: 0.05)`。

### 5) UIアクション/保存フロー（ID命名）
- [ ] キャンセル: `recorder.cancel()` → 画面を閉じる。
- [ ] 一時停止/再開: `recorder.pause()/resume()`、中央ボタンのアイコン（`pause.fill`/`play.fill`）とラベル切替。
- [ ] 終了: `stopRecording()` → `RecordingEntity` を作成 → ファイルを `entity.id.uuidString + ".m4a"` にリネーム → 通知登録 → `NotificationRouter.presentIntermediate(entity.id)` → 閉じる。

### 6) アクセシビリティ/仕上げ
- [ ] 各ボタンにラベル（キャンセル/一時停止/再開/終了/入力切替）。
- [ ] セーフエリア・ホームインジケータ考慮（下部に十分な余白）。
- [ ] 押下時の軽い縮小アニメ/影、触覚フィードバック（任意）。

### Definition of Done
- [ ] 実機で Bluetooth ヘッドセット接続時に「入力切替」で選択・切替ができる。
- [ ] `.voiceChat` で録音・一時停止・自動一時停止（着信などの割り込み）・復帰が動作する。
- [ ] 上限時間で自動停止→保存→ID命名→中間画面へ遷移。
- [ ] UIが `hassinchuuUI.png` と概ね一致し、数値表示・波形・ボタン位置が指定比率どおり。

