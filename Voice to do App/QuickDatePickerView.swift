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
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthTitle(for: date))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { stepMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }

            DatePicker("", selection: $date, in: minDate...maxDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                // ダーク配色で日付・曜日の文字色を白系に統一 + 選択色を不透明の黄緑に
                .environment(\.colorScheme, .dark)
                .tint(Color(red: 0.52, green: 0.85, blue: 0.22))
                // 内蔵ヘッダー帯を背景と同色の不透明カバーで覆い、その中に日付テキスト（年/月/日/曜日）を大きく表示
                .overlay(alignment: Alignment.top) {
                    let coverHeight: CGFloat = 56
                    ZStack {
                        // 背景と同系の不透明色（カレンダー用ヘッダー隠し）
                        Rectangle()
                            .fill(Color(red: 0.10, green: 0.44, blue: 0.95))
                            .frame(height: coverHeight)
                        Text(ymdwLabel(for: date))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.10)))
                    }
                }
                
                // 日付がタップされた時点で即反映
                .onChange(of: date) { newValue in
                    onApply(newValue)
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

// 表示用の年月日+曜日ラベル
private func ymdwLabel(for date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "ja_JP")
    df.setLocalizedDateFormatFromTemplate("yyyyMMddEEE")
    // yyyy/MM/dd (EEE) 形式に整形
    let y = DateFormatter(); y.setLocalizedDateFormatFromTemplate("yyyy"); y.locale = df.locale
    let m = DateFormatter(); m.setLocalizedDateFormatFromTemplate("MM"); m.locale = df.locale
    let d = DateFormatter(); d.setLocalizedDateFormatFromTemplate("dd"); d.locale = df.locale
    let e = DateFormatter(); e.setLocalizedDateFormatFromTemplate("EEE"); e.locale = df.locale
    return "\(y.string(from: date))/\(m.string(from: date))/\(d.string(from: date)) (\(e.string(from: date)))"
}

// （日曜装飾・選択数字のオーバーレイは要望により撤去）
