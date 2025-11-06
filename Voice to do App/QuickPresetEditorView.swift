import SwiftUI

struct QuickPresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (QuickPresetEntity) -> Void

    // 0=今日, 1=明日, 2..6=3〜6日後, 7=1週間後, 14=2週間後, 21=3週間後, 30=1ヶ月後
    @State private var daysOffset: Int = 1
    @State private var hour: Int = Calendar.current.component(.hour, from: Date())
    @State private var minute: Int = Calendar.current.component(.minute, from: Date())
    @State private var title: String = "" // 初期は空白

    private let dayOptions: [(value: Int, label: String)] = [
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
            } header: { Text("日付").foregroundColor(.white) }

            Section {
                HStack {
                    Picker("時", selection: $hour) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).foregroundColor(.black).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    Picker("分", selection: $minute) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).foregroundColor(.black).tag($0) }
                    }
                    .pickerStyle(.wheel)
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
        }
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
        let entity = QuickPresetEntity(title: title.isEmpty ? defaultTitle : title,
                                       daysOffset: daysOffset,
                                       hour: hour,
                                       minute: minute)
        onSave(entity)
        dismiss()
    }
}
