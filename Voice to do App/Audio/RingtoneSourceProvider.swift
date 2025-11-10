import Foundation

enum RingtoneSourceProvider {
    // ユーザーが指定した“原音”があれば最新を返す。無ければバンドルのデフォルトを返す。
    // ユーザー原音の保存場所: Documents/Sounds/Original/
    static func currentOriginalURL() -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Sounds/Original", isDirectory: true)
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]),
              !items.isEmpty else {
            // 未インポート時は ks035.wav（バンドル）を既定の着信音として使用
            return Bundle.main.url(forResource: "ks035", withExtension: "wav")
        }
        let sorted = items.sorted { (a, b) -> Bool in
            let ad = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let bd = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return ad > bd
        }
        return sorted.first
    }
}
