import SwiftUI
import SwiftData
import AVFoundation
import PhotosUI
import UIKit

// 中間画面：仕様の「詳細登録画面」をこのファイルに統合
struct IntermediateView: View {
    let recordingId: UUID
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if let rec = fetch() {
                DetailCoreView(recording: rec)
            } else {
                ZStack { Theme.appGradient.ignoresSafeArea(); Text("対象データが見つかりません").foregroundStyle(.white) }
            }
        }
    }

    private func fetch() -> RecordingEntity? {
        do {
            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == recordingId })
            return try context.fetch(fd).first
        } catch { return nil }
    }
}

// 実体の編集ビュー（ファイル分割せず同ファイルに内包）
private struct DetailCoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var recording: RecordingEntity

    // 音声プレビュー
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var timer: Timer?

    // アイコン（簡易クロップ）
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var showCropper = false

    // URL
    @State private var linkInput: String = ""
    @State private var linkIsValidHTTPS: Bool = true

    // タスク締切
    enum DeadlineMode: String, CaseIterable { case hoursMinutes = "時間・分後", days = "日後" }
    @State private var deadlineMode: DeadlineMode = .hoursMinutes

    private let actionBarHeight: CGFloat = 120
    private let titleLimit = 30
    private let memoLimit = 140

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // アイコン
                        VStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.08)).frame(width: 120, height: 120)
                                if let data = recording.iconImageData, let ui = UIImage(data: data) {
                                    Image(uiImage: ui).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle").resizable().scaledToFit().frame(width: 110, height: 110).foregroundStyle(.white.opacity(0.6))
                                }
                                Button { showPhotoPicker = true } label: {
                                    Image(systemName: "arrow.2.circlepath.circle.fill").font(.system(size: 32)).foregroundStyle(.white).shadow(radius: 2).offset(x: 40, y: 40)
                                }
                                .accessibilityLabel("アイコンを変更")
                            }
                            Text("アイコン（写真/撮影→トリミング）").font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.top, 24)
                        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
                        .onChange(of: pickedItem) { _, newItem in
                            guard let newItem else { return }
                            Task { @MainActor in
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let ui = UIImage(data: data) {
                                    // 先にピッカーを閉じ、少し待ってからクロッパーを提示
                                    pickedImage = ui
                                    showPhotoPicker = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        showCropper = true
                                    }
                                } else {
                                    // 読み込み失敗時は安全に閉じる
                                    showPhotoPicker = false
                                    showCropper = false
                                }
                            }
                        }
                        .sheet(isPresented: $showCropper) {
                            if let img = pickedImage {
                                SimpleSquareCropper(image: img) { out in
                                    if let out, let data = out.pngData() { recording.iconImageData = data }
                                    showCropper = false
                                }
                            }
                        }

                        // プレビュー
                        VStack(alignment: .leading, spacing: 8) {
                            Text("プレビュー").font(.headline).foregroundStyle(.white)
                            HStack(spacing: 12) {
                                Button { togglePlay() } label: {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill").foregroundStyle(.white).padding(10).background(Circle().fill(Color.accentColor))
                                }
                                Slider(value: $progress, in: 0...1) { editing in
                                    guard let player else { return }
                                    if editing == false { player.currentTime = player.duration * progress }
                                }.disabled(player == nil)
                                Text(playerDurationString()).font(.caption).frame(width: 46, alignment: .trailing).foregroundStyle(.white.opacity(0.7))
                            }
                            .onAppear { preparePlayerIfNeeded() }
                            .onDisappear { stopPlayer() }
                        }

                        // スヌーズ
                        VStack(alignment: .leading, spacing: 8) {
                            Text("スヌーズ時間（分）").font(.headline).foregroundStyle(.white)
                            Stepper(value: Binding(get: { recording.snoozeMin ?? 10 }, set: { recording.snoozeMin = $0 }), in: 1...240) {
                                Text("\(recording.snoozeMin ?? 10) 分").foregroundStyle(.white)
                            }
                        }

                        // タイトル
                        VStack(alignment: .leading, spacing: 6) {
                            Text("タイトル").font(.headline).foregroundStyle(.white)
                            ZStack(alignment: .leading) {
                                if (recording.title ?? "").isEmpty {
                                    Text("録音を終了した時刻(発信日時) からの連絡").foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 12)
                                }
                                TextField("", text: Binding(get: { recording.title ?? "" }, set: { recording.title = String($0.prefix(titleLimit)) }))
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(.black)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                            }
                            HStack { Spacer(); Text("\((recording.title ?? "").count)/\(titleLimit)").font(.caption2).foregroundStyle(.white.opacity(0.7)) }
                        }

                        // アフターメモ
                        VStack(alignment: .leading, spacing: 6) {
                            Text("アフターメモ").font(.headline).foregroundStyle(.white)
                            ZStack(alignment: .topLeading) {
                                if (recording.afterMessage ?? "").isEmpty {
                                    Text("（任意）着信後に表示されるメモ").foregroundStyle(.white.opacity(0.6)).padding(.horizontal, 8).padding(.vertical, 8)
                                }
                                TextEditor(text: Binding(get: { recording.afterMessage ?? "" }, set: { recording.afterMessage = String($0.prefix(memoLimit)) }))
                                    .frame(minHeight: 90)
                                    .scrollContentBackground(.hidden)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                                    .foregroundStyle(.black)
                            }
                            HStack { Spacer(); Text("\((recording.afterMessage ?? "").count)/\(memoLimit)").font(.caption2).foregroundStyle(.white.opacity(0.7)) }
                        }

                        // URL
                        VStack(alignment: .leading, spacing: 6) {
                            Text("URL（任意・https:// のみ）").font(.headline).foregroundStyle(.white)
                            TextField("https://example.com", text: Binding(get: { linkInput.isEmpty ? (recording.linkURLString ?? "") : linkInput }, set: { newVal in
                                linkInput = newVal
                                linkIsValidHTTPS = newVal.trimmingCharacters(in: .whitespaces).isEmpty || newVal.hasPrefix("https://")
                            }))
                            .textFieldStyle(.roundedBorder)
                            if !linkIsValidHTTPS { Text("URLは https:// で始めてください").font(.footnote).foregroundStyle(.red) }
                        }

                        // タスク
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ToDo").font(.headline).foregroundStyle(.white)
                            if recording.tasks.isEmpty {
                                Button(action: { addTask() }) {
                                    HStack(spacing: 8) { Image(systemName: "plus.circle"); Text("タスクを追加") }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity).padding(14)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(style: StrokeStyle(lineWidth: 1, dash: [6])).foregroundColor(.white))
                                }
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(recording.tasks, id: \.id) { task in
                                        HStack(alignment: .top, spacing: 8) {
                                            TextField("タスク", text: Binding(get: { task.text }, set: { task.text = String($0.prefix(120)) }))
                                                .textFieldStyle(.roundedBorder)
                                                .foregroundStyle(.black)
                                            Button(role: .destructive) { removeTask(task) } label: { Image(systemName: "trash").foregroundStyle(.red) }
                                        }
                                    }
                                    Button(action: { addTask() }) {
                                        HStack(spacing: 8) { Image(systemName: "plus.circle"); Text("タスクを追加") }
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity).padding(10)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(style: StrokeStyle(lineWidth: 1, dash: [6])).foregroundColor(.white))
                                    }
                                }
                            }
                        }

                        // 締切（タスクがある時のみ）
                        if !recording.tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("全タスクの締切設定").font(.headline).foregroundStyle(.white)
                                Picker("モード", selection: $deadlineMode) {
                                    Text(DeadlineMode.hoursMinutes.rawValue).tag(DeadlineMode.hoursMinutes)
                                    Text(DeadlineMode.days.rawValue).tag(DeadlineMode.days)
                                }
                                .pickerStyle(.segmented)
                                .tint(.white)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.12)))

                                if deadlineMode == .hoursMinutes {
                                    Stepper(value: Binding(get: { recording.deadlineHours ?? 0 }, set: { recording.deadlineHours = $0 }), in: 0...72) {
                                        Text("\(recording.deadlineHours ?? 0) 時間").foregroundStyle(.white)
                                    }
                                    Stepper(value: Binding(get: { recording.deadlineMinutes ?? 0 }, set: { recording.deadlineMinutes = $0 }), in: 0...59) {
                                        Text("\(recording.deadlineMinutes ?? 0) 分").foregroundStyle(.white)
                                    }
                                } else {
                                    Stepper(value: Binding(get: { recording.deadlineDays ?? 0 }, set: { recording.deadlineDays = $0 }), in: 0...60) {
                                        Text("\(recording.deadlineDays ?? 0) 日後").foregroundStyle(.white)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: actionBarHeight)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }

                // 下部固定バー
                LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)], startPoint: .bottom, endPoint: .top)
                    .frame(height: actionBarHeight)
                    .overlay(
                        HStack(spacing: 28) {
                            VStack(spacing: 6) {
                                Button { deleteAndExit() } label: {
                                    Circle().fill(Color.red).frame(width: 64, height: 64).overlay(Image(systemName: "xmark").foregroundStyle(.white).font(.title2))
                                }
                                Text("キャンセル").font(.caption).foregroundStyle(.white.opacity(0.9))
                            }
                            VStack(spacing: 6) {
                                Button { deleteAndGoBackToRecord() } label: {
                                    Circle().fill(Color.white).frame(width: 64, height: 64).overlay(Image(systemName: "arrow.uturn.left").foregroundStyle(.black).font(.title2))
                                }
                                Text("かけ直し").font(.caption).foregroundStyle(.white.opacity(0.9))
                            }
                            VStack(spacing: 6) {
                                Button { saveAndContinue() } label: {
                                    Circle().fill(Color.green.opacity(0.9)).frame(width: 64, height: 64).overlay(Image(systemName: "checkmark").foregroundStyle(.white).font(.title2))
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
        .onAppear {
            if linkInput.isEmpty { linkInput = recording.linkURLString ?? "" }
            if (recording.deadlineDays ?? 0) > 0 { deadlineMode = .days } else { deadlineMode = .hoursMinutes }
        }
        .onChange(of: deadlineMode) { newMode in
            if newMode == .days { recording.deadlineHours = nil; recording.deadlineMinutes = nil }
            else { recording.deadlineDays = nil }
        }
    }

    // MARK: Player helpers
    private func preparePlayerIfNeeded() {
        guard player == nil else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(recording.fileName)
        do { let p = try AVAudioPlayer(contentsOf: url); p.prepareToPlay(); player = p; startProgressTimer() } catch { print("Audio load error:", error) }
    }
    private func startProgressTimer() {
        timer?.invalidate(); guard let player else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            progress = player.duration > 0 ? player.currentTime / player.duration : 0
            if !player.isPlaying { isPlaying = false }
        }
    }
    private func stopPlayer() { timer?.invalidate(); player?.stop(); player = nil; isPlaying = false }
    private func togglePlay() { guard let player else { return }; if player.isPlaying { player.pause(); isPlaying = false } else { player.play(); isPlaying = true } }
    private func playerDurationString() -> String { guard let player else { return "00:00" }; let t = Int(player.duration); return String(format: "%02d:%02d", t/60, t%60) }

    // MARK: Task helpers
    private func addTask() {
        let new = RecordingTaskEntity(text: "", isDone: false)
        recording.tasks.append(new)
    }

    private func removeTask(_ task: RecordingTaskEntity) {
        // 非同期に削除して ForEach 再計算中の不整合を回避
        DispatchQueue.main.async {
            if let idx = recording.tasks.firstIndex(where: { $0 === task }) {
                let removed = recording.tasks.remove(at: idx)
                context.delete(removed)
            }
        }
    }

    // MARK: Save/Delete
    private func deleteAndExit() {
        NotificationManager.shared.cancelAllNotifications(for: recording.id.uuidString)
        deleteAudioFileIfExists()
        context.delete(recording)
        try? context.save()
        NotificationRouter.shared.switchToTab(2)
        dismiss()
    }
    private func deleteAndGoBackToRecord() {
        let date = recording.recordedAt
        let secondsAhead = date.timeIntervalSince(Date())
        // 既存データのクリーンアップ
        NotificationManager.shared.cancelAllNotifications(for: recording.id.uuidString)
        deleteAudioFileIfExists()
        context.delete(recording)
        try? context.save()
        if secondsAhead <= 60 {
            // 60秒以内ならキーパッドへ戻る
            NotificationRouter.shared.switchToTab(2)
            dismiss()
        } else {
            // 同じ未来時刻で通信中画面からやり直し
            NotificationRouter.shared.presentAudioPlay(for: date)
            NotificationRouter.shared.switchToTab(2) // タブはキーパッドにしておく（任意）
            NotificationRouter.shared.dismissIntermediate()
            dismiss()
        }
    }
    private func saveAndContinue() {
        if (recording.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let df = DateFormatter(); df.dateFormat = "yyyy/MM/dd HH:mm"; recording.title = "\(df.string(from: recording.recordedAt)) からの電話"
        }
        let trimmed = (linkInput.isEmpty ? (recording.linkURLString ?? "") : linkInput).trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { recording.linkURLString = nil } else if trimmed.hasPrefix("https://") { recording.linkURLString = trimmed } else { recording.linkURLString = nil }
        try? context.save()
        NotificationRouter.shared.switchToTab(3)
        NotificationRouter.shared.dismissIntermediate()
        dismiss()
    }
    private func deleteAudioFileIfExists() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(recording.fileName)
        try? FileManager.default.removeItem(at: url)
    }
}

