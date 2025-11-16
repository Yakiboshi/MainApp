import Foundation

enum SortPreference {
    enum History: String {
        case sentOldest
        case sentNewest
        case receivedOldest
    }

    enum Planned: String {
        case sentOldest
        case sentNewest
        case receivedOldest
    }

    enum Voicemail: String {
        case sentOldest
        case sentNewest
        case receivedOldest
    }

    private static let autoYearKey = "settings.autoYear"
    private static let autoMonthKey = "settings.autoMonth"

    enum Preset: String {
        case newest
        case oldest
        case nearest
        case recentUsed
    }

    private static let historyKey = "sort.history"
    private static let plannedKey = "sort.planned"
    private static let voicemailKey = "sort.voicemail"
    private static let presetKey = "sort.preset"

    static func loadHistory() -> History {
        if let raw = UserDefaults.standard.string(forKey: historyKey),
           let v = History(rawValue: raw) {
            return v
        }
        return .sentOldest
    }

    static func saveHistory(_ value: History) {
        UserDefaults.standard.set(value.rawValue, forKey: historyKey)
    }

    static func loadPlanned() -> Planned {
        if let raw = UserDefaults.standard.string(forKey: plannedKey),
           let v = Planned(rawValue: raw) {
            return v
        }
        return .sentOldest
    }

    static func savePlanned(_ value: Planned) {
        UserDefaults.standard.set(value.rawValue, forKey: plannedKey)
    }

    static func loadVoicemail() -> Voicemail {
        if let raw = UserDefaults.standard.string(forKey: voicemailKey),
           let v = Voicemail(rawValue: raw) {
            return v
        }
        return .sentOldest
    }

    static func saveVoicemail(_ value: Voicemail) {
        UserDefaults.standard.set(value.rawValue, forKey: voicemailKey)
    }

    static func loadPreset() -> Preset {
        if let raw = UserDefaults.standard.string(forKey: presetKey),
           let v = Preset(rawValue: raw) {
            return v
        }
        return .newest
    }

    static func savePreset(_ value: Preset) {
        UserDefaults.standard.set(value.rawValue, forKey: presetKey)
    }

    static func loadAutoYear() -> Bool {
        UserDefaults.standard.bool(forKey: autoYearKey)
    }

    static func saveAutoYear(_ flag: Bool) {
        UserDefaults.standard.set(flag, forKey: autoYearKey)
    }

    static func loadAutoMonth() -> Bool {
        UserDefaults.standard.bool(forKey: autoMonthKey)
    }

    static func saveAutoMonth(_ flag: Bool) {
        UserDefaults.standard.set(flag, forKey: autoMonthKey)
    }
}
