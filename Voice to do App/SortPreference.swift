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

    enum Preset: String {
        case newest
        case oldest
        case nearest
        case recentUsed
    }

    enum Voicemail: String {
        case sentOldest
        case sentNewest
        case receivedOldest
    }

    enum NotificationVolumePreset: Int, CaseIterable, Identifiable {
        case small       = 0  // 小さめ
        case semiSmall   = 1  // やや小さめ
        case normal      = 2  // 普通
        case semiBig     = 3  // やや大きめ
        case big         = 4  // 大きめ

        var id: Int { rawValue }
    }

    private static let historyKey = "sort.history"
    private static let plannedKey = "sort.planned"
    private static let voicemailKey = "sort.voicemail"
    private static let presetKey = "sort.preset"
    private static let autoYearKey = "settings.autoYear"
    private static let autoMonthKey = "settings.autoMonth"
    private static let notificationVolumeKey = "settings.notificationVolume"
    private static let defaultSnoozeMinutesKey = "settings.defaultSnoozeMinutes"
    private static let recordingMaxMinutesKey = "settings.recordingMaxMinutes"
    private static let maxFutureYearsKey = "settings.maxFutureYears"
    private static let playbackVolumeSliderKey = "settings.playbackVolumeSlider"

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

    static func loadNotificationVolumePreset() -> NotificationVolumePreset {
        let defaults = UserDefaults.standard
        let stored = defaults.integer(forKey: notificationVolumeKey)

        // キーが未設定ならデフォルト（普通）
        guard defaults.object(forKey: notificationVolumeKey) != nil else {
            return .normal
        }

        // 0〜4 は新しいプリセット値として解釈
        if let preset = NotificationVolumePreset(rawValue: stored) {
            return preset
        }

        // 旧実装: 0〜100 のスライダー値が保存されている場合は 5 段階にマッピングして即座に移行
        let clamped = max(0, min(100, stored))
        let migrated: NotificationVolumePreset
        switch clamped {
        case 0..<20:
            migrated = .small
        case 20..<40:
            migrated = .semiSmall
        case 40..<60:
            migrated = .normal
        case 60..<80:
            migrated = .semiBig
        default:
            migrated = .big
        }
        saveNotificationVolumePreset(migrated)
        return migrated
    }

    static func saveNotificationVolumePreset(_ preset: NotificationVolumePreset) {
        UserDefaults.standard.set(preset.rawValue, forKey: notificationVolumeKey)
    }

    // MARK: - Default snooze minutes (1...10080, initial 10)
    static func loadDefaultSnoozeMinutes() -> Int {
        let stored = UserDefaults.standard.integer(forKey: defaultSnoozeMinutesKey)
        if UserDefaults.standard.object(forKey: defaultSnoozeMinutesKey) == nil {
            return 10
        }
        return max(1, min(10080, stored))
    }

    static func saveDefaultSnoozeMinutes(_ minutes: Int) {
        let clamped = max(1, min(10080, minutes))
        UserDefaults.standard.set(clamped, forKey: defaultSnoozeMinutesKey)
    }

    // MARK: - Recording max minutes (1...60, initial 3)
    static func loadRecordingMaxMinutes() -> Int {
        let stored = UserDefaults.standard.integer(forKey: recordingMaxMinutesKey)
        if UserDefaults.standard.object(forKey: recordingMaxMinutesKey) == nil {
            return 3
        }
        return max(1, min(60, stored))
    }

    static func saveRecordingMaxMinutes(_ minutes: Int) {
        let clamped = max(1, min(60, minutes))
        UserDefaults.standard.set(clamped, forKey: recordingMaxMinutesKey)
    }

    // MARK: - Max future years (1...10, initial 1)
    static func loadMaxFutureYears() -> Int {
        let stored = UserDefaults.standard.integer(forKey: maxFutureYearsKey)
        if UserDefaults.standard.object(forKey: maxFutureYearsKey) == nil {
            return 1
        }
        return max(1, min(10, stored))
    }

    static func saveMaxFutureYears(_ years: Int) {
        let clamped = max(1, min(10, years))
        UserDefaults.standard.set(clamped, forKey: maxFutureYearsKey)
    }

    // MARK: - Playback volume slider (0...100, initial 50)
    static func loadPlaybackVolumeSlider() -> Int {
        let stored = UserDefaults.standard.integer(forKey: playbackVolumeSliderKey)
        if UserDefaults.standard.object(forKey: playbackVolumeSliderKey) == nil {
            return 50
        }
        return max(0, min(100, stored))
    }

    static func savePlaybackVolumeSlider(_ value: Int) {
        let clamped = max(0, min(100, value))
        UserDefaults.standard.set(clamped, forKey: playbackVolumeSliderKey)
    }
}
