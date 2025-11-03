import SwiftUI

struct QuickPresetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (QuickPresetEntity) -> Void

    @State private var daysOffset: Int = 1 // 1..7
    @State private var hour: Int = Calendar.current.component(.hour, from: Date())
    @State private var minute: Int = Calendar.current.component(.minute, from: Date())
    @State private var title: String = ""

    var body: some View {
        Form {
            Section("日付") {
                Picker("何日後", selection: $daysOffset) {
                    ForEach(1...7, id: \.self) { Text("\($0)日後").tag($0) }
                }
            }
            Section("時刻") {
                HStack {
                    Picker("時", selection: $hour) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    Picker("分", selection: $minute) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                }
                .frame(height: 120)
            }
            Section("表示名") {
                TextField("例: 3日後 08:00", text: $title)
            }
        }
        .navigationTitle("プリセット作成")
        .scrollContentBackground(.hidden)
        .background(Theme.appBlue.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
        }
        .onAppear { if title.isEmpty { title = defaultTitle } }
    }

    private var defaultTitle: String { "\(daysOffset)日後 \(String(format: "%02d:%02d", hour, minute))" }

    private func save() {
        let entity = QuickPresetEntity(title: title.isEmpty ? defaultTitle : title,
                                       daysOffset: daysOffset,
                                       hour: hour,
                                       minute: minute)
        onSave(entity)
        dismiss()
    }
}
