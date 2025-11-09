import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private(set) var recordingURL: URL?
    @Published var isRecording: Bool = false
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
            // 録音用にセッションを切替（MVP: スピーカー出力の既定でOK）
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.record()
            self.audioRecorder = recorder
            self.isRecording = true
        } catch {
            // 録音開始失敗時はステータスのみ更新
            self.isRecording = false
        }
    }

    func stopRecording() -> (fileName: String, duration: Double)? {
        audioRecorder?.stop()
        isRecording = false

        guard let url = recordingURL else { return nil }
        let duration = -(startTime?.timeIntervalSinceNow ?? 0)

        // 録音セッションの後片付け（キー音などに戻す場合は SoundManager 側で再設定される想定）
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        return (url.lastPathComponent, max(0, duration))
    }
}

