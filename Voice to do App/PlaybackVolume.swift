import Foundation

enum PlaybackVolume {
    /// スライダー値（0〜100）から実際に使用するゲイン値（0.0〜2.5）を計算する。
    /// 仕様: 0 → 0.1倍, 50 → 1.0倍, 100 → 2.5倍（線形補間）
    static func gain(fromSlider slider: Int) -> Float {
        let clamped = max(0, min(100, slider))
        if clamped <= 50 {
            // 0...50 -> 0.1...1.0
            let t = Double(clamped) / 50.0
            let value = 0.1 + (1.0 - 0.1) * t
            return Float(value)
        } else {
            // 50...100 -> 1.0...2.5
            let t = Double(clamped - 50) / 50.0
            let value = 1.0 + (2.5 - 1.0) * t
            return Float(value)
        }
    }

    /// 現在の設定値に基づく再生ゲイン
    static func currentGain() -> Float {
        let slider = SortPreference.loadPlaybackVolumeSlider()
        return gain(fromSlider: slider)
    }
}

