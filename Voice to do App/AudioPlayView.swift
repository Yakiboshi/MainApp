import SwiftUI

// 通信画面：遷移直後に接続音を再生し、完了で録音画面へ進む（ナビゲーションバーなし）
struct AudioPlayView: View {
    let scheduledAt: Date
    let soundName: String
    let soundExt: String

    @StateObject private var player = AudioPlayerViewModel()
    @State private var showRecording = false
    @State private var started = false
    @Environment(\.dismiss) private var dismiss

    init(scheduledAt: Date, soundName: String = "callSound", soundExt: String = "mp3") {
        self.scheduledAt = scheduledAt
        self.soundName = soundName
        self.soundExt = soundExt
    }

    var body: some View {
        ZStack {
            // 背景：黒系のダークグラデーション（上:濃い、下:やや明るい）
            LinearGradient(
                colors: [
                    Color(red: 12/255, green: 13/255, blue: 20/255), // top near-black navy
                    Color(red: 48/255, green: 50/255, blue: 58/255)  // bottom dark gray
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if showRecording {
                    // 次画面：録音（フルスクリーン、ナビバー無し）
                    RecordingView(date: scheduledAt)
                        .ignoresSafeArea()
                } else {
                    // 通信中ビュー（UIパーツ配置）
                    GeometryReader { geo in
                        let h = geo.size.height
                        VStack(spacing: 0) {
                            Spacer().frame(height: h/3)
                            // 見出し
                            Text("通信中")
                                .font(.title).bold()
                                .foregroundStyle(.white)
                                .accessibilityLabel("通信中")

                            Spacer()

                            // ローディング指標
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(1.8)
                                .accessibilityLabel("読み込み中")

                            Spacer()

                            // 閉じる（赤い×丸ボタン）+ ラベル
                            VStack(spacing: 6) {
                                Button {
                                    SoundManager.shared.play("cancell", ext: "mp3")
                                    player.stop()
                                    dismiss()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                                        Image(systemName: "xmark")
                                            .font(Theme.circleButtonIconFont)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("通信を終了")

                                Text("キャンセル")
                                    .font(Theme.circleButtonLabelFont)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .accessibilityHidden(true)
                            }
                            .padding(.bottom, h/6)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            // 通信画面へ遷移したタイミングで、録音向けのオーディオセッションと受話口出力に切り替える
            AudioRouteManager.configureForPreCall()
            // 画面表示と同時に音源再生（ファイル名は差し替え可能）
            player.playSound(fileName: soundName, fileExtension: soundExt) {
                // 再生完了/エラー時のフォールバックで録音へ
                DispatchQueue.main.async { showRecording = true }
            }
        }
    }
}
