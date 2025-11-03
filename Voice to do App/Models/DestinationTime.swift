import Foundation

struct DestinationTime: Equatable {
    var year: String = ""
    var month: String = ""
    var day: String = ""
    var hour: String = ""
    var minute: String = ""

    enum Field { case year, month, day, hour, minute }
    var active: Field = .year

    mutating func appendDigit(_ d: Int) {
        switch active {
        case .year:
            if year.count < 4 { year.append(String(d)) }
            if year.count == 4 { active = .month }
        case .month:
            if month.count < 2 { month.append(String(d)) }
            if month.count == 2 { active = .day }
        case .day:
            if day.count < 2 { day.append(String(d)) }
            if day.count == 2 { active = .hour }
        case .hour:
            if hour.count < 2 { hour.append(String(d)) }
            if hour.count == 2 { active = .minute }
        case .minute:
            if minute.count < 2 { minute.append(String(d)) }
        }
    }

    mutating func backspace() {
        switch active {
        case .minute:
            if !minute.isEmpty { minute.removeLast() }
            else { active = .hour; backspace() }
        case .hour:
            if !hour.isEmpty { hour.removeLast() }
            else { active = .day; backspace() }
        case .day:
            if !day.isEmpty { day.removeLast() }
            else { active = .month; backspace() }
        case .month:
            if !month.isEmpty { month.removeLast() }
            else { active = .year; backspace() }
        case .year:
            if !year.isEmpty { year.removeLast() }
        }
    }

    mutating func focus(_ f: Field) { active = f }

    func toDate(in calendar: Calendar = .current) -> Date? {
        guard year.count == 4, month.count == 2, day.count == 2, hour.count == 2, minute.count == 2,
              let y = Int(year), let m = Int(month), let d = Int(day), let h = Int(hour), let min = Int(minute) else { return nil }
        var comp = DateComponents()
        comp.year = y; comp.month = m; comp.day = d; comp.hour = h; comp.minute = min
        return calendar.date(from: comp)
    }

    func isValid(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let date = toDate(in: calendar) else { return false }
        // Future at least 1 minute
        if date < calendar.date(byAdding: .minute, value: 1, to: now)! { return false }
        // Within 1 year
        if date > calendar.date(byAdding: .year, value: 1, to: now)! { return false }
        // Check date validity (e.g., Feb 30)
        let comps = calendar.dateComponents([.year,.month,.day], from: date)
        if comps.year != Int(year) || comps.month != Int(month) || comps.day != Int(day) { return false }
        return true
    }
}

