次の仕様でSwiftUIコードを作成してください。

【目的】
ユーザーが選択した音声ファイルをアプリ内に保存し、常に7秒でフェードアウト（終端1秒でリニアに減衰）し、総尺は7秒に収める設計にする。

【条件】
- 音声情報（ファイル名・URL・長さ）をSwiftDataで永続化する。
- Documentsフォルダに音声を保存する。
- ローカル通知でのサウンドは内蔵サウンド（バンドル）を使用。ユーザー音源はアプリ内の擬似着信音として再生（いずれも7秒でフェードアウト）。
- SwiftUIのボタンから音声ファイルを選び、トリミング→保存→通知登録を自動で行う。
- トリミングはAVFoundationを使用する。
- すべて1つのSwiftUIプロジェクト内で動作するように構成する。

【構成】
1. SwiftDataモデル（SoundFile）
2. トリミング＆保存マネージャ（SoundManager）
3. SwiftUIビュー（ContentView, AudioPickerView）

【コードベース】
以下のコードを参考に、SwiftDataを使った完全動作版に仕上げてください。

swiftDataモデル

import SwiftData

@Model
class SoundFile {
    var id: UUID
    var fileName: String
    var fileURL: URL
    var duration: Double
    
    init(fileName: String, fileURL: URL, duration: Double) {
        self.id = UUID()
        self.fileName = fileName
        self.fileURL = fileURL
        self.duration = duration
    }
}

トリミング + 保存マネージャー

import AVFoundation
import UserNotifications
import SwiftData

class SoundManager {
    static let shared = SoundManager()
    
    /// 音声を7秒にトリミング（終端1秒フェードアウト）してDocumentsに保存し、SwiftDataに登録
    func importAndTrimAudio(from inputURL: URL, modelContext: ModelContext, completion: @escaping (SoundFile?) -> Void) {
        let asset = AVAsset(url: inputURL)
        let duration = CMTimeGetSeconds(asset.duration)
        
        // 出力先
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = docsDir.appendingPathComponent("\(UUID().uuidString).caf")
        
        // 書き出し設定
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .caf
        
        // 長い場合は7秒でカット（フェードアウトは終端1秒）
        let start = CMTime(seconds: 0, preferredTimescale: 600)
        let cutLength = CMTime(seconds: min(duration, 10.0), preferredTimescale: 600)
        exportSession?.timeRange = CMTimeRange(start: start, duration: cutLength)
        
        exportSession?.exportAsynchronously {
            switch exportSession?.status {
            case .completed:
                print("✅ Trimmed sound saved: \(outputURL)")
                let newSound = SoundFile(fileName: outputURL.lastPathComponent,
                                         fileURL: outputURL,
                                         duration: min(duration, 10.0))
                modelContext.insert(newSound)
                try? modelContext.save()
                completion(newSound)
            default:
                print("❌ Export error: \(exportSession?.error?.localizedDescription ?? "unknown error")")
                completion(nil)
            }
        }
    }
    
    /// ローカル通知で再生
    func scheduleNotification(for sound: SoundFile) {
        let content = UNMutableNotificationContent()
        content.title = "カスタムサウンド通知"
        content.body = "この通知で保存した音が鳴ります。"
        content.sound = UNNotificationSound(named: UNNotificationSoundName(sound.fileName))
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "customSound-\(sound.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        print("🔔 通知登録済み：\(sound.fileName)")
    }
}

SwiftUI側

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct AudioPickerView: UIViewControllerRepresentable {
    var modelContext: ModelContext
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(modelContext: modelContext)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var modelContext: ModelContext
        
        init(modelContext: ModelContext) {
            self.modelContext = modelContext
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedURL = urls.first else { return }
            SoundManager.shared.importAndTrimAudio(from: selectedURL, modelContext: modelContext) { newSound in
                if let sound = newSound {
                    SoundManager.shared.scheduleNotification(for: sound)
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SoundFile.fileName) var sounds: [SoundFile]
    @State private var showPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Button("音声ファイルを選んで通知テスト") {
                showPicker.toggle()
            }
            .sheet(isPresented: $showPicker) {
                AudioPickerView(modelContext: modelContext)
            }
            
            List(sounds) { sound in
                VStack(alignment: .leading) {
                    Text(sound.fileName)
                    Text("長さ: \(Int(sound.duration))秒")
                        .font(.caption)
                    Button("この音で通知") {
                        SoundManager.shared.scheduleNotification(for: sound)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                print("通知許可: \(granted)")
            }
        }
    }
}

「このコードを参考にリファクタリングして完全版を出力してください、またビルド可能な構成にしてください」 
