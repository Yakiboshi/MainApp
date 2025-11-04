import AVFoundation

final class SoundManager: NSObject {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]
    private var sessionConfigured = false

    override init() {
        super.init()
        configureAudioSession()
    }

    private func configureAudioSession() {
        guard !sessionConfigured else { return }
        do {
            // .ambient respects the Silent switch (no sound in silent mode) and mixes with other audio
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            sessionConfigured = true
        } catch {
            // If configuration fails, fallback is default which also typically respects silent switch
        }
    }

    func play(_ name: String, ext: String = "wav") {
        configureAudioSession()
        // Try cache
        if let p = players[name] {
            p.currentTime = 0
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
            players[name] = player
            player.play()
        } catch {
            // ignore silently in MVP skeleton
        }
    }
}
