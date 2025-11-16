import SwiftUI
import SwiftData
import UIKit
import Combine

// 通話後（AfterCall）画面
// - docs/specs/tuuwago.md のTODO仕様に準拠
struct AfterCallView: View {
    let messageId: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // 表示用データ
    @State private var recording: RecordingEntity? = nil
    @State private var iconImage: UIImage? = nil
    @State private var showReListen: Bool = false

    // カウントダウン（1秒間隔で更新。60分以上でも許容範囲内のコスト）
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.appGradient.ignoresSafeArea()

            GeometryReader { proxy in
                let h = proxy.size.height
                let iconSize = min(proxy.size.width * 0.55, 280)
                let topSpacing = h * 0.12

                VStack(spacing: 12) {
                    Spacer().frame(height: topSpacing)

                    // 丸アイコン
                    Group {
                        if let ui = iconImage {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: iconSize, height: iconSize)
                                .clipShape(Circle())
                                .shadow(radius: 8)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: iconSize, height: iconSize)
                                .overlay(
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(.white.opacity(0.7))
                                        .padding(iconSize * 0.18)
                                )
                        }
                    }

                    // タイトル（括弧なし）。空なら自動生成を使う（サブテキストは非表示）
                    if let rec = recording {
                        Text(displayTitle(rec))
                            .font(.title2).fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.top, 6)

