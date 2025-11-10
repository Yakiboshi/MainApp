import Foundation
import AVFoundation

final class RingtonePlayer: NSObject {
    private var player: AVAudioPlayer?

    func startLooping() {
        guard let url = RingtoneSourceProvider.currentOriginalURL() else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.prepareToPlay()
            p.play()
            self.player = p
        } catch {
            // ignore
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

