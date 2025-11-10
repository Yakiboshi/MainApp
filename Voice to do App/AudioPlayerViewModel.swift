import Foundation
import AVFoundation
import Combine
import Combine

// 音源再生のロジックと完了検知（通信画面用の軽量VM）
final class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var onFinish: (() -> Void)?

    // 指定名の音源をバンドルから再生。見つからない/失敗時は onFinish を即時呼び出し
    func playSound(fileName: String, fileExtension: String = "mp3", onFinish: @escaping () -> Void) {
        self.onFinish = onFinish

        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            // 音源が無い場合でもフローを止めない
            DispatchQueue.main.async { onFinish() }
            return
        }
        do {
            // セッションカテゴリはアプリ全体の方針に合わせる（サイレントスイッチ尊重＝.ambient）。
            // ここでは既存設定（SoundManagerなど）を尊重し、個別設定は行わない。
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            p.play()
            self.player = p
        } catch {
            DispatchQueue.main.async { onFinish() }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let cb = onFinish
        onFinish = nil
        DispatchQueue.main.async { cb?() }
    }

    // ドキュメント等の任意URLから再生（任意ループ）
    func playURL(_ url: URL, loops: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.numberOfLoops = loops
            p.prepareToPlay()
            p.play()
            self.player = p
        } catch {
            DispatchQueue.main.async { onFinish() }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        onFinish = nil
    }
}