                        if shouldShowSubText(rec) {
                            Text("\(formattedDate(savedDate(for: rec))) からの電話")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .padding(.bottom, 2)
                        }
                    }

                    // スクロール領域（アフターメッセージ + タスク一式）
                    ScrollView {
                        VStack(alignment: .center, spacing: 20) {
                            if let rec = recording, let msg = (rec.afterMessage?.trimmingCharacters(in: .whitespacesAndNewlines)), !msg.isEmpty {
                                Text(msg)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .frame(width: proxy.size.width * 0.8)
                                    .padding(.top, 6)
                            }

                            // タスク見出し + 期限表示 + タスク一覧
                            if let rec = recording, !rec.tasks.isEmpty {
                                // 見出し（数値を強調・文言変更）
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(rec.tasks.count)")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("個のタスクがあります。")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                    .padding(.horizontal, 24)

                                if let deadline = computeDeadline(for: rec) {
                                    deadlineSection(deadline: deadline)
                                }

                                VStack(spacing: 14) {
                                    ForEach(rec.tasks.indices, id: \.self) { idx in
                                        taskRow(task: rec.tasks[idx], isLocked: isExpired(for: rec))
                                        if idx < rec.tasks.count - 1 {
                                            Divider().background(Color.white.opacity(0.4)).frame(width: proxy.size.width * 0.6)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 220) // ボタン干渉回避（余白増）
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Spacer()
                }
            }

            // 下フェード背景
            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.7), .clear]), startPoint: .bottom, endPoint: .top)
                .frame(height: 180)
                .ignoresSafeArea(edges: .bottom)

            // 下部ボタン群
            HStack {
                // 左: 聞き直し
                VStack(spacing: 6) {
                    Button {
                        SoundManager.shared.play("cancell", ext: "mp3")
                        showReListen = true
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                            .overlay(
                                Image(systemName: "arrow.uturn.left")
                                    .foregroundStyle(.black)
                                    .font(Theme.circleButtonIconFont)
                            )
                    }
                    Text("聞き直し")
                        .foregroundStyle(.white)
                        .font(Theme.circleButtonLabelFont)
                }
                Spacer()

                // 中央: ショートカット（有効な https:// のみ）
                if let url = shortcutURL(), isHTTPS(url) {
                    VStack(spacing: 6) {
                        Button {
                            SoundManager.shared.play("nutural", ext: "mp3")
                            openShortcut(url)
                        } label: {
                            Circle()
                                .fill(Color(red: 0.52, green: 0.85, blue: 0.22))
                                .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                .overlay(
                                    Image(systemName: "link")
                                        .foregroundStyle(.white)
                                        .font(Theme.circleButtonIconFont)
                                )
                        }
                        Text("ショートカット")
                            .foregroundStyle(.white)
                            .font(Theme.circleButtonLabelFont)
                    }
                    Spacer()
                }

                // 右: 完了
                VStack(spacing: 6) {
                    Button {
                        SoundManager.shared.play("kettei", ext: "mp3")
                        completeAndClose()
                    } label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.black)
                                    .font(Theme.circleButtonIconFont)
                            )
                    }
                    Text("完了")
                        .foregroundStyle(.white)
                        .font(Theme.circleButtonLabelFont)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 36)
        }
        .onAppear { load() }
        .fullScreenCover(isPresented: $showReListen) {
            if let rec = recording { ReListenPlayerView(recording: rec) }
        }
        .onReceive(timer) { _ in tick() }
    }

    // MARK: - Sections
    @ViewBuilder
    private func deadlineSection(deadline: Date) -> some View {
        if let rec = recording {
            let remaining = max(0, deadline.timeIntervalSince(now))
            let lessThan1h = remaining < 3600

            if rec.deadlineDays != nil { // 日数モード
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("目標まで").foregroundStyle(.white).font(.headline)
                        Text("\(rec.deadlineDays ?? 0)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.35))
                        Text("日後").foregroundStyle(.white).font(.headline)
                    }
                    Text("\(formatDateOnly(deadline)) まで")
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            } else if (rec.deadlineHours ?? 0) > 0 || (rec.deadlineMinutes ?? 0) > 0 { // 時間/分モード
                let textColor: Color = lessThan1h ? .red : .white
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("目標時刻まで").foregroundStyle(.white).font(.headline)
                        Text(lessThan1h ? formatMMSS(remaining) : formatHHMM(remaining))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(lessThan1h ? .red : Color(red: 0.65, green: 0.95, blue: 0.35))
                    }
                    Text("\(formatDateTime(deadline)) まで")
                        .font(.footnote)
                        .foregroundStyle(textColor.opacity(0.8))
                }
            }
        }
    }

    // ロック状態か
    private func isExpired(for rec: RecordingEntity) -> Bool {
        guard let deadline = computeDeadline(for: rec) else { return false }
        return now >= deadline
    }

    // タスク1行
    private func taskRow(task: RecordingTaskEntity, isLocked: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: {
                guard !isLocked else { return }
                task.isDone.toggle()
                try? context.save()
            }) {
                Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isLocked ? Color.white.opacity(0.6) : .white)
            }
            .disabled(isLocked)

            Text(task.text)
                .foregroundStyle(taskTextColor(task: task, isLocked: isLocked))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
    }

    private func taskTextColor(task: RecordingTaskEntity, isLocked: Bool) -> Color {
        if isLocked { return task.isDone ? Color(red: 0.65, green: 0.95, blue: 0.35) : .red }
        return .white
    }

    // MARK: - Loading
    private func load() {
        guard let uuid = UUID(uuidString: messageId) else { return }
        do {
            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
            if let rec = try context.fetch(fd).first {
                recording = rec
                if let data = rec.iconImageData, let ui = UIImage(data: data) { iconImage = ui }
                // デッドライン起点が無い場合は安全に埋める
                if rec.deadlineBaseAt == nil { rec.deadlineBaseAt = Date(); try? context.save() }
            }
        } catch { recording = nil }
    }

    // MARK: - Actions
    private func completeAndClose() {
        updatePlayedStatus()
        withAnimation(nil) { NotificationRouter.shared.switchToTab(2) }
        withAnimation(nil) {
            NotificationRouter.shared.dismissCall()
            NotificationRouter.shared.dismissIncomingCall()
            NotificationRouter.shared.dismissAfterCall()
        }
        dismiss()
    }

    private func openShortcut(_ url: URL) {
        updatePlayedStatus()
        // Chrome 優先
        let chromeScheme = URL(string: "googlechrome://")!
        if UIApplication.shared.canOpenURL(chromeScheme) {
            // https:// を googlechrome:// に変換
            if url.absoluteString.lowercased().hasPrefix("https://") {
                let dropped = String(url.absoluteString.dropFirst("https://".count))
                if let chromeURL = URL(string: "googlechrome://\(dropped)") {
                    UIApplication.shared.open(chromeURL)
                    return
                }
            }
        }
        UIApplication.shared.open(url)
    }

    private func updatePlayedStatus() {
        guard let rec = recording else { return }
        rec.status = "answered" // 履歴へ反映させる
        rec.inVoicemailInbox = false
        try? context.save()
    }

    // MARK: - Helpers
    private func shouldShowSubText(_ rec: RecordingEntity) -> Bool {
        let t = (rec.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false } // 自動生成にするので非表示
        if rec.isAutoTitle { return false }
        return true
    }
    private func displayTitle(_ rec: RecordingEntity) -> String {
        let t = (rec.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return "\(formattedDate(savedDate(for: rec))) からの電話"
    }
    private func savedDate(for rec: RecordingEntity) -> Date {
        if let d = rec.savedAt { return d }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rec.fileName)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), let d = attrs[.creationDate] as? Date {
            return d
        }
        return Date()
    }
    private func formattedDate(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"; return f.string(from: date) }
    private func formatDateTime(_ date: Date) -> String { formattedDate(date) }
    private func formatDateOnly(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"; return f.string(from: date) }
    private func formatHHMM(_ seconds: TimeInterval) -> String { let s = Int(seconds); return String(format: "%02d:%02d", s/3600, (s%3600)/60) }
    private func formatMMSS(_ seconds: TimeInterval) -> String { let s = Int(seconds); return String(format: "%02d:%02d", (s/60)%60, s%60) }

    private func computeDeadline(for rec: RecordingEntity) -> Date? {
        let base = rec.deadlineBaseAt ?? rec.answeredAt ?? savedDate(for: rec)
        if let d = rec.deadlineDays, d > 0 {
            // D日後の「その日の 23:59」
            var comp = Calendar.current.dateComponents([.year, .month, .day], from: base)
            let startOfDay = Calendar.current.date(from: comp) ?? base
            guard let plus = Calendar.current.date(byAdding: .day, value: d, to: startOfDay) else { return nil }
            var c = Calendar.current.dateComponents([.year, .month, .day], from: plus)
            c.hour = 23; c.minute = 59; c.second = 0
            return Calendar.current.date(from: c)
        }
        if (rec.deadlineHours ?? 0) > 0 || (rec.deadlineMinutes ?? 0) > 0 {
            var sec = 0
            if let h = rec.deadlineHours { sec += max(0, h) * 3600 }
            if let m = rec.deadlineMinutes { sec += max(0, m) * 60 }
            return base.addingTimeInterval(TimeInterval(sec))
        }
        return nil
    }

    private func tick() { now = Date() }

    private func shortcutURL() -> URL? {
        guard let s = recording?.linkURLString?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: s) else { return nil }
        return url
    }
    private func isHTTPS(_ url: URL) -> Bool { url.scheme?.lowercased() == "https" }
}

