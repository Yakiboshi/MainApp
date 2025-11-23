import Foundation
import AVFoundation
import SwiftData

/// ユーザーが選んだ音源から擬似着信用のカスタム着信音を生成・管理するユーティリティ。
/// - 仕様:
///   - トリミング済みファイルは Library/Sounds/custom_ringtone.wav に保存
///   - 常に 7 秒以内・終端 1 秒フェードアウト（処理は `exportTrimmedFadeOutWAV` に委譲）
///   - メタ情報は SwiftData の `SoundFile` で管理
enum CustomRingtoneManager {
    private static let customFileName = "custom_ringtone.wav"

    /// トリミング済みカスタム着信音の出力先 URL（ディレクトリが無ければ作成）
    static func customRingtoneURL() -> URL? {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return nil }
        let dir = library.appendingPathComponent("Sounds", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return dir.appendingPathComponent(customFileName)
    }

    /// 旧バージョンで保存していた Documents/Ringtones 配下の URL
    private static func legacyRingtoneURL() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return docs.appendingPathComponent("Ringtones", isDirectory: true).appendingPathComponent(customFileName)
    }

    /// 現在有効な擬似着信音の URL（カスタムがあればそれ、無ければバンドル内デフォルト）。
    static func currentRingtoneURL() -> URL? {
        if let custom = customRingtoneURL(),
           FileManager.default.fileExists(atPath: custom.path) {
            return custom
        }
        // 旧バージョンの保存先にある場合はライブラリへ移行する
        if let legacy = legacyRingtoneURL(),
           FileManager.default.fileExists(atPath: legacy.path),
           let dst = customRingtoneURL() {
            try? FileManager.default.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: dst)
            try? FileManager.default.copyItem(at: legacy, to: dst)
            if FileManager.default.fileExists(atPath: dst.path) {
                return dst
            }
        }
        // カスタムが無い場合はバンドル内の固定サウンドを使用
        if let local = Bundle.main.url(forResource: "localsound", withExtension: "mp3") {
            return local
        }
        return Bundle.main.url(forResource: "ks035", withExtension: "wav")
    }

    /// 通知用に指定できるサウンド名（Library/Sounds にファイルが存在する場合のみ返す）
    static func notificationSoundNameIfAvailable() -> String? {
        guard let url = customRingtoneURL(),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return customFileName
    }

    /// カスタム着信音を削除し、デフォルトに戻す
    static func removeCustomRingtone(in context: ModelContext) {
        if let url = customRingtoneURL(), FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        do {
            let fetch = FetchDescriptor<SoundFile>()
            let existing = try context.fetch(fetch)
            for item in existing {
                context.delete(item)
            }
            try? context.save()
        } catch {
            // ignore
        }
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

        // 既存レコードと旧ファイルを先に削除（同じパスへの上書き時に新ファイルを消さないようにする）
        do {
            let fetch = FetchDescriptor<SoundFile>()
            let existing = try context.fetch(fetch)
            for item in existing {
                if FileManager.default.fileExists(atPath: item.fileURL.path) {
                    try? FileManager.default.removeItem(at: item.fileURL)
                }
                context.delete(item)
            }
            try? context.save()
        } catch {
            // 続行（後続の保存で再度試行）
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
                // 新しいレコードを保存（常に 1 件に保つ前提）
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