// Chrome 優先の URL 生成（同ファイル内）
extension URL {
    static func preferredBrowserURL(from httpsString: String) -> URL? {
        guard httpsString.hasPrefix("https://"), let url = URL(string: httpsString) else { return nil }
        if let scheme = URL(string: "googlechrome://"), UIApplication.shared.canOpenURL(scheme) {
            let dropped = String(httpsString.dropFirst("https://".count))
            if let chromeURL = URL(string: "googlechrome://\(dropped)") { return chromeURL }
        }
        return url
    }
}

// 簡易クロップ（SwiftyCrop置き換え予定）
private struct SimpleSquareCropper: View {
    let image: UIImage
    let onFinish: (UIImage?) -> Void
    var body: some View {
        VStack {
            Text("トリミング（デモ）").font(.headline).padding(.top, 12)
            Spacer()
            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 300)
            Spacer()
            HStack { Button("キャンセル") { onFinish(nil) }; Spacer(); Button("中央を正方形で確定") { onFinish(centerSquare(of: image)) } }.padding()
        }
        .presentationDetents([.medium, .large])
    }
    private func centerSquare(of img: UIImage) -> UIImage? {
        let size = min(img.size.width, img.size.height)
        let x = (img.size.width - size) / 2; let y = (img.size.height - size) / 2
        let rect = CGRect(x: x, y: y, width: size, height: size)
        guard let cg = img.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cg, scale: img.scale, orientation: img.imageOrientation)
    }
}
