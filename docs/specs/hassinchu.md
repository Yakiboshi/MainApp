1. 背景

AudioPlayView.swift　と同じ背景 (すでに実装済み)

2. 録音時間

画面上部から1/3の位置に中央揃えで「00:25」などの録音経過時間を大きな白いテキストで表示

3. 音声波形アニメーション

その下に音声に連動する波形アニメーションを白線で表示（簡易なビューでOK）

4. 残り時間

波形のすぐ下に「残り時間 2:35」のようなテキストを白で表示

5. 下部ボタン（1/6位置）

3つの丸ボタンを横並びに配置（中央揃え、等間隔）

🔴 左：「キャンセル」

赤丸、白バツマーク（xmark）、下に小さく「キャンセル」と白テキスト

タップで録音破棄、エントリ画面へ戻る

⚪️ 中央：「一時停止／再開」

白丸、黒の一時停止／再生アイコン（pause.fill / play.fill）、下に「一時停止」または「再開」

タップで録音を一時停止または再開（状態管理）

🟢 右：「終了」

黄緑色の丸、白の電話を切るアイコン（phone.down.fill）、下に「終了」

タップで録音を終了し、次の画面に遷移

🧾【SwiftUIのサンプルコード】
import SwiftUI

struct RecordingView: View {
    @State private var isPaused = false
    @State private var elapsedTime = 25
    @State private var remainingTime = 155 // 残り2分35秒

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                    .frame(height: UIScreen.main.bounds.height / 3)

                // 録音経過時間
                Text(String(format: "%02d:%02d", elapsedTime / 60, elapsedTime % 60))
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(.bottom, 40)

                // 波形（仮の表示）
                WaveformView()
                    .frame(height: 100)
                    .padding(.horizontal)

                // 残り時間
                Text("残り時間  \(String(format: "%01d:%02d", remainingTime / 60, remainingTime % 60))")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.top, 16)

                Spacer()

                // ボタン3つ並べる
                HStack(spacing: 40) {
                    // キャンセルボタン
                    VStack {
                        Button(action: {
                            // 録音破棄して戻る
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        Text("キャンセル")
                            .foregroundColor(.white)
                            .font(.caption)
                    }

                    // 一時停止／再開ボタン
                    VStack {
                        Button(action: {
                            isPaused.toggle()
                        }) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .foregroundColor(.black)
                                .font(.title)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        Text(isPaused ? "再開" : "一時停止")
                            .foregroundColor(.white)
                            .font(.caption)
                    }

                    // 終了ボタン
                    VStack {
                        Button(action: {
                            // 録音終了して次画面へ
                        }) {
                            Image(systemName: "phone.down.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding()
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                        Text("終了")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                .padding(.bottom, UIScreen.main.bounds.height / 12)
            }
        }
    }
}

// 仮の波形ビュー（本格的にするならCALayer連携）
struct WaveformView: View {
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(height: 1)
            .overlay(
                Text("≋≋≋≋≋≋≋≋≋")
                    .foregroundColor(.white)
                    .opacity(0.5)
            )
    }
}

#Preview {
    RecordingView()
}

実際の音声に連動する波形（サンプルコード）

音量レベル取得と波形Viewの作成

import SwiftUI
import AVFoundation

class AudioRecorder: ObservableObject {
    private var recorder: AVAudioRecorder!
    private var timer: Timer?
    
    @Published var currentLevel: Float = 0.0
    
    init() {
        startRecording()
    }
    
    func startRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        
        let url = URL(fileURLWithPath: "/dev/null")
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record()
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.recorder.updateMeters()
                self.currentLevel = self.recorder.averagePower(forChannel: 0)
            }
        } catch {
            print("録音に失敗しました: \(error)")
        }
    }
    
    func stopRecording() {
        recorder.stop()
        timer?.invalidate()
    }
}

波形アニメーションView

struct WaveformBar: Shape {
    var level: Float

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let height = CGFloat((level + 50) / 50) * rect.height
        let centerY = rect.midY
        path.move(to: CGPoint(x: rect.midX, y: centerY - height / 2))
        path.addLine(to: CGPoint(x: rect.midX, y: centerY + height / 2))
        return path
    }

    var animatableData: Float {
        get { level }
        set { level = newValue }
    }
}

SwiftUI UI部分

struct AudioWaveformView: View {
    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        VStack {
            Text("リアルタイム波形")
                .foregroundColor(.white)

            WaveformBar(level: recorder.currentLevel)
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 6, height: 100)
                .animation(.linear(duration: 0.05), value: recorder.currentLevel)
        }
        .padding()
        .background(Color.black)
    }
}
