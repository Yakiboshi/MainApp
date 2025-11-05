import SwiftUI
import Combine

// Reusable header component that renders the background image and overlays
// the PRESENT row (YEAR, MON, DAY, HOUR, MIN) and DESTINATION row (YEAR, MON, DAY, HOUR, MIN).
// Positions are specified as normalized values in 0...1 range.
struct TimeCircuitsHeaderView: View {
    // PRESENT positions
    let yearTop: CGFloat   // 0.0 (top) ... 1.0 (bottom)
    let yearLeft: CGFloat  // 0.0 (left) ... 1.0 (right)
    let monLeft: CGFloat
    let dayLeft: CGFloat
    let hourLeft: CGFloat
    let minLeft: CGFloat

    // DESTINATION positions / values
    let destYearTop: CGFloat // 0.0 (top) ... 1.0 (bottom)
    let destYear: String
    let destMonth: String
    let destDay: String
    let destHour: String
    let destMin: String

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width

            // Clamp 0...1 and convert to px
            let fy = max(0, min(1, yearTop))
            let fdy = max(0, min(1, destYearTop))
            let fxY = max(0, min(1, yearLeft))
            let fxM = max(0, min(1, monLeft))
            let fxD = max(0, min(1, dayLeft))
            let fxH = max(0, min(1, hourLeft))
            let fxN = max(0, min(1, minLeft))

            let yTop = fy * h
            let yTopDest = fdy * h
            let xLeftY = fxY * w
            let xLeftM = fxM * w
            let xLeftD = fxD * w
            let xLeftH = fxH * w
            let xLeftN = fxN * w

            ZStack(alignment: .topLeading) {
                Image("timecircuits2")
                    .resizable()
                    .scaledToFill()
                    // Ensure the image view's bounds exactly match the GeometryReader
                    // so 0.0/1.0 map to the image edges, not the screen edges.
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(Color.black)
                    .offset(y: 0) // safe-area top from container

                // PRESENT row (top)
                PresentYearView()
                    .frame(height: 34)
                    .offset(x: xLeftY, y: yTop)
                PresentMonthView()
                    .frame(height: 34)
                    .offset(x: xLeftM, y: yTop)
                PresentDayView()
                    .frame(height: 34)
                    .offset(x: xLeftD, y: yTop)
                PresentHourView()
                    .frame(height: 34)
                    .offset(x: xLeftH, y: yTop)
                PresentMinuteView()
                    .frame(height: 34)
                    .offset(x: xLeftN, y: yTop)

                // DESTINATION row (bottom)
                DestinationYearView(yearText: destYear)
                    .frame(height: 34)
                    .offset(x: xLeftY, y: yTopDest)
                DestinationMonthView(text: destMonth)
                    .frame(height: 34)
                    .offset(x: xLeftM, y: yTopDest)
                DestinationDayView(text: destDay)
                    .frame(height: 34)
                    .offset(x: xLeftD, y: yTopDest)
                DestinationHourView(text: destHour)
                    .frame(height: 34)
                    .offset(x: xLeftH, y: yTopDest)
                DestinationMinuteView(text: destMin)
                    .frame(height: 34)
                    .offset(x: xLeftN, y: yTopDest)
            }
        }
        .frame(height: 180)
    }
}

// MARK: - Present row views
private struct PresentYearView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var yearString: String {
        let y = Calendar.current.component(.year, from: now)
        return String(format: "%04d", y)
    }

    var body: some View {
        Text(yearString)
            .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 56))
            .foregroundStyle(Theme.segmentPresentText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .onReceive(timer) { date in now = date }
            .accessibilityLabel("現在の年 \(yearString)")
    }
}

private struct PresentMonthView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var monthString: String {
        let m = Calendar.current.component(.month, from: now)
        return String(format: "%02d", m)
    }
    var body: some View {
        Text(monthString)
            .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 56))
            .foregroundStyle(Theme.segmentPresentText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .onReceive(timer) { date in now = date }
            .accessibilityLabel("現在の月 \(monthString)")
    }
}

private struct PresentDayView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var dayString: String {
        let d = Calendar.current.component(.day, from: now)
        return String(format: "%02d", d)
    }
    var body: some View {
        Text(dayString)
            .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 56))
            .foregroundStyle(Theme.segmentPresentText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .onReceive(timer) { date in now = date }
            .accessibilityLabel("現在の日 \(dayString)")
    }
}

private struct PresentHourView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var hourString: String {
        let h = Calendar.current.component(.hour, from: now)
        return String(format: "%02d", h)
    }
    var body: some View {
        Text(hourString)
            .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 56))
            .foregroundStyle(Theme.segmentPresentText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .onReceive(timer) { date in now = date }
            .accessibilityLabel("現在の時 \(hourString)")
    }
}

private struct PresentMinuteView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var minuteString: String {
        let m = Calendar.current.component(.minute, from: now)
        return String(format: "%02d", m)
    }
    var body: some View {
        Text(minuteString)
            .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 56))
            .foregroundStyle(Theme.segmentPresentText)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .onReceive(timer) { date in now = date }
            .accessibilityLabel("現在の分 \(minuteString)")
    }
}

// MARK: - Destination row views
private struct DestinationYearView: View {
    var yearText: String // 0..4 chars
    private var chars: [Character] {
        let input = Array(yearText.prefix(4))
        var out: [Character] = []
        for i in 0..<4 { out.append(i < input.count ? input[i] : "8") }
        return out
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                let isFilled = idx < yearText.count
                Text(String(ch))
                    .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 56))
                    .foregroundStyle(isFilled ? Theme.segmentPresentText : Theme.segmentPlaceholder)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .accessibilityLabel("目的地の年 \(String(chars))")
    }
}

private struct TwoDigitPlaceholderView: View {
    var text: String
    private var out: [Character] {
        let input = Array(text.prefix(2))
        var arr: [Character] = []
        for i in 0..<2 { arr.append(i < input.count ? input[i] : "8") }
        return arr
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(out.enumerated()), id: \.offset) { idx, ch in
                let isFilled = idx < text.count
                Text(String(ch))
                    .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: 56))
                    .foregroundStyle(isFilled ? Theme.segmentPresentText : Theme.segmentPlaceholder)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

private struct DestinationMonthView: View {
    var text: String
    var body: some View { TwoDigitPlaceholderView(text: text) }
}

private struct DestinationDayView: View {
    var text: String
    var body: some View { TwoDigitPlaceholderView(text: text) }
}

private struct DestinationHourView: View {
    var text: String
    var body: some View { TwoDigitPlaceholderView(text: text) }
}

private struct DestinationMinuteView: View {
    var text: String
    var body: some View { TwoDigitPlaceholderView(text: text) }
}
