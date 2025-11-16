import AVFoundation

final class SoundManager: NSObject {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]

    override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 録音中などで .playAndRecord が設定されている場合はカテゴリを上書きしない
            if session.category != .playAndRecord {
                // .ambient respects the Silent switch (no sound in silent mode) and mixes with other audio
                try session.setCategory(.ambient, mode: .default, options: [])
            }
            try session.setActive(true, options: [])
        } catch {
            // If configuration fails, fallback is default which also typically respects silent switch
        }
    }

    private func isKeypadSound(_ name: String) -> Bool {
        if name == "kleft" || name == "kright" || name == "ke" { return true }
        if name.count == 2, name.first == "k", let digit = name.last, ("0"..."9").contains(String(digit)) {
            return true
        }
        return false
    }

    func play(_ name: String, ext: String = "wav") {
        configureAudioSession()
        let volume: Float
        if isKeypadSound(name) {
            volume = 0.4
        } else if ["start", "ichiziteisi", "kettei", "nutural", "cancell", "list", "trush", "syuuryou"].contains(name) {
            volume = 0.5
        } else {
            volume = 1.0
        }
        // Try cache
        if let p = players[name] {
            p.currentTime = 0
            p.volume = volume
            p.play()
            return
        }
        // Load from bundle (developers must add files to app target Resources)
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return // silently ignore when asset is not yet bundled
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = volume
            players[name] = player
            player.play()
        } catch {
            // ignore silently in MVP skeleton
        }
    }
}
