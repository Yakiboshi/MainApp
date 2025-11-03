import SwiftUI

struct QuickDatePickerView: View {
    var onApply: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = Date().addingTimeInterval(60) // +1分

    var body: some View {
        Form {
            DatePicker("日時", selection: $date, in: Date().addingTimeInterval(60)...Calendar.current.date(byAdding: .year, value: 1, to: Date())!, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
        }
        .navigationTitle("日時を選択")
        .scrollContentBackground(.hidden)
        .background(Theme.appBlue.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("適用") { onApply(date); dismiss() } }
        }
    }
}
