import SwiftUI

// Scroll-friendly graphical calendar with explicit month controls.
struct QuickDatePickerView: View {
    var onApply: (Date) -> Void
    // 初期選択は最小範囲内（現在+60秒）にして描画不具合を避ける
    @State private var date: Date = Date().addingTimeInterval(60)

    private var minDate: Date { Date().addingTimeInterval(60) }
    private var maxDate: Date { Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date().addingTimeInterval(60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Month control row
            HStack {
                Button(action: { stepMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthTitle(for: date))
                    .font(.headline)
                Spacer()
                Button(action: { stepMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }

            DatePicker("", selection: $date, in: minDate...maxDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()

            HStack {
                Spacer()
                Button("適用") { onApply(date) }
                    .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func stepMonth(_ delta: Int) {
        let cal = Calendar.current
        if let newDate = cal.date(byAdding: .month, value: delta, to: date) {
            let clamped = min(max(newDate, minDate), maxDate)
            date = clamped
        }
    }

    private func monthTitle(for date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        return df.string(from: date)
    }
}

