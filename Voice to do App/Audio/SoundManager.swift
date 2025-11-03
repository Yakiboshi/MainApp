import AVFoundation

final class SoundManager: NSObject {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]

    func play(_ name: String, ext: String = "wav") {
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