// 聞き直し（再生）ビュー: 通話中画面のバリアント（波形下に進捗表示）
private struct ReListenPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let recording: RecordingEntity
    @StateObject private var player = AudioPlayerViewModel()
    @State private var elapsed: Double = 0
    @State private var duration: Double = 1
    @State private var didFinish: Bool = false
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack {
                Spacer().frame(height: 80)
                if let data = recording.iconImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill).frame(width: 160, height: 160).clipShape(Circle()).shadow(radius: 10)
                } else {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 160, height: 160)
                        .overlay(Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(.white.opacity(0.7)).padding(24))
                }
                Text(timeString(elapsed)).font(.system(size: 36, weight: .bold, design: .monospaced)).foregroundStyle(.white).padding(.top, 16)
                // 波形（再生中のみアニメ）
                WaveformViewSimple(isAnimating: Binding(get: { player.isPlaying }, set: { _ in }))
                    .frame(height: 80)
                    .padding(.vertical, 10)

                // コントロール + 進捗スライダー
                HStack(spacing: 12) {
                    // 再生/一時停止
                    Button(action: {
                        if player.isPlaying { player.pause() } else { player.play() }
                    }) {
                        Circle().fill(Color.white)
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").foregroundColor(.black))
                    }
                    // 最初から（終了時のみ表示）
                    if didFinish || (elapsed >= duration - 0.1) {
                        Button(action: { restart() }) {
                            Circle().fill(Color.white)
                                .frame(width: 40, height: 40)
                                .overlay(Image(systemName: "backward.to.start.fill").foregroundColor(.black))
                        }
                    }
                    Slider(value: Binding(get: { elapsed }, set: { newVal in
                        elapsed = newVal
                        player.seek(to: newVal)
                    }), in: 0...max(duration, 1))
                    .tint(.white)
                }
                .padding(.horizontal, 24)

                Spacer()
                VStack(spacing: 8) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                                .font(Theme.circleButtonIconFont)
                        }
                    }
                    Text("閉じる")
                        .foregroundStyle(.white)
                        .font(Theme.circleButtonLabelFont)
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear { start() }
        .onReceive(tick) { _ in
            elapsed = player.currentTime()
            duration = max(player.duration(), 1)
        }
    }

    private func start() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(recording.fileName)
        didFinish = false
        player.playURL(url, loops: 0) { didFinish = true }
        duration = max(player.duration(), 1)
    }
    private func restart() {
        didFinish = false
        player.seek(to: 0)
    }

    private func timeString(_ sec: Double) -> String {
        let s = Int(sec); return String(format: "%02d : %02d", s/60, s%60)
    }
}

// 軽量波形（ダミーアニメ）
private struct WaveformViewSimple: View {
    @Binding var isAnimating: Bool
    @State private var values: [CGFloat] = (0..<30).map { _ in CGFloat.random(in: 0.2...1.0) }
    @State private var timer: Timer? = nil
    var body: some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 3) {
                    ForEach(values.indices, id: \.self) { i in
                        Capsule().fill(Color.white).frame(width: 3, height: geo.size.height * values[i])
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { start() }
        .onDisappear { stop() }
        .onChange(of: isAnimating) { _ in isAnimating ? start() : stop() }
    }

    private func start() {
        guard timer == nil, isAnimating else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { values = (0..<30).map { _ in CGFloat.random(in: 0.2...1.0) } }
        }
    }
    private func stop() { timer?.invalidate(); timer = nil }
}
