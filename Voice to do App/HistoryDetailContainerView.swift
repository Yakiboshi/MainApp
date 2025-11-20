import SwiftUI
import AVFAudio
import SwiftData
import Combine
import UIKit
import CoreGraphics

struct HistoryDetailContainerView: View {
    @Environment(\.modelContext) private var context
    let recordingId: UUID

    @State private var dominantBackground: Color? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // ベースのグラデーション
            Theme.appGradient.ignoresSafeArea()

            // アイコンから抽出した色があれば、その色で上からグラデーションを重ねる
            if let bg = dominantBackground {
                LinearGradient(
                    colors: [
                        bg.opacity(0.9),
                        bg.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            Group {
                if let state = buildState() {
                    HistoryDetailScreen(
                        entity: state.current,
                        previousId: state.previousId,
                        nextId: state.nextId
                    )
                } else {
                    ZStack {
                        Theme.appGradient.ignoresSafeArea()
                        Text("対象の履歴が見つかりません")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        // recordingId ごとにビューを作り直し、@State を確実にリセット
        .id(recordingId)
        .onAppear {
            // 初回表示時: 現在の履歴に合わせて背景色を設定（アニメーションなし）
            updateBackground(for: recordingId, animated: false)
        }
        .onChange(of: recordingId) { newId in
            // 履歴IDが変わったとき（次へ/前へなど）は、遷移先のデータに合わせてフェードしながら背景色を更新
            updateBackground(for: newId, animated: true)
        }
    }

    private func buildState() -> (current: RecordingEntity, previousId: UUID?, nextId: UUID?)? {
        do {
            let fd = FetchDescriptor<RecordingEntity>()
            // 履歴画面と同様に、answered のみを対象とし recordedAt 昇順で並べる
            let all = try context.fetch(fd)
            let historyItems = all
                .filter { ($0.status ?? "scheduled") == "answered" }
                .sorted { $0.recordedAt < $1.recordedAt }

            guard let index = historyItems.firstIndex(where: { $0.id == recordingId }) else {
                return nil
            }

            let current = historyItems[index]
            let previousId = index > 0 ? historyItems[index - 1].id : nil
            let nextId = index < historyItems.count - 1 ? historyItems[index + 1].id : nil
            return (current: current, previousId: previousId, nextId: nextId)
        } catch {
            return nil
        }
    }
}

private struct HistoryDetailScreen: View {
    let entity: RecordingEntity
    let previousId: UUID?
    let nextId: UUID?

    @Environment(\.modelContext) private var context
    @StateObject private var player = AudioPlayerViewModel()

    private let router = NotificationRouter.shared
    @State private var elapsed: Double = 0
    @State private var duration: Double = 1
    @State private var didLoadDuration: Bool = false
    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    @State private var newTaskText: String = ""
    @State private var deletableTaskIds: Set<UUID> = []
    @State private var showRetrySheet: Bool = false
    @State private var retryHours: Int = 0
    @State private var retryMinutes: Int = 0
    @State private var retryDate: Date = Date()

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                let h = proxy.size.height
                let boxWidth = min(proxy.size.width - 32, 380) // 両端16pt程度の余白で少し拡大
                let topSpacing = h * 0.12
                let iconSize = min(boxWidth, 220)

                VStack(spacing: 16) {
                    Spacer().frame(height: topSpacing)

                    // アイコン + タイトル + 再生ボックスをまとめて背面に丸型アイコンを配置
                    ZStack {
                        // 背面の丸型アイコン
                        if let data = entity.iconImageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: iconSize, height: iconSize)
                                .clipShape(Circle())
                                .opacity(0.25)
                                .offset(y: -10)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: iconSize, height: iconSize)
                                .opacity(0.6)
                                .offset(y: -10)
                        }

                        VStack(spacing: 16) {
                            // タイトル + サブテキスト
                            VStack(spacing: 6) {
                                Text(title())
                                    .font(.title2).fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                if let at = entity.answeredAt {
                                    Text(at.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.35))
                            )

                            // プレーヤーボックス（スライダー + 時刻 + 前/再生/次）
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.black.opacity(0.6),
                                                Color.black.opacity(0.3)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )

                                VStack(spacing: 12) {
                                    // 上部: 進捗スライダー
                                    VStack(spacing: 4) {
                                        Slider(
                                            value: Binding(
                                                get: { elapsed },
                                                set: { newVal in
                                                    elapsed = newVal
                                                    player.seek(to: newVal)
                                                }
                                            ),
                                            in: 0...max(duration, 1)
                                        )
                                        .tint(.white)

                                        HStack {
                                            Text(timeString(elapsed))
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(timeString(duration))
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                    }
                                    .padding(.horizontal, 18) // バーの端とボックス枠の間に余白を確保

                                    HStack(spacing: 32) {
                                        // 前へ
                                        Button(action: { goToPrevious() }) {
                                            Image(systemName: "chevron.left.circle.fill")
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundStyle(.white)
                                                .opacity(previousId == nil ? 0.3 : 1.0)
                                        }
                                        .disabled(previousId == nil)

                                        // 再生 / 一時停止
                                        Button(action: { togglePlay() }) {
                                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                .font(.system(size: 40, weight: .bold))
                                                .foregroundStyle(.white)
                                        }

                                        // 次へ
                                        Button(action: { goToNext() }) {
                                            Image(systemName: "chevron.right.circle.fill")
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundStyle(.white)
                                                .opacity(nextId == nil ? 0.3 : 1.0)
                                        }
                                        .disabled(nextId == nil)
                                    }
                                }
                                .padding(.vertical, 16)
                            }
                            .frame(width: boxWidth, height: 150)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // スクロール領域（メモ + タスク一式）
                    ScrollView {
                        VStack(alignment: .center, spacing: 20) {
                            if let msg = entity.afterMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !msg.isEmpty {
                                Text(msg)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.white)
                                    .frame(width: proxy.size.width * 0.8)
                                    .padding(.top, 6)
                            }

                            if !entity.tasks.isEmpty {
                                taskBox(proxyWidth: proxy.size.width)
                            }
                        }
                        .padding(.bottom, 220) // 下部ボタンと被らないように十分な余白を確保
                    }
                    // スクロール操作でキーボードを閉じる
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            dismissKeyboard()
                        }
                    )
                }
            }

            // 下部: 戻る + URL（あれば） — 背景グラデーションの上にボタンを重ねる
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.7), .clear]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 140)
                .ignoresSafeArea(edges: .bottom)

                HStack {
                    VStack(spacing: 6) {
                        Button {
                            player.stop()
                            router.dismissHistoryDetail()
                        } label: {
                            Circle()
                                .fill(Color.white)
                                .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                .overlay(
                                    Image(systemName: "chevron.backward")
                                        .foregroundStyle(.black)
                                        .font(Theme.circleButtonIconFont)
                                )
                        }
                        Text("履歴に戻る")
                            .foregroundStyle(.white)
                            .font(Theme.circleButtonLabelFont)
                    }

                    Spacer()

                    if let url = historyShortcutURL() {
                        VStack(spacing: 6) {
                            Button {
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
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
        }
        // 背景タップでキーボードを閉じる
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .onDisappear {
            player.stop()
        }
        .onAppear {
            prepareDurationIfNeeded()
            // 初回表示時は現在のエンティティに合わせて再生状態を初期化
            resetAudioStateForCurrentEntity()
        }
        // 前へ/次へ で別の履歴に遷移したとき、バー・時間表示を新しいデータに合わせてリセット
        .onChange(of: entity.id) { _ in
            resetAudioStateForCurrentEntity()
        }
        .onReceive(tick) { _ in
            elapsed = player.currentTime()
            duration = max(player.duration(), duration)
            now = Date()
        }
        .overlay {
            if showRetrySheet {
                retryOverlay()
            }
        }
    }

    private func title() -> String {
        if let t = entity.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return "\(f.string(from: entity.recordedAt)) からの電話"
    }

    // MARK: - Audio
    private func audioURL() -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(entity.fileName)
    }

    private func togglePlay() {
        if player.isPlaying {
            player.pause()
            return
        }
        // 再生前に再生用セッション（.playback + スピーカー）を構成
        AudioRouteManager.configurePlaybackSession()
        // 再生開始時は現在のエンティティに合わせて状態を再構築
        resetAudioStateForCurrentEntity()
        guard let url = audioURL() else { return }
        let baseGain: Float = 1.0
        let userGain = PlaybackVolume.currentGain()
        let volume = baseGain * userGain
        player.playURL(url, loops: 0, volume: volume) {
            // 再生終了時は自動で isPlaying が false になる
        }
    }

    private func prepareDurationIfNeeded() {
        guard !didLoadDuration, let url = audioURL() else { return }
        do {
            let tmp = try AVAudioPlayer(contentsOf: url)
            duration = max(tmp.duration, 1)
            didLoadDuration = true
        } catch {
            // ignore
        }
    }

    /// エンティティが切り替わったときに、再生状態・バー・時間表示をリセットし、新しい録音の総時間を読み込む
    private func resetAudioStateForCurrentEntity() {
        player.stop()
        elapsed = 0
        duration = 1
        didLoadDuration = false
        prepareDurationIfNeeded()
    }

    // MARK: - Prev/Next navigation
    private func goToPrevious() {
        guard let prev = previousId else { return }
        player.stop()
        router.presentHistoryDetail(for: prev)
    }

    private func goToNext() {
        guard let next = nextId else { return }
        player.stop()
        router.presentHistoryDetail(for: next)
    }

    // MARK: - URL handling
    private func historyShortcutURL() -> URL? {
        guard let s = entity.linkURLString?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let url = URL(string: s),
              url.scheme?.lowercased() == "https"
        else { return nil }
        return url
    }

    private func openShortcut(_ url: URL) {
        // Chrome 優先（AfterCallView と同様のロジック）
        let chromeScheme = URL(string: "googlechrome://")!
        if UIApplication.shared.canOpenURL(chromeScheme) {
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

    // MARK: - Retry deadline overlay
    @ViewBuilder
    private func retryOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    showRetrySheet = false
                }

            VStack(spacing: 16) {
                Text("締切をやり直す")
                    .font(.headline)
                    .foregroundStyle(.white)

                if entity.deadlineDays != nil {
                    // 日時モード: 日付を選択
                    DatePicker(
                        "",
                        selection: $retryDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.white)
                } else {
                    // 時間・分モード
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(retryHours) 時間")
                                .foregroundStyle(.white)
                            Spacer()
                            Stepper("", value: $retryHours, in: 0...72)
                                .labelsHidden()
                                .tint(.white)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                        }
                        HStack {
                            Text("\(retryMinutes) 分")
                                .foregroundStyle(.white)
                            Spacer()
                            Stepper("", value: $retryMinutes, in: 0...59)
                                .labelsHidden()
                                .tint(.white)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                        }
                    }
                }

                HStack {
                    Button {
                        // 戻る: 変更せず閉じる
                        showRetrySheet = false
                    } label: {
                        Text("戻る")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.9))
                            )
                    }

                    Spacer()

                    Button {
                        startRetryDeadline()
                    } label: {
                        Text("スタート")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 0.96, green: 0.80, blue: 0.20))
                            )
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Tasks & deadline
    @ViewBuilder
    private func taskBox(proxyWidth: CGFloat) -> some View {
        let total = entity.tasks.count
        let remaining = entity.tasks.filter { !$0.isDone }.count
        let deadline = computeDeadline(for: entity)
        let locked = isExpired(for: entity)

        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                // 見出し（締切未超過時は総数+残タスク、超過時は「タスク未達成」）
                if let d = deadline, locked {
                    HStack {
                        Spacer()
                        Text("タスク未達成")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                        Spacer()
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // 総タスク数: 背面に 8 を同フォントで配置
                        let totalText = "\(total)"
                        let totalMask = String(repeating: "8", count: totalText.count)
                        ZStack {
                            Text(totalMask)
                                .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 28))
                                .foregroundStyle(.black)
                            Text(totalText)
                                .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 28))
                                .foregroundStyle(.white)
                        }
                        Text("個のタスクがあります。")
                            .font(.headline)
                            .foregroundStyle(.white)
                        if remaining > 0 {
                            // 残りタスク数は元のフォントに戻す
                            Text("残り \(remaining)")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                }

                if let d = deadline {
                    deadlineSection(deadline: d)
                }

                if let d = deadline, locked, remaining > 0 {
                    HStack {
                        Spacer()
                        Button {
                            prepareRetryValues(currentDeadline: d)
                            showRetrySheet = true
                        } label: {
                            Text("やり直し")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.18))
                                )
                        }
                        Spacer()
                    }
                }

                VStack(spacing: 10) {
                    ForEach(entity.tasks, id: \.id) { task in
                        taskRow(task: task, isLocked: locked && !isNew(task: task))
                    }
                }

                if !locked {
                    HStack(spacing: 8) {
                        TextField(
                            "",
                            text: $newTaskText,
                            prompt: Text("新しいタスクを追加").foregroundColor(.gray)
                        )
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(.black)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))

                        Button(action: { addTask() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(trimmedNewTaskText.isEmpty ? Color.white.opacity(0.4) : .white)
                        }
                        .disabled(trimmedNewTaskText.isEmpty)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .frame(width: min(proxyWidth - 40, 360))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func isNew(task: RecordingTaskEntity) -> Bool {
        // ここでは「テキストが空のタスク」を新規扱いとする（締切超過時のロック判定用）。
        return task.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

            Text(task.text.isEmpty ? "新しいタスク" : task.text)
                .foregroundStyle(taskTextColor(task: task, isLocked: isLocked))
                .frame(maxWidth: .infinity, alignment: .leading)

            if deletableTaskIds.contains(task.id) && !isLocked {
                Button(role: .destructive) {
                    delete(task)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var trimmedNewTaskText: String {
        newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addTask() {
        let text = trimmedNewTaskText
        guard !text.isEmpty else { return }
        let newTask = RecordingTaskEntity(text: text, isDone: false)
        entity.tasks.append(newTask)
        try? context.save()
        deletableTaskIds.insert(newTask.id)
        newTaskText = ""
    }

    private func delete(_ task: RecordingTaskEntity) {
        if let idx = entity.tasks.firstIndex(where: { $0.id == task.id }) {
            entity.tasks.remove(at: idx)
            context.delete(task)
            try? context.save()
        }
    }

    private func taskTextColor(task: RecordingTaskEntity, isLocked: Bool) -> Color {
        if isLocked { return task.isDone ? Color(red: 0.65, green: 0.95, blue: 0.35) : .red }
        return .white
    }

    private func deadlineSection(deadline: Date) -> some View {
        let remaining = max(0, deadline.timeIntervalSince(now))
        let lessThan1h = remaining < 3600

        if entity.deadlineDays != nil { // 日数モード
            return AnyView(
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("目標まで").foregroundStyle(.white).font(.headline)
                        let daysText = "\(entity.deadlineDays ?? 0)"
                        let daysMask = String(repeating: "8", count: daysText.count)
                        ZStack {
                            Text(daysMask)
                                .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 28))
                                .foregroundStyle(.black)
                            Text(daysText)
                                .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 28))
                                .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.35))
                        }
                        Text("日後").foregroundStyle(.white).font(.headline)
                    }
                    Text(formatDateOnly(deadline))
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            )
        } else if (entity.deadlineHours ?? 0) > 0 || (entity.deadlineMinutes ?? 0) > 0 { // 時間/分モード
            let textColor: Color = lessThan1h ? .red : .white
            return AnyView(
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("目標時刻まで").foregroundStyle(.white).font(.headline)
                        let timeText = lessThan1h ? formatMMSS(remaining) : formatHHMM(remaining)
                        let timeMask = String(timeText.map { $0 == ":" ? ":" : "8" })
                        ZStack {
                            Text(timeMask)
                                .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 28))
                                .foregroundStyle(.black)
                            Text(timeText)
                                .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 28))
                                .foregroundStyle(lessThan1h ? .red : Color(red: 0.65, green: 0.95, blue: 0.35))
                        }
                    }
                    Text(formatDateTime(deadline))
                        .font(.footnote)
                        .foregroundStyle(textColor.opacity(0.8))
                }
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    private func isExpired(for rec: RecordingEntity) -> Bool {
        guard let deadline = computeDeadline(for: rec) else { return false }
        return now >= deadline
    }

    private func computeDeadline(for rec: RecordingEntity) -> Date? {
        let base = rec.deadlineBaseAt ?? rec.answeredAt ?? rec.recordedAt
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

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    private func formatHHMM(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 3600, (s % 3600) / 60)
    }

    private func formatMMSS(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", (s / 60) % 60, s % 60)
    }

    private func timeString(_ sec: Double) -> String {
        let s = Int(sec)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func prepareRetryValues(currentDeadline: Date) {
        if entity.deadlineDays != nil {
            // 日時モード: 現在の締切日を初期値に設定
            retryDate = currentDeadline
        } else {
            // 時間・分モード: 現在の設定値を反映
            retryHours = entity.deadlineHours ?? 0
            retryMinutes = entity.deadlineMinutes ?? 0
        }
    }

    private func startRetryDeadline() {
        let nowBase = Date()
        if entity.deadlineDays != nil {
            // 日時モード: 選択された日付までの日数差を deadlineDays として設定
            let cal = Calendar.current
            let startOfToday = cal.startOfDay(for: nowBase)
            let startOfTarget = cal.startOfDay(for: retryDate)
            let diff = cal.dateComponents([.day], from: startOfToday, to: startOfTarget).day ?? 0
            let days = max(0, diff)
            entity.deadlineBaseAt = nowBase
            entity.deadlineDays = days
            entity.deadlineHours = nil
            entity.deadlineMinutes = nil
        } else {
            // 時間・分モード: 現在時刻を起点に再設定
            entity.deadlineBaseAt = nowBase
            entity.deadlineHours = retryHours
            entity.deadlineMinutes = retryMinutes
            entity.deadlineDays = nil
        }
        try? context.save()
        showRetrySheet = false
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

}

// MARK: - Icon dominant color helpers (container-level)
private extension HistoryDetailContainerView {
    /// 指定 ID の RecordingEntity から背景色を決定し、必要なら抽出して SwiftData にキャッシュしたうえで反映する
    func updateBackground(for recordingId: UUID, animated: Bool) {
        let newColor: Color?

        do {
            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == recordingId })
            if let rec = try context.fetch(fd).first {
                newColor = dominantColor(for: rec)
            } else {
                newColor = nil
            }
        } catch {
            newColor = nil
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.45)) {
                dominantBackground = newColor
            }
        } else {
            dominantBackground = newColor
        }
    }

    /// 個々の RecordingEntity から Color? を得る（キャッシュがあれば利用、無ければ抽出して保存）
    func dominantColor(for rec: RecordingEntity) -> Color? {
        // 1. キャッシュ（iconDominantColorHex）があればそれを使う
        if let hex = rec.iconDominantColorHex,
           let ui = color(fromHex: hex) {
            return Color(ui)
        }

        // 2. アイコン画像が無ければデフォルト背景（nil）を返す
        guard let data = rec.iconImageData,
              let uiImage = UIImage(data: data) else {
            return nil
        }

        // 3. 平均色を計算してキャッシュ＆保存
        guard let avg = averageColor(from: uiImage) else { return nil }
        let hex = hexString(from: avg)
        rec.iconDominantColorHex = hex
        try? context.save()
        return Color(avg)
    }

    func averageColor(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        // 小さくリサンプルして平均色を計算（パフォーマンス軽量）
        let targetSize = CGSize(width: 32, height: 32)
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

        guard let data = context.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        var totalR: Int = 0
        var totalG: Int = 0
        var totalB: Int = 0
        var count: Int = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + x * bytesPerPixel
                let r = Int(ptr[offset])
                let g = Int(ptr[offset + 1])
                let b = Int(ptr[offset + 2])
                let a = Int(ptr[offset + 3])

                // 完全に透過なピクセルは無視
                guard a > 0 else { continue }

                totalR += r
                totalG += g
                totalB += b
                count += 1
            }
        }

        guard count > 0 else { return nil }

        let avgR = CGFloat(totalR) / CGFloat(count) / 255.0
        let avgG = CGFloat(totalG) / CGFloat(count) / 255.0
        let avgB = CGFloat(totalB) / CGFloat(count) / 255.0

        return UIColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
    }

    func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    func color(fromHex hex: String) -> UIColor? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6,
              let value = Int(cleaned, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
