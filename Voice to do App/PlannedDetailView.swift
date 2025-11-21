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
    @State private var showUrlPresetPicker: Bool = false
    @State private var showTaskPresetPicker: Bool = false

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

    @Query private var urlPresets: [UrlPresetEntity]
    @Query private var taskPresets: [TaskPresetEntity]

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
                                    .foregroundStyle(Theme.secondaryText)
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
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        .padding(.bottom, 28)
                    )
            }
            .ignoresSafeArea(edges: .bottom)

            if showUrlPresetPicker {
                urlPresetOverlay
                    .transition(.move(edge: .bottom))
            }
            if showTaskPresetPicker {
                taskPresetOverlay
                    .transition(.move(edge: .bottom))
            }
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
            snoozeSection
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
                if let data = iconImageData ?? DefaultIconStore.load(),
                   let ui = UIImage(data: data) {
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
                        .foregroundStyle(Theme.isSingularity ? .black.opacity(0.6) : .white.opacity(0.6))
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
                .foregroundStyle(Theme.primaryText)
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

    private var snoozeSection: some View {
        let total = max(entity.snoozeMin ?? SortPreference.loadDefaultSnoozeMinutes(), 0)
        let days = max(0, min(7, total / (24 * 60)))
        let hours = max(0, min(23, (total % (24 * 60)) / 60))
        let mins = max(0, min(59, total % 60))
        return VStack(alignment: .leading, spacing: 8) {
            Text("スヌーズ時間")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            Text("この予定のスヌーズ時間（日・時間・分）")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            HStack(alignment: .center, spacing: 16) {
                VStack {
                    Text("日")
                        .foregroundStyle(Theme.secondaryText)
                        .font(.caption)
                    Picker(
                        "",
                        selection: Binding(
                            get: { days },
                            set: { newValue in
                                let clamped = max(0, min(7, newValue))
                                let current = entity.snoozeMin ?? SortPreference.loadDefaultSnoozeMinutes()
                                let currentHours = max(0, min(23, (current % (24 * 60)) / 60))
                                let currentMins = max(0, min(59, current % 60))
                                entity.snoozeMin = clamped * 24 * 60 + currentHours * 60 + currentMins
                            }
                        )
                    ) {
                        ForEach(0...7, id: \.self) { v in
                            Text("\(v)").foregroundStyle(Theme.primaryText).tag(v)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 100)
                }
                VStack {
                    Text("時間")
                        .foregroundStyle(Theme.secondaryText)
                        .font(.caption)
                    Picker(
                        "",
                        selection: Binding(
                            get: {
                                let current = entity.snoozeMin ?? SortPreference.loadDefaultSnoozeMinutes()
                                return max(0, min(23, (current % (24 * 60)) / 60))
                            },
                            set: { newValue in
                                let clamped = max(0, min(23, newValue))
                                let current = entity.snoozeMin ?? SortPreference.loadDefaultSnoozeMinutes()
                                let currentDays = max(0, min(7, current / (24 * 60)))
                                let currentMins = max(0, min(59, current % 60))
                                entity.snoozeMin = currentDays * 24 * 60 + clamped * 60 + currentMins
                            }
                        )
                    ) {
                        ForEach(0...23, id: \.self) { v in
                            Text("\(v)").foregroundStyle(Theme.primaryText).tag(v)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 100)
                }
                VStack {
                    Text("分")
                        .foregroundStyle(Theme.secondaryText)
                        .font(.caption)
                    Picker(
                        "",
                        selection: Binding(
                            get: {
                                let current = entity.snoozeMin ?? SortPreference.loadDefaultSnoozeMinutes()
                                return max(0, min(59, current % 60))
                            },
                            set: { newValue in
                                let clamped = max(0, min(59, newValue))
                                let current = entity.snoozeMin ?? SortPreference.loadDefaultSnoozeMinutes()
                                let currentDays = max(0, min(7, current / (24 * 60)))
                                let currentHours = max(0, min(23, (current % (24 * 60)) / 60))
                                entity.snoozeMin = currentDays * 24 * 60 + currentHours * 60 + clamped
                            }
                        )
                    ) {
                        ForEach(0...59, id: \.self) { v in
                            Text("\(v)").foregroundStyle(Theme.primaryText).tag(v)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 100)
                }
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("タイトル")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            TextField(
                text: Binding(
                    get: { title },
                    set: { title = String($0.prefix(titleLimit)) }
                ),
                prompt: Text(defaultTitle()).foregroundColor(.secondary)
            ) {}
            .textFieldStyle(.plain)
            .foregroundStyle(Theme.inputFieldText)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.inputFieldBackground))
            HStack {
                Spacer()
                Text("\(title.count)/\(titleLimit)")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var afterMemoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("アフターメモ")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
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
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.inputFieldBackground))
                .foregroundStyle(Theme.inputFieldText)
            }
            HStack {
                Spacer()
                Text("\(afterMessage.count)/\(memoLimit)")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("URL（任意・https:// のみ）")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                if !urlPresets.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showUrlPresetPicker = true
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(Theme.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.inputFieldBackground))
            .foregroundStyle(Theme.inputFieldText)

            if !linkIsValidHTTPS {
                Text("URLは https:// で始めてください")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
            Text("ToDo")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
                Spacer()
                if !taskPresets.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            showTaskPresetPicker = true
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(Theme.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            if taskDrafts.isEmpty {
                Button(action: { addTask() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("タスクを追加")
                    }
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.clear)
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.inputFieldBackground))
                            .foregroundStyle(Theme.inputFieldText)
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
                        .foregroundStyle(Theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.clear)
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
                    .foregroundStyle(Theme.primaryText)
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
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Stepper("", value: $deadlineHours, in: 0...72)
                            .labelsHidden()
                            .tint(.white)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                    }
                    HStack {
                        Text("\(deadlineMinutes) 分")
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Stepper("", value: $deadlineMinutes, in: 0...59)
                            .labelsHidden()
                            .tint(.white)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                    }
                } else {
                    HStack {
                        Text("\(deadlineDays) 日後")
                            .foregroundStyle(Theme.primaryText)
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

    // MARK: - URL / タスクプリセット選択用小ウィンドウ
    private var urlPresetOverlay: some View {
        ZStack {
            // 外側タップで閉じる透明オーバーレイ
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        showUrlPresetPicker = false
                    }
                }

            GeometryReader { geo in
                let height = geo.size.height
                let topY = height * 0.55

                VStack {
                    Spacer()
                    ZStack {
                        // 半透明の黄緑グラデーション（下部ほど暗く）
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.9, blue: 0.3).opacity(0.8),
                                Color(red: 0.25, green: 0.5, blue: 0.15).opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.0),
                                    Color.black.opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        ScrollView(showsIndicators: true) {
                            VStack(spacing: 0) {
                                ForEach(urlPresets.sorted(by: { $0.createdAt < $1.createdAt })) { preset in
                                    Button {
                                        applyUrlPreset(preset)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            showUrlPresetPicker = false
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preset.title)
                                                .foregroundStyle(.white)
                                                .font(.body)
                                            Text(preset.urlString)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.85))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Rectangle()
                                        .fill(Color.white.opacity(0.28))
                                        .frame(height: 1)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    .frame(height: height - topY)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geo.size.width, height: height, alignment: .bottom)
            }
        }
    }

    @ViewBuilder
    private var taskPresetOverlay: some View {
        ZStack {
            // 外側タップで閉じる透明オーバーレイ
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        showTaskPresetPicker = false
                    }
                }

            GeometryReader { geo in
                let height = geo.size.height
                let topY = height * 0.55

                VStack {
                    Spacer()
                    ZStack {
                        // 半透明の水色グラデーション（下側ほど暗く）
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.8, blue: 0.95).opacity(0.8),
                                Color(red: 0.15, green: 0.45, blue: 0.6).opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.0),
                                    Color.black.opacity(0.35)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        ScrollView(showsIndicators: true) {
                            VStack(spacing: 0) {
                                ForEach(taskPresets.sorted(by: { $0.createdAt < $1.createdAt })) { preset in
                                    Button {
                                        applyTaskPreset(preset)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            showTaskPresetPicker = false
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preset.title)
                                                .foregroundStyle(.white)
                                                .font(.body)
                                            if !preset.items.isEmpty {
                                                Text("\(preset.items.count) 件のタスク")
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.85))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Rectangle()
                                        .fill(Color.white.opacity(0.28))
                                        .frame(height: 1)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    .frame(height: height - topY)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geo.size.width, height: height, alignment: .bottom)
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

        // スヌーズ時間が 0 分になっている場合は 5 分として保存する
        if let snooze = entity.snoozeMin, snooze <= 0 {
            entity.snoozeMin = 5
        }

        try? context.save()
        dismiss()
    }

    private func applyUrlPreset(_ preset: UrlPresetEntity) {
        let url = preset.urlString
        linkInput = url
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        linkIsValidHTTPS = trimmed.isEmpty || trimmed.hasPrefix("https://")
    }

    private func applyTaskPreset(_ preset: TaskPresetEntity) {
        // プリセットのタスクをドラフトに反映
        let drafts = preset.items.map { item in
            TaskDraft(id: UUID(), text: item.text, isDone: false)
        }
        taskDrafts = drafts

        // 締切もあれば適用（任意）
        if let d = preset.deadlineDays, d > 0 {
            deadlineMode = .days
            deadlineDays = d
            deadlineHours = 0
            deadlineMinutes = 0
        } else {
            deadlineMode = .hoursMinutes
            deadlineHours = preset.deadlineHours ?? 0
            deadlineMinutes = preset.deadlineMinutes ?? 0
            deadlineDays = 0
        }
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
