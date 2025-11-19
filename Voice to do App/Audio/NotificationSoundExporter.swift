import Foundation
import AVFoundation

/// 通知・着信共通のカスタムサウンドを書き出すユーティリティ。
/// 入力音声を「7秒にトリミング＋終端1秒フェードアウト＋音量スケーリング」して WAV として出力する。
enum NotificationSoundExporter {
    static func exportTrimmedFadeOutWAV(
        inputURL: URL,
        outputURL: URL,
        trimStart: Double,
        volume: VolumeLevel,
        completion: @escaping (Error?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let inFile = try AVAudioFile(forReading: inputURL)
                let format = inFile.processingFormat
                let sampleRate = format.sampleRate

                let totalFrames = Double(inFile.length)
                let totalDuration = totalFrames / sampleRate

                let safeTrimStart = max(0.0, min(trimStart, max(0.0, totalDuration - 0.1)))
                let availableDuration = max(0.0, totalDuration - safeTrimStart)
                let targetDuration = min(7.0, availableDuration)

                guard targetDuration > 0 else {
                    throw NSError(domain: "NotificationSoundExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio too short for trimming"])
                }

                let startFrame = AVAudioFramePosition(safeTrimStart * sampleRate)
                let frameCount = AVAudioFrameCount(targetDuration * sampleRate)

                inFile.framePosition = startFrame

                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    throw NSError(domain: "NotificationSoundExporter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PCM buffer"])
                }

                try inFile.read(into: buffer, frameCount: frameCount)
                buffer.frameLength = frameCount

                let channels = Int(format.channelCount)
                let frames = Int(buffer.frameLength)
                let fadeFrames = Int(min(sampleRate, Double(frames)))
                let fadeStartIndex = max(0, frames - fadeFrames)
                let baseGain = volume.rawValue

                switch format.commonFormat {
                case .pcmFormatFloat32:
                    guard let channelData = buffer.floatChannelData else {
                        throw NSError(domain: "NotificationSoundExporter", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unsupported float32 buffer"])
                    }
                    for ch in 0..<channels {
                        let data = channelData[ch]
                        for i in 0..<frames {
                            var g = baseGain
                            if i >= fadeStartIndex {
                                let t = Double(i - fadeStartIndex) / Double(max(fadeFrames, 1))
                                g *= Float(1.0 - t)
                            }
                            let sample = data[i] * g
                            data[i] = max(-1.0, min(1.0, sample))
                        }
                    }
                case .pcmFormatInt16:
                    guard let channelData = buffer.int16ChannelData else {
                        throw NSError(domain: "NotificationSoundExporter", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unsupported int16 buffer"])
                    }
                    let maxVal: Float = Float(Int16.max)
                    let minVal: Float = Float(Int16.min)
                    for ch in 0..<channels {
                        let data = channelData[ch]
                        for i in 0..<frames {
                            var g = baseGain
                            if i >= fadeStartIndex {
                                let t = Double(i - fadeStartIndex) / Double(max(fadeFrames, 1))
                                g *= Float(1.0 - t)
                            }
                            let sample = Float(data[i]) * g
                            let clamped = max(minVal, min(maxVal, sample))
                            data[i] = Int16(clamped.rounded())
                        }
                    }
                case .pcmFormatInt32:
                    guard let channelData = buffer.int32ChannelData else {
                        throw NSError(domain: "NotificationSoundExporter", code: -5, userInfo: [NSLocalizedDescriptionKey: "Unsupported int32 buffer"])
                    }
                    let maxVal: Double = Double(Int32.max)
                    let minVal: Double = Double(Int32.min)
                    for ch in 0..<channels {
                        let data = channelData[ch]
                        for i in 0..<frames {
                            var g = Double(baseGain)
                            if i >= fadeStartIndex {
                                let t = Double(i - fadeStartIndex) / Double(max(fadeFrames, 1))
                                g *= (1.0 - t)
                            }
                            let sample = Double(data[i]) * g
                            let clamped = max(minVal, min(maxVal, sample))
                            data[i] = Int32(clamped.rounded())
                        }
                    }
                default:
                    throw NSError(domain: "NotificationSoundExporter", code: -6, userInfo: [NSLocalizedDescriptionKey: "Unsupported audio format"])
                }

                // 出力ディレクトリを作成
                let dir = outputURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                // 既存ファイルがあれば削除
                try? FileManager.default.removeItem(at: outputURL)

                let outFile = try AVAudioFile(forWriting: outputURL, settings: inFile.processingFormat.settings)
                try outFile.write(from: buffer)

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
}

/// 5 段階の音量レベル（スケーリング値）
enum VolumeLevel: Float, CaseIterable, Identifiable {
    case small = 0.3
    case mediumSmall = 0.6
    case normal = 1.0
    case mediumLarge = 1.5
    case large = 2.0

    var id: Float { rawValue }
}

extension VolumeLevel {
    /// 既存の NotificationVolumePreset との相互変換（永続化用）
    init(from preset: SortPreference.NotificationVolumePreset) {
        switch preset {
        case .small:
            self = .small
        case .semiSmall:
            self = .mediumSmall
        case .normal:
            self = .normal
        case .semiBig:
            self = .mediumLarge
        case .big:
            self = .large
        }
    }

    var toPreset: SortPreference.NotificationVolumePreset {
        switch self {
        case .small:
            return .small
        case .mediumSmall:
            return .semiSmall
        case .normal:
            return .normal
        case .mediumLarge:
            return .semiBig
        case .large:
            return .big
        }
    }
}

