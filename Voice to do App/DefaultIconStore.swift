import Foundation

enum DefaultIconStore {
    private static let key = "settings.defaultIconData"

    static func save(_ data: Data?) {
        let defaults = UserDefaults.standard
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func load() -> Data? {
        UserDefaults.standard.data(forKey: key)
    }
}

