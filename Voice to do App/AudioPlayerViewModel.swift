import Foundation
import AVFoundation
import Combine
import Combine

// 音源再生のロジックと完了検知（通信画面用の軽量VM）
final class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var onFinish: (() -> Void)?
    @Published var isPlaying: Bool = false

    // 指定名の音源をバンドルから再生。見つからない/失敗時は onFinish を即時呼び出し
    func playSound(fileName: String, fileExtension: String = "mp3", volume: Float = 1.0, onFinish: @escaping () -> Void) {
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
            p.volume = max(0.0, min(volume, 1.0))
            p.prepareToPlay()
            p.play()
            self.player = p
            DispatchQueue.main.async { self.isPlaying = true }
        } catch {
            DispatchQueue.main.async { onFinish() }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let cb = onFinish
        onFinish = nil
        DispatchQueue.main.async { self.isPlaying = false }
        DispatchQueue.main.async { cb?() }
    }

    // ドキュメント等の任意URLから再生（任意ループ）
    func playURL(_ url: URL, loops: Int = 0, volume: Float = 1.0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.numberOfLoops = loops
            p.volume = max(0.0, min(volume, 1.0))
            p.prepareToPlay()
            p.play()
            self.player = p
            DispatchQueue.main.async { self.isPlaying = true }
        } catch {
            DispatchQueue.main.async { onFinish() }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        onFinish = nil
        DispatchQueue.main.async { self.isPlaying = false }
    }

    // 現在の再生時間（秒）
    func currentTime() -> TimeInterval { player?.currentTime ?? 0 }
    // 総再生時間（秒）
    func duration() -> TimeInterval { player?.duration ?? 0 }
    // 指定位置にシーク（秒）
    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(0, seconds), player.duration)
        player.currentTime = clamped
        if !player.isPlaying {
            player.play()
            DispatchQueue.main.async { self.isPlaying = true }
        }
    }

    // 一時停止
    func pause() {
        player?.pause()
        DispatchQueue.main.async { self.isPlaying = false }
    }

    // 再生再開（URLが設定済みのプレイヤー）
    func play() {
        guard let p = player else { return }
        if !p.isPlaying {
            p.play()
            DispatchQueue.main.async { self.isPlaying = true }
        }
    }
}
