import Foundation

struct QuickPreset: Identifiable, Equatable {
    enum Kind: Equatable {
        case offsetDays(Int, hour: Int, minute: Int)
    }

    let id: UUID
    var title: String
    var kind: Kind

    init(id: UUID = UUID(), title: String, kind: Kind) {
        self.id = id
        self.title = title
        self.kind = kind
    }
}

extension QuickPreset {
    static func defaultPresets(now: Date = Date(), calendar: Calendar = .current) -> [QuickPreset] {
        // +1時間 / 明日の同時刻
        let oneHourDate = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let oneHour = QuickPreset(
            title: "+1時間",
            kind: .offsetDays(0,
                               hour: calendar.component(.hour, from: oneHourDate),
                               minute: calendar.component(.minute, from: oneHourDate))
        )
        let tomorrowSame = QuickPreset(
            title: "明日の同時刻",
            kind: .offsetDays(1,
                               hour: calendar.component(.hour, from: now),
                               minute: calendar.component(.minute, from: now))
        )
        return [oneHour, tomorrowSame]
    }
}
