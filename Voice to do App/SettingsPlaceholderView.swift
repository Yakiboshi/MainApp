import SwiftUI
import SwiftData

struct SettingsPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var autoYear: Bool = SortPreference.loadAutoYear()
    @State private var autoMonth: Bool = SortPreference.loadAutoMonth()
    @State private var isShowingSoundSheet: Bool = false

    @Query private var soundEntities: [NotificationSoundEntity]

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
        if let entity = soundEntities.first {
            if entity.isDefault {
                return "デフォルト"
            } else if let name = entity.displayName, !name.isEmpty {
                return name
            } else if let path = entity.soundURL, let url = URL(string: path) {
                return url.lastPathComponent
            }
        }
        return "デフォルト"
    }
}
