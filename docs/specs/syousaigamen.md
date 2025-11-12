SwiftUIで作成している録音通知アプリの「詳細登録画面」を完成させたいです。
下記の仕様に沿ってSwiftUIコードを生成してください。
データはSwiftDataで保存されています。

 UI仕様

画面全体はスクロール可能（ScrollView）

画面上部に円形アイコン（SwiftyCrop使用予定）
　- 写真ライブラリまたは撮影した画像をトリミングして登録

音声プレビュー：再生/停止ボタン＋スライダー＋再生時間表示

タイトル入力欄（空白時は薄い文字で「録音を終了した時刻(発信日時)からの連絡」を表示）

アフターメモ入力欄（文字数カウント表示、最大140字）

スヌーズ時間入力欄（数値で分を設定）

URL入力欄（任意入力・https://で始まらない場合は赤文字でエラーメッセージを表示）
　- URLが有効ならSwiftDataに保存
　- 開く時はGoogle Chrome優先（インストール時）／なければSafariで開く

ToDoタスク入力欄：
　- 最初は「＋タスクを追加」ボタンのみ表示（破線枠内にプラスアイコンと文字）
　- 押すと新しいタスク欄を追加
　- 各タスクに文字数制限 120字
　- 右に削除ボタン（赤いゴミ箱アイコン）

タスクが1件以上あるときのみ「全タスクの締切設定」を表示
　- モード切替（時間・分後／日後）可能
　- Stepperで時間・分・日を設定
　- 全削除で締切設定を自動で無効化し非表示

画面下部に固定バー（スクロールに影響されない）
　- フェードアウトする黒背景
　- ボタンを横並びに3つ配置
　　1️⃣ 左：赤×白バツマーク（キャンセル）→該当録音データ削除＋キーパッド画面へ戻る
　　2️⃣ 中：白×黒の戻るマーク（撮り直し）→録音データ削除＋録音画面へ戻る
　　3️⃣ 右：黄緑×白チェック（確定）→入力データをSwiftDataへ保存して次の画面へ遷移(予定画面)

 機能要件

URL欄でhttps://以外の入力時：
　→ テキストフィールド下に赤文字で「URLは https:// で始めてください」を表示
　→ 不正URLは保存時に破棄

ToDo欄：1タスクあたり120字を超えたら自動で入力制限

SwiftDataで管理しているデータモデル(参考)：

@Model
final class ReminderRecording {
    var createdAt: Date
    var audioFilePath: String?
    var title: String
    var afterMemo: String
    var snoozeMinutes: Int
    var linkURLString: String?
    var iconImageData: Data?
    @Relationship(deleteRule: .cascade) var tasks: [ReminderTask]
    var deadlineHours: Int?
    var deadlineMinutes: Int?
    var deadlineDays: Int?
}

@Model
final class ReminderTask {
    var text: String
    var isDone: Bool
}

 表示デザイン

背景：キーパッド画面と同じ背景

各セクション見出しは白

枠線・テキストボックスは角丸8pt程度

「＋タスクを追加」ボタンは破線枠＋プラスアイコン

下部ボタンはそれぞれ丸ボタン64×64pt、アイコン中央、下に白文字ラベル

 動作面

スクロール末尾が下部フェード背景に隠れないよう、Spacer(height: actionBarHeight) を挿入

保存時：タイトルが空なら「(録音時刻)からの連絡」を自動設定

削除系ボタン押下時：SwiftDataから該当データを削除

 出力形式

SwiftUI + SwiftData対応コード

Xcode15以降でビルド可能

コメント付き・構造化（セクションごとに // MARK: コメント）

Chlomeを開く為、Info.plistに該当する部分に、

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlechrome</string>
</array>

を追加

以下サンプルコード（サンプルコードでは一つにまとめて制作しているが、ファイルを分けれるところは分けてもOK）

import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI

// MARK: - SwiftData Models
@Model
final class ReminderRecording {
    // 既存の録音データに合わせて必要なら項目追加してください
    var createdAt: Date
    var audioFilePath: String? // 端末内パス or FileManager保存先
    var title: String
    var afterMemo: String
    var snoozeMinutes: Int
    var linkURLString: String?      // 任意（httpsのみ許可）
    var iconImageData: Data?        // 円形アイコン（JPEG/PNG）
    @Relationship(deleteRule: .cascade) var tasks: [ReminderTask]

    // タスク締切（相対指定）
    var deadlineHours: Int?         // 「〜時間〜分後」用
    var deadlineMinutes: Int?
    var deadlineDays: Int?          // 「〜日後」用（どちらか片方の概念を使う）
    
