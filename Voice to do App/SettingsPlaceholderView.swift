import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct SettingsPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var autoYear: Bool = SortPreference.loadAutoYear()
    @State private var autoMonth: Bool = SortPreference.loadAutoMonth()
    @State private var isShowingSoundSheet: Bool = false
    @State private var defaultSnoozeMinutes: Int = SortPreference.loadDefaultSnoozeMinutes()
    @State private var recordingMaxMinutes: Int = SortPreference.loadRecordingMaxMinutes()
    @State private var maxFutureYears: Int = SortPreference.loadMaxFutureYears()
    @State private var playbackVolumeSlider: Double = Double(SortPreference.loadPlaybackVolumeSlider())
    @State private var defaultIconImageData: Data? = nil
    @State private var showDefaultIconPhotoPicker: Bool = false
    @State private var defaultIconPickedItem: PhotosPickerItem?
    @State private var defaultIconCropTarget: CroppingImage?
    @State private var showPresetDateOptionSheet: Bool = false
    @State private var showPresetDateDeleteSheet: Bool = false
    @State private var showUrlPresetSheet: Bool = false
    @State private var showUrlPresetDeleteSheet: Bool = false
    @State private var showTaskPresetSheet: Bool = false
    @State private var showTaskPresetDeleteSheet: Bool = false

    @Query(sort: \SoundFile.createdAt, order: .reverse) private var soundFiles: [SoundFile]

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                // ヘッダー
                VStack {
                    HStack {
                        Text("アプリ設定")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 16)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)

                // 本文（スクロール可能）
                ScrollView {
                    VStack(spacing: 16) {
                        settingToggleRow(
                            title: "固定 年 を追加",
                            isOn: $autoYear
                        )
                        settingToggleRow(
                            title: "固定 月 を追加",
                            isOn: $autoMonth
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            Text("着信音")
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(currentSoundDisplayName)
                                .foregroundStyle(Color.white.opacity(0.9))
                                .font(.subheadline)
                            Button("着信音を変更") {
                                isShowingSoundSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white.opacity(0.15))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        // デフォルトスヌーズ時間（日・時間・分）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("デフォルトスヌーズ時間")
                                .foregroundStyle(Color.white)
                            Text("詳細設定画面のスヌーズ初期値（日・時間・分）")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            let total = defaultSnoozeMinutes
                            let days = max(0, min(7, total / (24 * 60)))
                            let hours = max(0, min(23, (total % (24 * 60)) / 60))
                            let mins = max(0, min(59, total % 60))
                            HStack(alignment: .center, spacing: 16) {
                                VStack {
                                    Text("日")
                                        .foregroundStyle(.white.opacity(0.8))
                                        .font(.caption)
                                    Picker(
                                        "",
                                        selection: Binding(
                                            get: { days },
                                            set: { newValue in
                                                let clamped = max(0, min(7, newValue))
                                                let currentHours = max(0, min(23, (defaultSnoozeMinutes % (24 * 60)) / 60))
                                                let currentMins = max(0, min(59, defaultSnoozeMinutes % 60))
                                                defaultSnoozeMinutes = clamped * 24 * 60 + currentHours * 60 + currentMins
                                            }
                                        )
                                    ) {
                                        ForEach(0...7, id: \.self) { v in
                                            Text("\(v)").foregroundStyle(.white).tag(v)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.wheel)
                                    .frame(maxHeight: 100)
                                }
                                VStack {
                                    Text("時間")
                                        .foregroundStyle(.white.opacity(0.8))
                                        .font(.caption)
                                    Picker(
                                        "",
                                        selection: Binding(
                                            get: { hours },
                                            set: { newValue in
                                                let clamped = max(0, min(23, newValue))
                                                let currentDays = max(0, min(7, defaultSnoozeMinutes / (24 * 60)))
                                                let currentMins = max(0, min(59, defaultSnoozeMinutes % 60))
                                                defaultSnoozeMinutes = currentDays * 24 * 60 + clamped * 60 + currentMins
                                            }
                                        )
                                    ) {
                                        ForEach(0...23, id: \.self) { v in
                                            Text("\(v)").foregroundStyle(.white).tag(v)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.wheel)
                                    .frame(maxHeight: 100)
                                }
                                VStack {
                                    Text("分")
                                        .foregroundStyle(.white.opacity(0.8))
                                        .font(.caption)
                                    Picker(
                                        "",
                                        selection: Binding(
                                            get: { mins },
                                            set: { newValue in
                                                let clamped = max(0, min(59, newValue))
                                                let currentDays = max(0, min(7, defaultSnoozeMinutes / (24 * 60)))
                                                let currentHours = max(0, min(23, (defaultSnoozeMinutes % (24 * 60)) / 60))
                                                defaultSnoozeMinutes = currentDays * 24 * 60 + currentHours * 60 + clamped
                                            }
                                        )
                                    ) {
                                        ForEach(0...59, id: \.self) { v in
                                            Text("\(v)").foregroundStyle(.white).tag(v)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.wheel)
                                    .frame(maxHeight: 100)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        // デフォルトアイコン設定
                        VStack(alignment: .leading, spacing: 8) {
                            Text("デフォルトアイコン")
                                .foregroundStyle(Color.white)
                            Text("アイコン未設定の録音で使用する画像")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(width: 70, height: 70)
                                    if let data = defaultIconImageData,
                                       let ui = UIImage(data: data) {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 68, height: 68)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                Spacer()
                                Button("アイコンを変更") {
                                    showDefaultIconPhotoPicker = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.white.opacity(0.2))
                                if defaultIconImageData != nil {
                                    Button("クリア") {
                                        defaultIconImageData = nil
                                        DefaultIconStore.save(nil)
                                    }
                                    .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        // 録音上限時間
                        VStack(alignment: .leading, spacing: 8) {
                            Text("録音上限時間")
                                .foregroundStyle(Color.white)
                            Text("録音画面の最大録音時間（1〜60分）")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack {
                                Stepper(
                                    value: $recordingMaxMinutes,
                                    in: 1...60,
                                    step: 1
                                ) {
                                    Text("\(recordingMaxMinutes) 分")
                                        .foregroundStyle(Color.white)
                                }
                                .tint(.white)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        // 最高未来時刻
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最高未来時刻")
                                .foregroundStyle(Color.white)
                            Text("登録できる未来の上限（1〜10年）")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack {
                                Stepper(
                                    value: $maxFutureYears,
                                    in: 1...10,
                                    step: 1
                                ) {
                                    Text("\(maxFutureYears) 年先まで")
                                        .foregroundStyle(Color.white)
                                }
                                .tint(.white)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        // 録音音声再生時の音量
                        VStack(alignment: .leading, spacing: 8) {
                            Text("録音音声再生時の音量")
                                .foregroundStyle(Color.white)
                            Text("詳細プレビュー・通話・通話後・履歴再生の音量")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack {
                                Slider(
                                    value: $playbackVolumeSlider,
                                    in: 0...100,
                                    step: 1
                                ) { editing in
                                    if !editing {
                                        let intValue = Int(playbackVolumeSlider.rounded())
                                        SortPreference.savePlaybackVolumeSlider(intValue)
                                    }
                                }
                                .tint(.white)
                                Text("\(Int(playbackVolumeSlider))")
                                    .foregroundStyle(Color.white)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                        .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                        // プリセット・日付の追加選択肢
                        VStack(alignment: .leading, spacing: 8) {
                            Text("プリセット・日付の追加選択肢")
                                .foregroundStyle(Color.white)
                            Text("キーパッド画面のプリセットに出す相対時刻（日付）を追加")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack(spacing: 12) {
                                Button {
                                    showPresetDateOptionSheet = true
                                } label: {
                                    Text("選択肢を追加…")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.18))
                                        )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showPresetDateDeleteSheet = true
                                } label: {
                                    Text("削除…")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        // URLプリセット
                        VStack(alignment: .leading, spacing: 8) {
                            Text("URLプリセット")
                                .foregroundStyle(Color.white)
                            Text("詳細設定画面のURL欄に挿入できるプリセット")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack(spacing: 12) {
                                Button {
                                    showUrlPresetSheet = true
                                } label: {
                                    Text("URLを追加…")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.18))
                                        )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showUrlPresetDeleteSheet = true
                                } label: {
                                    Text("削除…")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        // タスクプリセット
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タスクプリセット")
                                .foregroundStyle(Color.white)
                            Text("詳細設定画面のToDoと締切に挿入できるプリセット")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack(spacing: 12) {
                                Button {
                                    showTaskPresetSheet = true
                                } label: {
                                    Text("タスクを追加…")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.18))
                                        )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showTaskPresetDeleteSheet = true
                                } label: {
                                    Text("削除…")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: autoYear) { newValue in
            SortPreference.saveAutoYear(newValue)
            if !newValue, autoMonth {
                autoMonth = false
                SortPreference.saveAutoMonth(false)
            }
        }
        .onChange(of: autoMonth) { newValue in
            SortPreference.saveAutoMonth(newValue)
            if newValue, !autoYear {
                autoYear = true
                SortPreference.saveAutoYear(true)
            }
        }
        .onChange(of: defaultSnoozeMinutes) { newValue in
            SortPreference.saveDefaultSnoozeMinutes(newValue)
        }
        .onChange(of: recordingMaxMinutes) { newValue in
            SortPreference.saveRecordingMaxMinutes(newValue)
        }
        .onChange(of: maxFutureYears) { newValue in
            SortPreference.saveMaxFutureYears(newValue)
        }
        .sheet(isPresented: $isShowingSoundSheet) {
            SoundSettingSheet()
        }
        .photosPicker(
            isPresented: $showDefaultIconPhotoPicker,
            selection: $defaultIconPickedItem,
            matching: .images
        )
        .onChange(of: defaultIconPickedItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    showDefaultIconPhotoPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        defaultIconCropTarget = CroppingImage(image: ui)
                    }
                } else {
                    showDefaultIconPhotoPicker = false
                }
            }
        }
        .sheet(item: $defaultIconCropTarget) { box in
            IconCropperSheet(image: box.image) { result in
                if let img = result, let data = img.pngData() {
                    defaultIconImageData = data
                    DefaultIconStore.save(data)
                }
                defaultIconCropTarget = nil
            }
        }
        .onAppear {
            if defaultIconImageData == nil {
                defaultIconImageData = DefaultIconStore.load()
            }
        }
        .sheet(isPresented: $showPresetDateOptionSheet) {
            PresetDateOptionSheet()
        }
        .sheet(isPresented: $showPresetDateDeleteSheet) {
            PresetDateOptionDeleteSheet()
        }
        .sheet(isPresented: $showUrlPresetSheet) {
            UrlPresetSheet()
        }
        .sheet(isPresented: $showUrlPresetDeleteSheet) {
            UrlPresetDeleteSheet()
        }
        .sheet(isPresented: $showTaskPresetSheet) {
            TaskPresetSheet()
        }
        .sheet(isPresented: $showTaskPresetDeleteSheet) {
            TaskPresetDeleteSheet()
        }
    }
}

private extension SettingsPlaceholderView {
    func settingToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: isOn.onChange { newValue in
                // 保存などの副作用は View 本体側の .onChange で処理
            })
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .white))
            .frame(width: 60, alignment: .trailing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

private extension SettingsPlaceholderView {
    var currentSoundDisplayName: String {
        if let sound = soundFiles.first {
            return sound.fileName
        }
        return "デフォルト"
    }
}

// MARK: - プリセット用 日付オプション追加シート
private struct PresetDateOptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    enum Mode {
        case hour, day
    }

    @State private var mode: Mode = .hour
    @State private var selectedHour: Double = 1.0
    @State private var selectedDay: Int = 8

    private var hourOptions: [Double] {
        stride(from: 0.5, through: 24.0, by: 0.5).map { Double($0) }
    }

    private var bodyBackground: some View {
        Theme.appGradient
            .ignoresSafeArea()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bodyBackground
                VStack(spacing: 16) {
                    Picker("種類", selection: $mode) {
                        Text("時間後").tag(Mode.hour)
                        Text("日後").tag(Mode.day)
                    }
                    .pickerStyle(.segmented)
                    .tint(.white)

                    if mode == .hour {
                        VStack {
                            Text("何時間後かを選択")
                                .foregroundStyle(.white)
                            Picker("", selection: $selectedHour) {
                                ForEach(hourOptions, id: \.self) { v in
                                    let label = v.truncatingRemainder(dividingBy: 1.0) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
                                    Text(label).foregroundStyle(.white).tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxHeight: 140)
                        }
                    } else {
                        VStack {
                            Text("何日後かを選択")
                                .foregroundStyle(.white)
                            Picker("", selection: $selectedDay) {
                                ForEach(8...365, id: \.self) { v in
                                    Text("\(v)").foregroundStyle(.white).tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxHeight: 140)
                        }
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("日付プリセット追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addPreset()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .interactiveDismissDisabled(false)
    }

    private func addPreset() {
        switch mode {
        case .hour:
            let hours = selectedHour
            let title: String = {
                let label = hours.truncatingRemainder(dividingBy: 1.0) == 0 ? String(format: "%.0f", hours) : String(format: "%.1f", hours)
                return "\(label)時間後"
            }()
            let entity = RelativeDatePresetEntity(
                title: title,
                isHourBased: true,
                hours: hours,
                days: nil
            )
            context.insert(entity)
            try? context.save()
        case .day:
            let days = selectedDay
            let title = "\(days)日後"
            let entity = RelativeDatePresetEntity(
                title: title,
                isHourBased: false,
                hours: nil,
                days: days
            )
            context.insert(entity)
            try? context.save()
        }
        dismiss()
    }
}

// 追加済みの日付プリセットを削除するためのシート
private struct PresetDateOptionDeleteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var relativePresets: [RelativeDatePresetEntity]
    @State private var confirmTarget: RelativeDatePresetEntity? = nil
    @State private var showConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    if relativePresets.isEmpty {
                        Text("追加された選択肢はありません")
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        List {
                            ForEach(relativePresets) { preset in
                                Button {
                                    confirmTarget = preset
                                    showConfirm = true
                                } label: {
                                    HStack {
                                        Text(preset.title)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if preset.isHourBased, let h = preset.hours {
                                            Text(String(format: "+%.1fh", h))
                                                .foregroundStyle(.white.opacity(0.7))
                                                .font(.caption)
                                        } else if let d = preset.days {
                                            Text("+\(d)d")
                                                .foregroundStyle(.white.opacity(0.7))
                                                .font(.caption)
                                        }
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle("選択肢を削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .alert("削除しますか", isPresented: $showConfirm, presenting: confirmTarget) { target in
                Button("はい", role: .destructive) {
                    context.delete(target)
                    try? context.save()
                }
                Button("いいえ", role: .cancel) { }
            } message: { _ in
                Text("このプリセットを削除してよろしいですか？")
            }
        }
    }
}

// MARK: - URLプリセット追加・削除シート
private struct UrlPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title: String = ""
    @State private var urlInput: String = ""
    @State private var isValidHTTPS: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                Form {
                    Section(header: Text("タイトル").foregroundColor(.white)) {
                        TextField("プリセット名（必須）", text: $title)
                            .foregroundColor(.black)
                    }
                    Section(header: Text("URL（https:// のみ）").foregroundColor(.white)) {
                        TextField("https://example.com", text: $urlInput)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundColor(.black)
                            .onChange(of: urlInput) { newVal in
                                let trimmed = newVal.trimmingCharacters(in: .whitespaces)
                                isValidHTTPS = trimmed.isEmpty || trimmed.hasPrefix("https://")
                            }
                        if !isValidHTTPS {
                            Text("URLは https:// で始めてください")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("URLプリセットを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { addPreset() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func addPreset() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              !trimmedURL.isEmpty,
              trimmedURL.hasPrefix("https://") else { return }

        let entity = UrlPresetEntity(title: trimmedTitle, urlString: trimmedURL)
        context.insert(entity)
        try? context.save()
        dismiss()
    }
}

private struct UrlPresetDeleteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var presets: [UrlPresetEntity]
    @State private var confirmTarget: UrlPresetEntity? = nil
    @State private var showConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    if presets.isEmpty {
                        Text("追加されたURLプリセットはありません")
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        List {
                            ForEach(presets.sorted(by: { $0.createdAt < $1.createdAt })) { preset in
                                Button {
                                    confirmTarget = preset
                                    showConfirm = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.title)
                                            .foregroundStyle(.white)
                                        Text(preset.urlString)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle("URLプリセット削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .alert("削除しますか", isPresented: $showConfirm, presenting: confirmTarget) { target in
                Button("はい", role: .destructive) {
                    context.delete(target)
                    try? context.save()
                }
                Button("いいえ", role: .cancel) {}
            } message: { _ in
                Text("このURLプリセットを削除してよろしいですか？")
            }
        }
    }
}

// MARK: - タスクプリセット追加・削除シート
private struct TaskPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private struct TaskDraft: Identifiable {
        let id: UUID
        var text: String
    }

    enum DeadlineMode: String, CaseIterable { case hoursMinutes = "時間・分後", days = "日後" }

    @State private var title: String = ""
    @State private var tasks: [TaskDraft] = [TaskDraft(id: UUID(), text: "")]
    @State private var deadlineMode: DeadlineMode = .hoursMinutes
    @State private var deadlineHours: Int = 0
    @State private var deadlineMinutes: Int = 0
    @State private var deadlineDays: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // タイトル
                        VStack(alignment: .leading, spacing: 6) {
                            Text("タイトル")
                                .foregroundStyle(.white)
                            TextField("プリセット名（必須）", text: $title)
                                .foregroundColor(.black)
                                .textFieldStyle(.roundedBorder)
                        }

                        // タスク一覧
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ToDo")
                                .foregroundStyle(.white)
                            if tasks.isEmpty {
                                Button {
                                    tasks.append(TaskDraft(id: UUID(), text: ""))
                                } label: {
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
                                    ForEach(tasks) { task in
                                        HStack(alignment: .top, spacing: 8) {
                                            TextField(
                                                "タスク",
                                                text: Binding(
                                                    get: {
                                                        task.text
                                                    },
                                                    set: { newVal in
                                                        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                                                            tasks[idx].text = String(newVal.prefix(120))
                                                        }
                                                    }
                                                )
                                            )
                                            .textFieldStyle(.roundedBorder)
                                            .foregroundColor(.black)
                                            Button(role: .destructive) {
                                                tasks.removeAll { $0.id == task.id }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                        }
                                    }
                                    Button {
                                        tasks.append(TaskDraft(id: UUID(), text: ""))
                                    } label: {
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

                        // 締切（任意）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("全タスクの締切設定（任意）")
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
                                    Stepper("", value: $deadlineHours, in: 0...168)
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
                                    Stepper("", value: $deadlineDays, in: 0...365)
                                        .labelsHidden()
                                        .tint(.white)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.15)))
                                }
                            }
                        }

                        Spacer(minLength: 40) // 一番下に余白を設ける
                    }
                    .padding()
                }
            }
            .navigationTitle("タスクプリセットを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { addPreset() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func addPreset() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskTexts = tasks.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmedTitle.isEmpty, !taskTexts.isEmpty else { return }

        let preset = TaskPresetEntity(
            title: trimmedTitle,
            deadlineHours: deadlineMode == .hoursMinutes ? (deadlineHours > 0 ? deadlineHours : nil) : nil,
            deadlineMinutes: deadlineMode == .hoursMinutes ? (deadlineMinutes > 0 ? deadlineMinutes : nil) : nil,
            deadlineDays: deadlineMode == .days ? (deadlineDays > 0 ? deadlineDays : nil) : nil
        )

        for text in taskTexts {
            let item = TaskPresetItemEntity(text: text)
            preset.items.append(item)
        }

        context.insert(preset)
        try? context.save()
        dismiss()
    }
}

private struct TaskPresetDeleteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var presets: [TaskPresetEntity]
    @State private var confirmTarget: TaskPresetEntity? = nil
    @State private var showConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    if presets.isEmpty {
                        Text("追加されたタスクプリセットはありません")
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        List {
                            ForEach(presets.sorted(by: { $0.createdAt < $1.createdAt })) { preset in
                                Button {
                                    confirmTarget = preset
                                    showConfirm = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.title)
                                            .foregroundStyle(.white)
                                        if !preset.items.isEmpty {
                                            Text("\(preset.items.count) 件のタスク")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                    }
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle("タスクプリセット削除")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .alert("削除しますか", isPresented: $showConfirm, presenting: confirmTarget) { target in
                Button("はい", role: .destructive) {
                    context.delete(target)
                    try? context.save()
                }
                Button("いいえ", role: .cancel) {}
            } message: { _ in
                Text("このタスクプリセットを削除してよろしいですか？")
            }
        }
    }
}
