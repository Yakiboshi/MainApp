録音画面をSwiftUIとSwiftDataを使います。

目的：
画面遷移後すぐに録音が開始され、「録音終了」ボタンを押すと録音が停止し、
遷移時に渡された日時データと録音した音声データを紐付けて保存します。
また、同時にその日時データに合わせてローカル通知を作成します。

機能要件：

画面遷移後すぐに自動で録音を開始する

画面下部の「録音終了」ボタンで録音を停止する

録音データはアプリ内のDocumentsフォルダに .m4a 形式で保存

遷移時に受け取った日時（Date型）と録音ファイルをSwiftDataで紐付けて保存

録音終了と同時に、その日時でローカル通知を登録

SwiftDataのモデルは RecordingEntity とし、以下のプロパティを持つ

id: UUID

recordedAt: Date

fileName: String

duration: Double

技術条件：

SwiftUIを使用

SwiftDataを使用して録音履歴を保存

音声録音は AVAudioRecorder を使用

通知は UserNotifications フレームワークを使用

モデル保存は .modelContainer(for: RecordingEntity.self) を利用

画面構成は以下の2画面構成

FirstView: DatePickerで日時を選び、「録音画面へ」ボタンで遷移

RecordingView: 自動で録音を開始し、ボタンで停止→保存→通知

ファイル構成：

RecordingEntity.swift（SwiftDataモデル）

AudioRecorderViewModel.swift（録音管理）

NotificationManager.swift（通知処理）

RecordingView.swift（録音画面）

AudioPlayView.swift（遷移元画面）

AppTabsView.swift（アプリエントリ）

コードにはコメントを入れて、録音開始／停止／保存／通知処理がどこで行われているか分かるようにしてください。




以下参考コード

import SwiftUI
import AVFoundation
import UserNotifications
import SwiftData

// MARK: - ViewModel: 録音処理
@MainActor
class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private(set) var recordingURL: URL?
    @Published var isRecording = false
    private var startTime: Date?
    
    func startRecording(for date: Date) {
        let fileName = "recording_\(Int(date.timeIntervalSince1970)).m4a"
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docDir.appendingPathComponent(fileName)
        recordingURL = fileURL
        startTime = Date()
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            print("🎙️録音開始: \(fileName)")
        } catch {
            print("❌録音エラー: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() -> (fileName: String?, duration: Double)? {
        audioRecorder?.stop()
        isRecording = false
        
        guard let url = recordingURL else { return nil }
        let duration = -(startTime?.timeIntervalSinceNow ?? 0)
        print("🛑録音終了: \(url.lastPathComponent)")
        return (url.lastPathComponent, duration)
    }
}

// MARK: - 通知管理
class NotificationManager {
    static let shared = NotificationManager()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("通知許可エラー: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "録音データのお知らせ"
        content.body = "この日時の録音データがあります"
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        print("🔔通知設定完了: \(date)")
    }
}

// MARK: - 録音画面
struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var recorder = AudioRecorderViewModel()
    @Environment(\.dismiss) private var dismiss
    let date: Date
    
    var body: some View {
        VStack(spacing: 40) {
            Text("録音日時: \(date.formatted(.dateTime.year().month().day().hour().minute()))")
                .font(.headline)
            
            if recorder.isRecording {
                Text("🎙️ 録音中...")
                    .foregroundColor(.red)
            } else {
                Text("🛑 録音停止中")
                    .foregroundColor(.gray)
            }
            
            Button(action: {
                if recorder.isRecording {
                    if let result = recorder.stopRecording() {
                        let newRecording = RecordingEntity(recordedAt: date, fileName: result.fileName ?? "", duration: result.duration)
                        modelContext.insert(newRecording)
                        try? modelContext.save()
                        
                        NotificationManager.shared.scheduleNotification(for: date)
                        dismiss()
                    }
                }
            }) {
                Text("録音終了")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            NotificationManager.shared.requestPermission()
            recorder.startRecording(for: date)
        }
    }
}

// MARK: - 遷移元画面
struct FirstView: View {
    @State private var targetDate = Date().addingTimeInterval(60)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                DatePicker("録音・通知日時", selection: $targetDate)
                    .datePickerStyle(.graphical)
                
                NavigationLink("録音画面へ") {
                    RecordingView(date: targetDate)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

// MARK: - アプリエントリ
@main
struct RecorderApp: App {
    var body: some Scene {
        WindowGroup {
            FirstView()
        }
        .modelContainer(for: RecordingEntity.self)
    }
}
