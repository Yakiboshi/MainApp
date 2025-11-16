import SwiftUI
import AVFAudio
import SwiftData
import Combine

struct HistoryDetailContainerView: View {
    @Environment(\.modelContext) private var context
    let recordingId: UUID

    var body: some View {
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
            Theme.appGradient.ignoresSafeArea()

            GeometryReader { proxy in
                let h = proxy.size.height
                let boxWidth = min(proxy.size.width - 40, 360) // 両端20ptの余白
                let topSpacing = h * 0.12

                VStack(spacing: 16) {
                    Spacer().frame(height: topSpacing)

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
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

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
                    .frame(maxWidth: .infinity, alignment: .center)

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
        .onDisappear {
            player.stop()
        }
        .onAppear {
            prepareDurationIfNeeded()
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
        guard let url = audioURL() else { return }
        player.playURL(url, loops: 0) {
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
                        Text("\(total)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Text("個のタスクがあります。")
                            .font(.headline)
                            .foregroundStyle(.white)
                        if remaining > 0 {
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
                        Text("\(entity.deadlineDays ?? 0)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.35))
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
                        Text(lessThan1h ? formatMMSS(remaining) : formatHHMM(remaining))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(lessThan1h ? .red : Color(red: 0.65, green: 0.95, blue: 0.35))
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
}
