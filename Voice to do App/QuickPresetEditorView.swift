import SwiftUI
import UIKit
import SwiftData

struct QuickPresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var relativePresets: [RelativeDatePresetEntity]
    var onSave: (QuickPresetEntity) -> Void

    // 0=今日, 1=明日, 2..6=3〜6日後, 7=1週間後, 14=2週間後, 21=3週間後, 30=1ヶ月後
    @State private var daysOffset: Int = 1
    @State private var hour: Int = Calendar.current.component(.hour, from: Date())
    @State private var minute: Int = Calendar.current.component(.minute, from: Date())
    @State private var title: String = "" // 初期は空白
    // 相対時刻プリセット（時間）の利用有無とパラメータ
    @State private var useRelative: Bool = false
    @State private var relativeHours: Double? = nil
    @State private var selectedRelativeKey: String = ""

    private static let baseDayOptions: [(value: Int, label: String)] = [
        (0, "今日"),
        (1, "明日"),
        (2, "2日"),
        (3, "3日後"),
        (4, "4日後"),
        (5, "5日後"),
        (6, "6日後"),
        (7, "1週間後"),
        (14, "2週間後"),
        (21, "3週間後"),
        (30, "1ヶ月後")
    ]

    // 設定画面で追加された RelativeDatePresetEntity（isHourBased == false）を
    // 日付ピッカーの候補として統合する。
    private var dayOptions: [(value: Int, label: String)] {
        var opts = Self.baseDayOptions
        let extraDays = relativePresets
            .filter { !$0.isHourBased }
            .compactMap { $0.days }
        for d in extraDays {
            if !opts.contains(where: { $0.value == d }) {
                opts.append((d, "\(d)日後"))
            }
        }
        opts.sort { $0.value < $1.value }
        return opts
    }

    private struct RelativeOption {
        let key: String
        let label: String
        let hours: Double?
    }

    private var relativeOptions: [RelativeOption] {
        var opts: [RelativeOption] = [
            RelativeOption(key: "", label: "なし", hours: nil),
            RelativeOption(key: "builtin_1h", label: "1時間後", hours: 1.0)
        ]
        for p in relativePresets
            .filter({ $0.isHourBased })
            .sorted(by: { $0.createdAt < $1.createdAt }) {
            if let h = p.hours {
                let label = p.title
                let key = "h_\(h)"
                opts.append(RelativeOption(key: key, label: label, hours: h))
            }
        }
        return opts
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $daysOffset) {
                    ForEach(dayOptions, id: \.value) { opt in
                        Text(opt.label).foregroundColor(.black).tag(opt.value)
                    }
                } label: {
                    Text(selectedDayLabel).foregroundColor(.black)
                }
                // 相対時刻プリセットの選択肢
                Picker("相対時刻", selection: $selectedRelativeKey) {
                    ForEach(relativeOptions, id: \.key) { opt in
                        Text(opt.label).tag(opt.key)
                    }
                }
                .onChange(of: selectedRelativeKey) { key in
                    applyRelativeSelection(key: key)
                }
            } header: { Text("日付 / 相対時刻").foregroundColor(.white) }

            Section {
                HStack {
                    Picker("時", selection: $hour) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).foregroundColor(.black).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .disabled(useRelative)
                    .opacity(useRelative ? 0.4 : 1.0)
                    Picker("分", selection: $minute) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).foregroundColor(.black).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .disabled(useRelative)
                    .opacity(useRelative ? 0.4 : 1.0)
                }
                .frame(height: 120)
            } header: { Text("時刻").foregroundColor(.white) }

            Section {
                TextField(text: $title, prompt: Text("\(selectedDayLabel) \(currentTimeLabel)").foregroundColor(.secondary)) {}
                    .foregroundColor(.black)
            } header: { Text("表示名").foregroundColor(.white) }
        }
        .navigationTitle("プリセット作成")
        .scrollContentBackground(.hidden)
        .background(Theme.appBlue.ignoresSafeArea())
        // keep default tint and colors; texts set to black above per spec
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            // キーボード上に閉じるボタンを表示（背景タップと競合しない）
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") { dismissKeyboard() }
            }
        }
        // 背景タップではなく、スクロールとツールバーで閉じる運用に変更（Picker操作と干渉しない）
        .scrollDismissesKeyboard(.interactively)
    }

    private var defaultTitle: String { Self.composeDefaultTitle(daysOffset: daysOffset, hour: hour, minute: minute) }

    private var selectedDayLabel: String {
        dayOptions.first(where: { $0.value == daysOffset })?.label ?? "\(daysOffset)日後"
    }

    private var currentTimeLabel: String { String(format: "%02d:%02d", hour, minute) }

    // Convenience init to support new/edit
    init(entity: QuickPresetEntity? = nil, onSave: @escaping (QuickPresetEntity) -> Void) {
        self.onSave = onSave
        if let e = entity {
            _daysOffset = State(initialValue: e.daysOffset)
            _hour = State(initialValue: e.hour)
            _minute = State(initialValue: e.minute)
            let auto = Self.composeDefaultTitle(daysOffset: e.daysOffset, hour: e.hour, minute: e.minute)
            _title = State(initialValue: e.title == auto ? "" : e.title)
            _useRelative = State(initialValue: e.isRelative)
            _relativeHours = State(initialValue: e.relativeHours)
            // 既存相対プリセット編集時のキー復元（おおよそ同じ値のものを選択）
            if e.isRelative {
                if let h = e.relativeHours {
                    _selectedRelativeKey = State(initialValue: "h_\(h)")
                }
            }
        }
    }

    private static func composeDefaultTitle(daysOffset: Int, hour: Int, minute: Int) -> String {
        let label: String
        switch daysOffset {
        case 0: label = "今日"
        case 1: label = "明日"
        case 2: label = "2日"
        case 3: label = "3日後"
        case 4: label = "4日後"
        case 5: label = "5日後"
        case 6: label = "6日後"
        case 7: label = "1週間後"
        case 14: label = "2週間後"
        case 21: label = "3週間後"
        case 30: label = "1ヶ月後"
        default: label = "\(daysOffset)日後"
        }
        return "\(label) \(String(format: "%02d:%02d", hour, minute))"
    }

    private func save() {
        let finalTitle: String
        if useRelative {
            let d = daysOffset > 0 ? daysOffset : 0
            let h = relativeHours

            let hoursLabel: String? = {
                guard let h else { return nil }
                if h.truncatingRemainder(dividingBy: 1.0) == 0 {
                    return String(format: "%.0f", h)
                } else {
                    return String(format: "%.1f", h)
                }
            }()

            let base: String
            if d > 0, let hoursLabel {
                base = "\(d)日/\(hoursLabel)時間後"
            } else if let hoursLabel {
                base = "\(hoursLabel)時間後"
            } else if d > 0 {
                base = "\(d)日後"
            } else {
                base = defaultTitle
            }

            finalTitle = title.isEmpty ? base : title
        } else {
            finalTitle = title.isEmpty ? defaultTitle : title
        }

        let entity = QuickPresetEntity(
            title: finalTitle,
            daysOffset: daysOffset,
            hour: hour,
            minute: minute,
            isRelative: useRelative,
            relativeHours: relativeHours,
            relativeDays: nil
        )
        onSave(entity)
        dismiss()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func applyRelativeSelection(key: String) {
        guard let opt = relativeOptions.first(where: { $0.key == key }) else {
            // 「なし」または不正なキー → 相対モード解除
            useRelative = false
            relativeHours = nil
            return
        }
        if opt.hours == nil {
            useRelative = false
            relativeHours = nil
        } else {
            useRelative = true
            relativeHours = opt.hours
        }
    }
}