    init(createdAt: Date = Date(),
         audioFilePath: String? = nil,
         title: String = "",
         afterMemo: String = "",
         snoozeMinutes: Int = 5,
         linkURLString: String? = nil,
         iconImageData: Data? = nil,
         tasks: [ReminderTask] = [],
         deadlineHours: Int? = nil,
         deadlineMinutes: Int? = nil,
         deadlineDays: Int? = nil) {
        self.createdAt = createdAt
        self.audioFilePath = audioFilePath
        self.title = title
        self.afterMemo = afterMemo
        self.snoozeMinutes = snoozeMinutes
        self.linkURLString = linkURLString
        self.iconImageData = iconImageData
        self.tasks = tasks
        self.deadlineHours = deadlineHours
        self.deadlineMinutes = deadlineMinutes
        self.deadlineDays = deadlineDays
    }
}

@Model
final class ReminderTask {
    var text: String
    var isDone: Bool
    init(text: String = "", isDone: Bool = false) {
        self.text = text
        self.isDone = isDone
    }
}

// MARK: - Main Detail Edit View
struct DetailEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var recording: ReminderRecording  // 呼び出し側から注入（編集画面）
    
    // 音声再生
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0 // 0...1
    @State private var timer: Timer?
    
    // アイコン画像（SwiftyCrop + Photos）
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showCropper = false // ← SwiftyCrop を出すトグル
    
    // URL 入力バリデーション
    @State private var linkInput: String = ""
    @State private var linkIsValidHTTPS: Bool = true
    
    // タスク UI
    enum DeadlineMode: String, CaseIterable { case hoursMinutes = "時間・分後", days = "日後" }
    @State private var deadlineMode: DeadlineMode = .hoursMinutes
    
    // 下部アクションバー高さ（スクロールボトム余白に使用）
    private let actionBarHeight: CGFloat = 120
    
    // タイトル/メモの文字数制限（画像に合わせて）
    private let titleLimit = 30
    private let memoLimit = 140
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - 円形アイコン（SwiftyCrop）
                    VStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            if let data = recording.iconImageData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 110, height: 110)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button {
                                showPhotoPicker = true
                            } label: {
                                Image(systemName: "arrow.2.circlepath.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                                    .offset(x: 40, y: 40)
                            }
                            .accessibilityLabel("アイコンを変更")
                        }
                        Text("アイコン（写真ライブラリ/撮影→トリミング）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                    .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
                    .onChange(of: pickedItem) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let ui = UIImage(data: data) {
                                pickedImage = ui
                                showCropper = true
                            }
                        }
                    }
                    // ↓ SwiftyCrop をシートで表示（実際のAPI名に合わせて置き換えてください）
                    .sheet(isPresented: $showCropper) {
                        // 例: SwiftyCropView(image: pickedImage, shape: .circle) { cropped in
                        //     if let png = cropped.pngData() {
                        //         recording.iconImageData = png
                        //     }
                        // }
                        // 一旦簡易クロップ（中央を正方形で切り出し）
                        if let img = pickedImage {
                            SimpleSquareCropper(image: img) { out in
                                if let out, let data = out.pngData() {
                                    recording.iconImageData = data
                                }
                                showCropper = false
                            }
                        }
                    }
                    
                    // MARK: - 音声プレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Text("プレビュー").font(.headline)
                        
                        HStack(spacing: 12) {
                            Button {
                                togglePlay()
                            } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(Circle().fill(Color.accentColor))
                            }
                            Slider(value: $progress, in: 0...1) { editing in
                                guard let player else { return }
                                if editing == false {
                                    player.currentTime = player.duration * progress
                                }
                            }
                            .disabled(player == nil)
                            
                            Text(playerDurationString())
                                .font(.caption)
                                .frame(width: 46, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                        .onAppear { preparePlayerIfNeeded() }
                        .onDisappear { stopPlayer() }
                    }
                    .padding(.top, 4)
                    
                    // MARK: - タイトル
                    VStack(alignment: .leading, spacing: 6) {
                        Text("タイトル").font(.headline)
                        ZStack(alignment: .leading) {
                            if recording.title.isEmpty {
                                Text("録音を終了した時刻(発信日時) からの連絡")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                            }
                            TextField("", text: Binding(
                                get: { recording.title },
                                set: { recording.title = String($0.prefix(titleLimit)) }
                            ))
                            .textFieldStyle(.plain)
                            .padding(10)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)))
                        }
                        HStack {
                            Spacer()
                            Text("\(recording.title.count)/\(titleLimit)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // MARK: - アフターメッセージ
                    VStack(alignment: .leading, spacing: 6) {
                        Text("アフターメモ").font(.headline)
                        ZStack(alignment: .topLeading) {
                            if recording.afterMemo.isEmpty {
                                Text("（任意）着信後に表示されるメモ")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: Binding(
                                get: { recording.afterMemo },
                                set: { recording.afterMemo = String($0.prefix(memoLimit)) }
                            ))
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)))
                        }
                        HStack {
                            Spacer()
                            Text("\(recording.afterMemo.count)/\(memoLimit)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // MARK: - スヌーズ時間（分）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("スヌーズ時間（分）").font(.headline)
                        HStack {
                            TextField("5", value: $recording.snoozeMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .frame(width: 120)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)))
                            Text("分")
                            Spacer()
                        }
                    }
                    
                    // MARK: - URL（任意 / httpsのみ / Chrome優先で開く）
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ショートカットURL（任意）").font(.headline)
                        TextField("https://example.com", text: Binding(
                            get: { linkInput.isEmpty ? (recording.linkURLString ?? "") : linkInput },
                            set: { newVal in
                                linkInput = newVal
                                linkIsValidHTTPS = newVal.isEmpty || newVal.hasPrefix("https://")
                            }
                        ))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .padding(10)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(linkIsValidHTTPS ? .secondary.opacity(0.4) : .red))
                        
                        if !linkIsValidHTTPS {
                            Text("URLは https:// で始めてください").font(.caption).foregroundStyle(.red)
                        }
                        Text("空欄の場合はショートカットボタンを作りません。開くときはGoogle Chrome（なければSafari）で表示します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // MARK: - ToDo タスク
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ToDo タスク（任意）").font(.headline)
                        
                        // 既存タスクの編集/削除
                        ForEach(recording.tasks.indices, id: \.self) { idx in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.square") // 履歴画面でチェック可能、ここでは作成のみ
                                    .foregroundStyle(.secondary)
                                TextField("タスク内容", text: $recording.tasks[idx].text)
                                    .textFieldStyle(.plain)
                                    .padding(.vertical, 8)
                                Button {
                                    withAnimation {
                                        let task = recording.tasks.remove(at: idx)
                                        context.delete(task)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.3)))
                        }
                        
                        // 追加タブ（最初は枠だけ＋プラスボタン）
                        Button {
                            withAnimation {
                                recording.tasks.append(ReminderTask(text: ""))
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("タスクを追加")
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6,6])))
                        }
                        
                        // タスクが1件以上なら 締切UI 表示
                        if !recording.tasks.isEmpty {
                            Divider().padding(.top, 6)
                            Text("全タスクの締切（任意）").font(.headline)
                            
                            Picker("", selection: $deadlineMode) {
                                Text("時間・分後").tag(DeadlineMode.hoursMinutes)
                                Text("日後").tag(DeadlineMode.days)
                            }
                            .pickerStyle(.segmented)
                            
                            if deadlineMode == .hoursMinutes {
                                HStack {
                                    Stepper("時間 \(recording.deadlineHours ?? 0)", value: Binding(
                                        get: { recording.deadlineHours ?? 0 },
                                        set: { recording.deadlineHours = max(0, $0) }
                                    ), in: 0...168)
                                    Stepper("分 \(recording.deadlineMinutes ?? 0)", value: Binding(
                                        get: { recording.deadlineMinutes ?? 0 },
                                        set: { recording.deadlineMinutes = max(0, $0) }
                                    ), in: 0...55)
                                }
                                .onAppear {
                                    if recording.deadlineHours == nil { recording.deadlineHours = 0 }
                                    if recording.deadlineMinutes == nil { recording.deadlineMinutes = 0 }
                                    // モード切替時、日側をクリア
                                    recording.deadlineDays = nil
                                }
                            } else {
                                Stepper("日 \(recording.deadlineDays ?? 0)", value: Binding(
                                    get: { recording.deadlineDays ?? 0 },
                                    set: { recording.deadlineDays = max(0, $0) }
                                ), in: 0...365)
                                .onAppear {
                                    // モード切替時、時間分側をクリア
                                    recording.deadlineHours = nil
                                    recording.deadlineMinutes = nil
                                }
                            }
                            
                            Text("※タスクを全て削除すると締切設定は自動的に無効になります")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .onChange(of: recording.tasks.count) { _, newVal in
                                    if newVal == 0 {
                                        recording.deadlineHours = nil
                                        recording.deadlineMinutes = nil
                                        recording.deadlineDays = nil
                                    }
                                }
                        }
                    }
                    
                    // 下部アクションバーぶんの空き
                    Spacer().frame(height: actionBarHeight + 12)
                }
                .padding(.horizontal, 20)
            }
            
            // MARK: - 固定の下部アクションバー（フェード背景＋3ボタン）
            VStack(spacing: 0) {
                Spacer()
                // フェード背景（上に向かってフェード）
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.5), Color.black.opacity(0.0)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: actionBarHeight)
                .overlay(
                    HStack(spacing: 28) {
                        // キャンセル：録音データ等を削除→エントリへ
                        VStack(spacing: 6) {
                            Button {
                                deleteAndExit()
                            } label: {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 64, height: 64)
                                    .overlay(Image(systemName: "xmark").foregroundStyle(.white).font(.title2))
                            }
                            Text("キャンセル").font(.caption).foregroundStyle(.white.opacity(0.9))
                        }
                        
                        // 撮り直し：録音データ削除→録音画面へ戻る
                        VStack(spacing: 6) {
                            Button {
                                deleteAndGoBackToRecord()
                            } label: {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 64, height: 64)
                                    .overlay(Image(systemName: "arrow.uturn.left").foregroundStyle(.black).font(.title2))
                            }
                            Text("かけ直し").font(.caption).foregroundStyle(.white.opacity(0.9))
                        }
                        
                        // 確定：保存→既存の遷移
                        VStack(spacing: 6) {
                            Button {
                                saveAndContinue()
                            } label: {
                                Circle()
                                    .fill(Color.green.opacity(0.9))
                                    .frame(width: 64, height: 64)
                                    .overlay(Image(systemName: "checkmark").foregroundStyle(.white).font(.title2))
                            }
                            Text("確定").font(.caption).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.bottom, 28)
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle("詳細登録")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Player helpers
extension DetailEditView {
    private func preparePlayerIfNeeded() {
        guard player == nil else { return }
        guard let path = recording.audioFilePath else { return }
        do {
            let url = URL(fileURLWithPath: path)
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            self.player = p
            startProgressTimer()
        } catch {
            print("Audio load error:", error)
        }
    }
    private func startProgressTimer() {
        timer?.invalidate()
        guard let player else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            if player.duration > 0 {
                progress = player.currentTime / player.duration
            } else {
                progress = 0
            }
            if !player.isPlaying { isPlaying = false }
        }
    }
    private func stopPlayer() {
        timer?.invalidate()
        player?.stop()
        player = nil
        isPlaying = false
    }
    private func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    private func playerDurationString() -> String {
        guard let player else { return "00:00" }
        let total = Int(player.duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Save / Delete / Navigation
extension DetailEditView {
    private func deleteAndExit() {
        // 録音を含むこのレコードごと削除
        context.delete(recording)
        try? context.save()
        // エントリ画面へ（呼び出し側のナビゲーション設計に合わせて）
        dismiss()
    }
    private func deleteAndGoBackToRecord() {
        context.delete(recording)
        try? context.save()
        // 1つ前の録音画面へ戻る
        dismiss()
    }
    private func saveAndContinue() {
        // タイトルが空ならデフォルト文字列を適用
        if recording.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let df = DateFormatter()
            df.dateFormat = "yyyy/MM/dd HH:mm"
            recording.title = "\(df.string(from: recording.createdAt)) からの連絡"
        }
        // URL バリデーション（https のみ）
        let trimmed = (linkInput.isEmpty ? (recording.linkURLString ?? "") : linkInput).trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            recording.linkURLString = nil
        } else if trimmed.hasPrefix("https://") {
            recording.linkURLString = trimmed
        } else {
            // 不正なら保存しない（必要ならアラートに変更）
            recording.linkURLString = nil
        }
        try? context.save()
        // ここから従来の遷移へ（呼び出し側でハンドル）
        dismiss()
    }
}

