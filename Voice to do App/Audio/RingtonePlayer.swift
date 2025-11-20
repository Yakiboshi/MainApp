import Foundation
import AVFoundation

final class RingtonePlayer: NSObject {
    private var player: AVAudioPlayer?

    func startLooping(with url: URL?) {
        guard let url else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // サイレントスイッチに関係なく鳴らすため .playback を使用
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            // 録音中以外は基本スピーカー出力：外部機器が無い場合のみスピーカーへ
            let outputs = session.currentRoute.outputs
            let hasExternal = outputs.contains { output in
                output.portType != .builtInSpeaker && output.portType != .builtInReceiver
            }
            if !hasExternal {
                try? session.overrideOutputAudioPort(.speaker)
            }
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
