import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct PlannedDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let entity: RecordingEntity

    // 編集用ステート（キャンセルで破棄される）
    @State private var title: String = ""
    @State private var scheduledAt: Date = .now
    @State private var iconImageData: Data? = nil
    @State private var afterMessage: String = ""
    @State private var linkInput: String = ""
    @State private var linkIsValidHTTPS: Bool = true

    private struct TaskDraft: Identifiable {
        var id: UUID
        var text: String
        var isDone: Bool
    }
    @State private var taskDrafts: [TaskDraft] = []

    enum DeadlineMode: String, CaseIterable { case hoursMinutes = "時間・分後", days = "日後" }
    @State private var deadlineMode: DeadlineMode = .hoursMinutes
    @State private var deadlineHours: Int = 0
    @State private var deadlineMinutes: Int = 0
    @State private var deadlineDays: Int = 0

    // アイコン用
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var cropTarget: CroppingImage?

    @State private var loaded: Bool = false

    private let actionBarHeight: CGFloat = 120
    private let titleLimit = 30
    private let memoLimit = 140

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView { contentStack }
                    // スクロール時にキーボードを閉じる
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            dismissKeyboard()
                        }
                    )

                // 下部固定バー（キャンセル / 完了）
                LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)], startPoint: .bottom, endPoint: .top)
                    .frame(height: actionBarHeight)
                    .overlay(
                        HStack(spacing: Theme.circleButtonSpacing) {
                            VStack(spacing: 6) {
                                Button {
                                    // 変更を破棄して閉じる
                                    dismiss()
                                } label: {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .foregroundStyle(.white)
                                                .font(Theme.circleButtonIconFont)
                                        )
                                }
                                Text("キャンセル")
                                    .font(Theme.circleButtonLabelFont)
                                    .foregroundStyle(.white.opacity(0.9))
                            }

                            VStack(spacing: 6) {
                                Button {
                                    saveAndClose()
                                } label: {
                                    Circle()
                                        .fill(Color.green.opacity(0.9))
                                        .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .font(Theme.circleButtonIconFont)
                                        )
                                }
                                .disabled(!isFutureDate || !isUniqueDate)
                                .opacity(isFutureDate && isUniqueDate ? 1.0 : 0.6)
                                Text("完了")
                                    .font(Theme.circleButtonLabelFont)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .padding(.bottom, 28)
                    )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // 背景タップでキーボードを閉じる
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyboard()
        }
        .onAppear { if !loaded { load() } }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content stack
    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: 20) {
            iconSection
            timeSection
            titleSection
            afterMemoSection
            urlSection
            tasksSection
            deadlineSection
            Spacer(minLength: actionBarHeight)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    // MARK: - Sections
    private var iconSection: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 120, height: 120)
                if let data = iconImageData, let ui = UIImage(data: data) {
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
                        .foregroundStyle(.white.opacity(0.6))
                }
                Button { showPhotoPicker = true } label: {
                    Image(systemName: "arrow.2.circlepath.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .offset(x: 40, y: 40)
                }
                .accessibilityLabel("アイコンを変更")
            }
            Text("アイコン（写真/撮影→トリミング）")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 24)
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    showPhotoPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        cropTarget = CroppingImage(image: ui)
                    }
                } else {
                    showPhotoPicker = false
                }
            }
        }
        .sheet(item: $cropTarget) { box in
            IconCropperSheet(image: box.image) { result in
                if let img = result, let data = img.pngData() {
                    iconImageData = data
                }
                cropTarget = nil
            }
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予定日時")
                .font(.headline)
                .foregroundStyle(.white)
            DatePicker(
                "",
                selection: $scheduledAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .tint(.white)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.15))
            )
            if !isFutureDate {
                Text("未来の時刻を入力してください")
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            } else if !isUniqueDate {
                Text("別の予定と同じ時刻は登録できません")
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("タイトル")
                .font(.headline)
                .foregroundStyle(.white)
            TextField(
                text: Binding(
                    get: { title },
                    set: { title = String($0.prefix(titleLimit)) }
                ),
                prompt: Text(defaultTitle()).foregroundColor(.secondary)
            ) {}
            .textFieldStyle(.plain)
            .foregroundStyle(.black)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
            HStack {
                Spacer()
                Text("\(title.count)/\(titleLimit)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var afterMemoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("アフターメモ")
                .font(.headline)
                .foregroundStyle(.white)
            ZStack(alignment: .topLeading) {
                if afterMessage.isEmpty {
                    Text("（\(scheduledLabel()) に送るメモ）")
                        .foregroundStyle(.gray.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
                TextEditor(
                    text: Binding(
                        get: { afterMessage },
                        set: { afterMessage = String($0.prefix(memoLimit)) }
                    )
                )
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                .foregroundStyle(.black)
            }
            HStack {
                Spacer()
                Text("\(afterMessage.count)/\(memoLimit)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL（任意・https:// のみ）")
                .font(.headline)
                .foregroundStyle(.white)
            TextField(
                text: Binding(
                    get: { linkInput },
                    set: { newVal in
                        linkInput = newVal
                        let trimmed = newVal.trimmingCharacters(in: .whitespaces)
                        linkIsValidHTTPS = trimmed.isEmpty || trimmed.hasPrefix("https://")
                    }
                ),
                prompt: Text("https://example.com").foregroundColor(.secondary)
            ) {}
            .textFieldStyle(.roundedBorder)

            if !linkIsValidHTTPS {
                Text("URLは https:// で始めてください")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ToDo")
                .font(.headline)
                .foregroundStyle(.white)
            if taskDrafts.isEmpty {
                Button(action: { addTask() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("タスクを追加")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                            .foregroundColor(.white)
                    )
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(taskDrafts) { task in
                        HStack(alignment: .top, spacing: 8) {
                            TextField(
                                "タスク",
                                text: Binding(
                                    get: { task.text },
                                    set: { newVal in
                                        if let idx = taskDrafts.firstIndex(where: { $0.id == task.id }) {
                                            taskDrafts[idx].text = String(newVal.prefix(120))
                                        }
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(.black)
                            Button(role: .destructive) {
                                removeTask(task)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    Button(action: { addTask() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                            Text("タスクを追加")
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundColor(.white)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deadlineSection: some View {
        if !taskDrafts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("全タスクの締切設定")
                    .font(.headline)
                    .foregroundStyle(.white)
                Picker("モード", selection: $deadlineMode) {
                    Text(DeadlineMode.hoursMinutes.rawValue).tag(DeadlineMode.hoursMinutes)
                    Text(DeadlineMode.days.rawValue).tag(DeadlineMode.days)
                }
                .pickerStyle(.segmented)
                .tint(.white)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.12)))

                if deadlineMode == .hoursMinutes {
                    HStack {
                        Text("\(deadlineHours) 時間")
                            .foregroundStyle(.white)
                        Spacer()
                        Stepper("", value: $deadlineHours, in: 0...72)
                            .labelsHidden()
                            .tint(.white)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                    }
                    HStack {
                        Text("\(deadlineMinutes) 分")
                            .foregroundStyle(.white)
                        Spacer()
                        Stepper("", value: $deadlineMinutes, in: 0...59)
                            .labelsHidden()
                            .tint(.white)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                    }
                } else {
                    HStack {
                        Text("\(deadlineDays) 日後")
                            .foregroundStyle(.white)
                        Spacer()
                        Stepper("", value: $deadlineDays, in: 0...60)
                            .labelsHidden()
                            .tint(.white)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                    }
                }
            }
        }
    }

    // MARK: - Load / Save
    private func load() {
        loaded = true
        title = entity.title ?? ""
        scheduledAt = entity.recordedAt
        iconImageData = entity.iconImageData
        afterMessage = entity.afterMessage ?? ""
        linkInput = entity.linkURLString ?? ""
        linkIsValidHTTPS = linkInput.trimmingCharacters(in: .whitespaces).isEmpty || linkInput.hasPrefix("https://")

        taskDrafts = entity.tasks.map { TaskDraft(id: $0.id, text: $0.text, isDone: $0.isDone) }

        if let d = entity.deadlineDays, d > 0 {
            deadlineMode = .days
            deadlineDays = d
            deadlineHours = 0
            deadlineMinutes = 0
        } else {
            deadlineMode = .hoursMinutes
            deadlineHours = entity.deadlineHours ?? 0
            deadlineMinutes = entity.deadlineMinutes ?? 0
            deadlineDays = 0
        }
    }

    private func saveAndClose() {
        guard isFutureDate, isUniqueDate else { return }

        // タイトル
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            t = defaultTitle()
        }
        entity.title = t

        // 予定日時
        if entity.recordedAt != scheduledAt {
            entity.recordedAt = scheduledAt
            entity.isSnoozed = false
            NotificationManager.shared.cancelAllNotifications(for: entity.id.uuidString)
            // 予定変更に合わせてバッジベースと通知キューを再構築
            _ = AppBadgeManager.refresh(using: context)
            LocalNotificationManager.shared.refreshAllNotifications(in: context)
        }

        // アイコン
        entity.iconImageData = iconImageData

        // アフターメモ
        let trimmedMemo = afterMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.afterMessage = trimmedMemo.isEmpty ? nil : trimmedMemo

        // URL
        let trimmedURL = linkInput.trimmingCharacters(in: .whitespaces)
        if trimmedURL.isEmpty {
            entity.linkURLString = nil
        } else if trimmedURL.hasPrefix("https://") {
            entity.linkURLString = trimmedURL
        }

        // タスク適用
        applyTaskDrafts()

        // 締切
        switch deadlineMode {
        case .hoursMinutes:
            entity.deadlineHours = deadlineHours
            entity.deadlineMinutes = deadlineMinutes
            entity.deadlineDays = nil
        case .days:
            entity.deadlineDays = deadlineDays
            entity.deadlineHours = nil
            entity.deadlineMinutes = nil
        }

        try? context.save()
        dismiss()
    }

    private func applyTaskDrafts() {
        // 既存タスクを削除してドラフトから再構築
        for task in entity.tasks {
            context.delete(task)
        }
        entity.tasks.removeAll()

        for draft in taskDrafts {
            let newTask = RecordingTaskEntity(id: draft.id, text: draft.text, isDone: draft.isDone)
            entity.tasks.append(newTask)
        }
    }

    private func addTask() {
        taskDrafts.append(TaskDraft(id: UUID(), text: "", isDone: false))
    }

    private func removeTask(_ task: TaskDraft) {
        taskDrafts.removeAll { $0.id == task.id }
    }

    private func defaultTitle() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return "\(f.string(from: scheduledAt)) からの電話"
    }

    private func scheduledLabel() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return scheduledAt > .now ? f.string(from: scheduledAt) : f.string(from: entity.recordedAt)
    }
}

private extension PlannedDetailView {
    var isFutureDate: Bool { scheduledAt > Date() }

    var isUniqueDate: Bool {
        do {
            let fd = FetchDescriptor<RecordingEntity>()
            let items = try context.fetch(fd)
            return !items.contains {
                $0.id != entity.id &&
                ($0.status ?? "scheduled") == "scheduled" &&
                $0.recordedAt == scheduledAt
            }
        } catch {
            return true
        }
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