// MARK: - Chrome/Safari 起動用（※実際に開くのは履歴/着信画面側で使う）
extension URL {
    static func preferredBrowserURL(from httpsString: String) -> URL? {
        guard httpsString.hasPrefix("https://"), let url = URL(string: httpsString) else { return nil }
        // Chrome 優先（インストール判定）
        if let scheme = URL(string: "googlechrome://"),
           UIApplication.shared.canOpenURL(scheme) {
            // https:// を googlechrome:// に変換
            let dropped = String(httpsString.dropFirst("https://".count))
            if let chromeURL = URL(string: "googlechrome://\(dropped)") {
                return chromeURL
            }
        }
        return url // Chromeがなければ https のまま（Safari）
    }
}

// MARK: - 簡易クロッパー（SwiftyCrop 置き換えまでのダミー）
struct SimpleSquareCropper: View {
    let image: UIImage
    let onFinish: (UIImage?) -> Void
    
    var body: some View {
        VStack {
            Text("トリミング（デモ）").font(.headline).padding(.top, 12)
            Spacer()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(Rectangle())
            Spacer()
            HStack {
                Button("キャンセル") { onFinish(nil) }
                Spacer()
                Button("中央を正方形で確定") {
                    onFinish(centerSquare(of: image))
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
    }
    private func centerSquare(of img: UIImage) -> UIImage? {
        let size = min(img.size.width, img.size.height)
        let x = (img.size.width - size) / 2
        let y = (img.size.height - size) / 2
        let rect = CGRect(x: x, y: y, width: size, height: size)
        guard let cg = img.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cg, scale: img.scale, orientation: img.imageOrientation)
    }
}
