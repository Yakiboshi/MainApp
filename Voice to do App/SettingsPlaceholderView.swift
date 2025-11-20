import SwiftUI
import SwiftData

struct SettingsPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var autoYear: Bool = SortPreference.loadAutoYear()
    @State private var autoMonth: Bool = SortPreference.loadAutoMonth()
    @State private var isShowingSoundSheet: Bool = false
    @State private var defaultSnoozeMinutes: Int = SortPreference.loadDefaultSnoozeMinutes()
    @State private var recordingMaxMinutes: Int = SortPreference.loadRecordingMaxMinutes()
    @State private var maxFutureYears: Int = SortPreference.loadMaxFutureYears()
    @State private var playbackVolumeSlider: Double = Double(SortPreference.loadPlaybackVolumeSlider())

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

                        // デフォルトスヌーズ時間
                        VStack(alignment: .leading, spacing: 8) {
                            Text("デフォルトスヌーズ時間")
                                .foregroundStyle(Color.white)
                            Text("詳細設定画面のスヌーズ初期値（最大1週間）")
                                .foregroundStyle(Color.white.opacity(0.7))
                                .font(.footnote)
                            HStack {
                                Stepper(
                                    value: $defaultSnoozeMinutes,
                                    in: 1...10080,
                                    step: 1
                                ) {
                                    Text("\(defaultSnoozeMinutes) 分")
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
