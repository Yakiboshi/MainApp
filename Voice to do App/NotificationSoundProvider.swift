import Foundation
import AVFoundation
import CoreMedia

enum NotificationSoundProvider {
    // 現行の通知音ファイル名（Bundle内）。将来は設定から選択可能に拡張。
    private static let defaultName = "ks035"
    private static let defaultExt = "wav"
    private static let maxDuration: TimeInterval = 7.0 // 要件: 通知音は7秒以内（終端でフェードアウト）
    private static let customFileName = "notification.wav"

    // MARK: - 公開 API

    /// 現在有効な通知音ファイル名（"name.ext"）を返す。
    /// - 優先: Library/Sounds/notification.wav（カスタム/デフォルト変換済み）
    /// - フォールバック: バンドル内 ks035.wav（7秒以内の場合）
    static func currentNotificationSoundName() -> String? {
        // 1. カスタム（Library/Sounds/notification.wav）があればそれを優先
        if let url = customSoundFileURL(), FileManager.default.fileExists(atPath: url.path) {
            return customFileName
        }

        // 2. 旧仕様: バンドル内デフォルト音源
        guard let url = Bundle.main.url(forResource: defaultName, withExtension: defaultExt) else {
            return nil
        }
        // 長さチェック（>7秒は不可のため .default にフォールバック）
        if let duration = audioDuration(at: url), duration <= maxDuration {
            return "\(defaultName).\(defaultExt)"
        }
        return nil
    }

    /// Library/Sounds/notification.wav の URL
    static func customSoundFileURL() -> URL? {
        guard let dir = librarySoundsDirectory() else { return nil }
        return dir.appendingPathComponent(customFileName)
    }

    /// Library/Sounds ディレクトリ
    static func librarySoundsDirectory() -> URL? {
        guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return lib.appendingPathComponent("Sounds", isDirectory: true)
    }

    // MARK: - プリセット別ファイル生成

    /// 指定プリセット用の音源ファイルを Library/Sounds に確保し、そのファイル名を返す。
    /// 既に存在する場合は再生成せず、そのままファイル名を返す。
    private static func ensureScaledFile(for preset: SortPreference.NotificationVolumePreset) -> String? {
        guard let baseURL = Bundle.main.url(forResource: defaultName, withExtension: defaultExt) else {
            return nil
        }

        let suffix = preset.fileNameSuffix
        let fileName = "\(defaultName)\(suffix).\(defaultExt)"

        guard let soundsDir = librarySoundsDirectory() else {
            return nil
        }
        let dstURL = soundsDir.appendingPathComponent(fileName)

        // 既に生成済みならそれを利用
        if FileManager.default.fileExists(atPath: dstURL.path) {
            return fileName
        }

        do {
            try FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let gain = preset.gain
        guard scaleAudio(from: baseURL, to: dstURL, gain: gain) else {
            return nil
        }

        // 元音源と同じ長さである前提だが、一応長さチェックを通す
        if let duration = audioDuration(at: dstURL), duration <= maxDuration {
            return fileName
        } else {
            // 要件を満たさない場合は生成したファイルを削除してフォールバック
            try? FileManager.default.removeItem(at: dstURL)
            return nil
        }
    }

    // MARK: - ヘルパー

    private static func audioDuration(at url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }

    /// 元音源のサンプルにゲインを掛けて別ファイルとして書き出す。
    private static func scaleAudio(from srcURL: URL, to dstURL: URL, gain: Float) -> Bool {
        do {
            let srcFile = try AVAudioFile(forReading: srcURL)
            let format = srcFile.processingFormat
            let frameCount = AVAudioFrameCount(srcFile.length)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return false
            }

            try srcFile.read(into: buffer)

            let channels = Int(format.channelCount)
            let frames = Int(buffer.frameLength)

            let g = gain

            switch format.commonFormat {
            case .pcmFormatFloat32:
                guard let channelData = buffer.floatChannelData else {
                    return false
                }
                for ch in 0..<channels {
                    let data = channelData[ch]
                    for i in 0..<frames {
                        let sample = data[i] * g
                        // クリッピング防止のため -1.0〜1.0 にクランプ
                        data[i] = max(-1.0, min(1.0, sample))
                    }
                }

            case .pcmFormatInt16:
                guard let channelData = buffer.int16ChannelData else {
                    return false
                }
                let maxVal: Float = Float(Int16.max)
                let minVal: Float = Float(Int16.min)
                for ch in 0..<channels {
                    let data = channelData[ch]
                    for i in 0..<frames {
                        let sample = Float(data[i]) * g
                        let clamped = max(minVal, min(maxVal, sample))
                        data[i] = Int16(clamped.rounded())
                    }
                }

            case .pcmFormatInt32:
                guard let channelData = buffer.int32ChannelData else {
                    return false
                }
                let maxVal: Double = Double(Int32.max)
                let minVal: Double = Double(Int32.min)
                for ch in 0..<channels {
                    let data = channelData[ch]
                    for i in 0..<frames {
                        let sample = Double(data[i]) * Double(g)
                        let clamped = max(minVal, min(maxVal, sample))
                        data[i] = Int32(clamped.rounded())
                    }
                }

            default:
                // 対応していないフォーマット
                return false
            }

            let dstFile = try AVAudioFile(forWriting: dstURL, settings: srcFile.fileFormat.settings)
            try dstFile.write(from: buffer)

            return true
        } catch {
            return false
        }
    }
}

// MARK: - プリセットごとのパラメータ

private extension SortPreference.NotificationVolumePreset {
    /// 元音源に対する音量倍率
    var gain: Float {
        switch self {
        case .small:
            return 0.3
        case .semiSmall:
            return 0.7
        case .normal:
            return 1.0
        case .semiBig:
            return 1.4
        case .big:
            return 1.8
        }
    }

    /// 生成ファイル名のサフィックス
    var fileNameSuffix: String {
        switch self {
        case .small:
            return "_small"
        case .semiSmall:
            return "_semismall"
        case .normal:
            return ""
        case .semiBig:
            return "_semibig"
        case .big:
            return "_big"
        }
    }
}
