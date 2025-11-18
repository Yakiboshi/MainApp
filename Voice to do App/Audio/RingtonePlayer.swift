import Foundation
import AVFoundation

final class RingtonePlayer: NSObject {
    private var player: AVAudioPlayer?

    func startLooping() {
        guard let url = RingtoneSourceProvider.currentOriginalURL() else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // サイレントスイッチに関係なく鳴らすため .playback を使用
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
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
