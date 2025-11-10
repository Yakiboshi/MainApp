import Foundation
import AVFoundation

enum UserSoundTrimmer {
    // 入力URLの音声を10秒にカットして Documents/Sounds に保存し、保存先URLを返す
    static func trimTo10Seconds(inputURL: URL, preferredExt: AVFileType = .m4a, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: inputURL)
        let durationSec = CMTimeGetSeconds(asset.duration)
        // 7秒でフェードアウト、総尺も7秒に揃える
        let outLen = min(durationSec, 7.0)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: outLen, preferredTimescale: 600))

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        // 元ファイル（原音）も保管（擬似着信用）
        let originalDir = docs.appendingPathComponent("Sounds/Original", isDirectory: true)
        try? FileManager.default.createDirectory(at: originalDir, withIntermediateDirectories: true)
        let origDest = originalDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(inputURL.pathExtension.isEmpty ? "m4a" : inputURL.pathExtension)

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(NSError(domain: "UserSoundTrimmer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export session create failed"])));
            return
        }
        exporter.outputURL = out
        exporter.outputFileType = .m4a
        exporter.timeRange = range
        // フェードアウト（終端1秒）
        if let track = asset.tracks(withMediaType: .audio).first {
            let mix = AVMutableAudioMix()
            let params = AVMutableAudioMixInputParameters(track: track)
            let rampStart = max(0.0, outLen - 1.0)
            let rampRange = CMTimeRange(start: CMTime(seconds: rampStart, preferredTimescale: 600),
                                        duration: CMTime(seconds: outLen - rampStart, preferredTimescale: 600))
            params.setVolumeRamp(fromStartVolume: 1.0, toEndVolume: 0.0, timeRange: rampRange)
            mix.inputParameters = [params]
            exporter.audioMix = mix
        }
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed:
                // 原音も保存（失敗しても致命ではない）
                _ = try? FileManager.default.copyItem(at: inputURL, to: origDest)
                completion(.success(out))
            case .failed, .cancelled:
                completion(.failure(exporter.error ?? NSError(domain: "UserSoundTrimmer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])) )
            default:
                break
            }
        }
    }
}
