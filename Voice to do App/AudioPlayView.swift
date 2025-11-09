import SwiftUI

// 通信画面：遷移直後に接続音を再生し、完了で録音画面へ進む（ナビゲーションバーなし）
struct AudioPlayView: View {
    let scheduledAt: Date
    let soundName: String
    let soundExt: String

    @StateObject private var player = AudioPlayerViewModel()
    @State private var showRecording = false
    @State private var started = false

    init(scheduledAt: Date, soundName: String = "callSound", soundExt: String = "mp3") {
        self.scheduledAt = scheduledAt
        self.soundName = soundName
        self.soundExt = soundExt
    }

    var body: some View {
        Group {
            if showRecording {
                // 次画面：録音（フルスクリーン、ナビバー無し）
                RecordingView(date: scheduledAt)
                    .ignoresSafeArea()
            } else {
                // 通信中ビュー
                VStack(spacing: 24) {
                    Text("通信中…")
                        .font(.title).bold()
                        .accessibilityLabel("通信中")
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                .padding()
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            // 画面表示と同時に音源再生（ファイル名は差し替え可能）
            player.playSound(fileName: soundName, fileExtension: soundExt) {
                // 再生完了/エラー時のフォールバックで録音へ
                DispatchQueue.main.async { showRecording = true }
            }
        }
    }
}
