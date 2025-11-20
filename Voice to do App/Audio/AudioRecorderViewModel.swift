import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    // MARK: - Public state
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var level: Double = 0 // 0...1
    @Published var elapsedSec: Int = 0
    @Published var remainingSec: Int = 0

    // MARK: - Private properties
    private var audioRecorder: AVAudioRecorder?
    private(set) var recordingURL: URL?
    private var meterTimer: Timer?
    private var secondTimer: Timer?
    private var maxDurationSec: Int = 180
    private var autoPausedByInterruption: Bool = false
    private var pauseLoopPlayer: AVAudioPlayer?

    // MARK: - Lifecycle
    deinit {
        // deinit は nonisolated のため、actor隔離されたメソッドは呼べない。
        // タイマー破棄とオブザーバ解除のみを nonisolated(unsafe) ヘルパで実施。
        cleanupForDeinit()
    }

    // MainActor 隔離検査を回避するため、deinit でのみ使用するクリーナー
    nonisolated(unsafe) private func cleanupForDeinit() {
        // タイマーは通常の停止系メソッドで破棄される前提。deinitではオブザーバのみ解除。
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Control
    func startRecording(for date: Date, maxDurationSec: Int = 180) {
        self.maxDurationSec = maxDurationSec
        elapsedSec = 0
        remainingSec = maxDurationSec
        isPaused = false
        level = 0

        // Prepare file path (temporary; can be renamed later)
        let fileName = "recording_\(Int(date.timeIntervalSince1970)).m4a"
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docDir.appendingPathComponent(fileName)
        recordingURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            // Use voiceChat for better echo cancellation and BT mic support
            let session = AVAudioSession.sharedInstance()
            // 実機では .playAndRecord + .voiceChat と .allowBluetoothA2DP の組み合わせが失敗するケースがあるため、
            // 録音時は入力に必要な .allowBluetooth のみに絞る
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try session.setActive(true)

            // 録音の入力ゲインを強める（可能なデバイスのみ）。デフォルトの約2倍を目安に、上限1.0でクリップ。
            if session.isInputGainSettable {
                let currentGain = session.inputGain
                let targetGain = min(1.0, max(0.0, currentGain * 2.0))
                try? session.setInputGain(targetGain)
            }

            // 外部機器接続時は、入力を持たないデバイスなら内蔵マイクにフォールバック
            AudioRouteManager.configureInputForRecording()

            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.record()
            self.audioRecorder = recorder
            self.isRecording = true

            startTimers()
            observeSessionNotifications()

            // 録音開始時の効果音
            SoundManager.shared.play("start", ext: "mp3")
        } catch {
            // 録音開始失敗時はステータスのみ更新
            self.isRecording = false
        }
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        audioRecorder?.pause()
        isPaused = true
        stopTimers(keepLevelZero: true)
        startPauseLoop()
    }

    func resume() {
        guard isRecording, isPaused else { return }
        stopPauseLoop()
        audioRecorder?.record()
        isPaused = false
        startTimers()
    }

    func cancel() {
        // Stop and delete file
        audioRecorder?.stop()
        isRecording = false
        isPaused = false
        stopTimers(keepLevelZero: true)
        stopPauseLoop()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        level = 0
        elapsedSec = 0
        remainingSec = 0
        // 録音を終えたら内蔵出力のみの場合はスピーカーへ戻す
        AudioRouteManager.restoreBuiltInSpeakerIfNeeded()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Stop recording and optionally rename the file to `<id>.m4a`.
    func stopRecording(renameToId id: UUID? = nil) -> (fileName: String, duration: Double)? {
        audioRecorder?.stop()
        isRecording = false
        stopTimers()

        guard let srcURL = recordingURL else { return nil }
        var finalURL = srcURL
        if let id = id {
            let docs = srcURL.deletingLastPathComponent()
            let dst = docs.appendingPathComponent("\(id.uuidString).m4a")
            // Remove existing if any, then move
            if FileManager.default.fileExists(atPath: dst.path) {
                try? FileManager.default.removeItem(at: dst)
            }
            do {
                try FileManager.default.moveItem(at: srcURL, to: dst)
                finalURL = dst
                recordingURL = dst
            } catch {
                // fallback to original
                finalURL = srcURL
            }
        }

        // Use timer-based elapsedSec as duration; fallback to recorder.currentTime
        let duration: Double
        if elapsedSec > 0 {
            duration = Double(elapsedSec)
        } else {
            duration = max(0, audioRecorder?.currentTime ?? 0)
        }

        // 録音終了時の効果音
        SoundManager.shared.play("start", ext: "mp3")

        // 録音を終えたら内蔵出力のみの場合はスピーカーへ戻す
        AudioRouteManager.restoreBuiltInSpeakerIfNeeded()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        return (finalURL.lastPathComponent, duration)
    }

    // MARK: - Timers
    private func startTimers() {
        stopTimers()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let rec = self.audioRecorder, self.isRecording, !self.isPaused else { return }
            rec.updateMeters()
            let dB = rec.averagePower(forChannel: 0)
            let v = self.normalizedPower(from: dB)
            // simple smoothing
            self.level = self.level * 0.8 + v * 0.2
        }
        if let meterTimer { RunLoop.current.add(meterTimer, forMode: .common) }

        secondTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording, !self.isPaused else { return }
            self.elapsedSec += 1
            self.remainingSec = max(self.maxDurationSec - self.elapsedSec, 0)
            if self.elapsedSec >= self.maxDurationSec {
                _ = self.stopRecording()
            }
        }
        if let secondTimer { RunLoop.current.add(secondTimer, forMode: .common) }
    }

    private func stopTimers(keepLevelZero: Bool = false) {
        meterTimer?.invalidate(); meterTimer = nil
        secondTimer?.invalidate(); secondTimer = nil
        if keepLevelZero { level = 0 }
    }

    private func normalizedPower(from decibels: Float) -> Double {
        if decibels <= -80 { return 0 }
        if decibels >= 0 { return 1 }
        return pow(10.0, Double(decibels) / 20.0)
    }

    // MARK: - Session notifications
    private func observeSessionNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMediaServicesReset(_:)), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard isRecording else { return }
        guard let info = note.userInfo,
              let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
        switch type {
        case .began:
            autoPausedByInterruption = true
            pause()
        case .ended:
            let optsVal = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let opts = AVAudioSession.InterruptionOptions(rawValue: optsVal ?? 0)
            if autoPausedByInterruption, opts.contains(.shouldResume) {
                autoPausedByInterruption = false
                resume()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        // 以前は .unknown などで積極的に cancel() していたが、
        // 実機での正規なルート変更まで巻き込んで録音が即停止するケースがあったため、
        // ここでは本当に「ルートが取れない」ときだけキャンセルするように絞る。
        guard isRecording else { return }
        if let reasonVal = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal) {
            switch reason {
            case .noSuitableRouteForCategory:
                // このカテゴリでは適切なルートが存在しない → 録音を中断
                cancel()
            default:
                // oldDeviceUnavailable/newDeviceAvailable/categoryChange/override などは録音継続
                break
            }
        }
    }

    @objc private func handleMediaServicesReset(_ note: Notification) {
        // Media services crashed or reset -> cancel recording
        cancel()
    }

    // MARK: - Pause loop sound
    private func startPauseLoop() {
        stopPauseLoop()
        guard let url = Bundle.main.url(forResource: "ichiziteisi", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.5
            player.prepareToPlay()
            player.play()
            pauseLoopPlayer = player
        } catch {
            pauseLoopPlayer = nil
        }
    }

    private func stopPauseLoop() {
        pauseLoopPlayer?.stop()
        pauseLoopPlayer = nil
    }
}
