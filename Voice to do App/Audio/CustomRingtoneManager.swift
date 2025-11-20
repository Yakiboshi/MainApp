import Foundation
import AVFoundation
import SwiftData

/// ユーザーが選んだ音源から擬似着信用のカスタム着信音を生成・管理するユーティリティ。
/// - 仕様:
///   - トリミング済みファイルは Documents/Ringtones/custom_ringtone.wav に保存
///   - 常に 7 秒以内・終端 1 秒フェードアウト（処理は `exportTrimmedFadeOutWAV` に委譲）
///   - メタ情報は SwiftData の `SoundFile` で管理
enum CustomRingtoneManager {
    /// トリミング済みカスタム着信音の出力先 URL（ディレクトリが無ければ作成）
    static func customRingtoneURL() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("Ringtones", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return dir.appendingPathComponent("custom_ringtone.wav")
    }

    /// 現在有効な擬似着信音の URL（カスタムがあればそれ、無ければバンドル内デフォルト）。
    static func currentRingtoneURL() -> URL? {
        if let custom = customRingtoneURL(),
           FileManager.default.fileExists(atPath: custom.path) {
            return custom
        }
        // カスタムが無い場合はバンドル内の固定サウンドを使用
        if let local = Bundle.main.url(forResource: "localsound", withExtension: "mp3") {
            return local
        }
        return Bundle.main.url(forResource: "ks035", withExtension: "wav")
    }

    /// ユーザーが選択した音源からカスタム着信音を生成し、SwiftData にメタ情報を保存する。
    static func importAndStoreCustomRingtone(
        from inputURL: URL,
        trimStart: Double,
        volume: VolumeLevel,
        context: ModelContext,
        completion: @escaping (Error?) -> Void
    ) {
        guard let outputURL = customRingtoneURL() else {
            let error = NSError(
                domain: "CustomRingtoneManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "出力先パスの取得に失敗しました"]
            )
            completion(error)
            return
        }

        exportTrimmedFadeOutWAV(
            inputURL: inputURL,
            outputURL: outputURL,
            trimStart: trimStart,
            volume: volume
        ) { error in
            if let error {
                completion(error)
                return
            }

            let asset = AVURLAsset(url: outputURL)
            let duration = CMTimeGetSeconds(asset.duration)

            do {
                // 既存の SoundFile を削除して 1 件に保つ
                let fetch = FetchDescriptor<SoundFile>()
                let existing = try context.fetch(fetch)
                for item in existing {
                    // 古いファイルも削除（存在すれば）
                    if FileManager.default.fileExists(atPath: item.fileURL.path) {
                        try? FileManager.default.removeItem(at: item.fileURL)
                    }
                    context.delete(item)
                }

                let sound = SoundFile(
                    fileName: outputURL.lastPathComponent,
                    fileURL: outputURL,
                    duration: duration.isFinite ? duration : 7.0
                )
                context.insert(sound)
                try context.save()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}

