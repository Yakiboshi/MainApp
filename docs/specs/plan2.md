画面遷移後にXcodeに含まれているcallSoundmp3ファイルが再生される

再生が最後まで終了したら自動的に次の画面へ遷移する

特定の音源に依存しないように汎用的に設計する（ファイル名を変えても動作可能）

使用条件:

SwiftUIを使用

音声再生はAVFoundationのAVAudioPlayerを使う

再生完了検知にはAVAudioPlayerDelegateを使用

以下のファイル構成でお願いします。

AudioPlayView.swift（音源再生と遷移を管理）

AudioPlayerViewModel.swift（再生ロジックとデリゲート処理）

RecordingView.swift（再生完了後の画面）

コード内にはコメントを入れて、どこで音が再生・遷移しているか分かるようにしてください。

以下参考コード

import SwiftUI
import AVFoundation

// MARK: - ViewModel: 音声再生の管理
class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?
    var onFinish: (() -> Void)?
    
    func playSound(fileName: String, fileExtension: String = "mp3", onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        
        // mp3 ファイルをバンドルから取得
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("⚠️ 音源が見つかりません: \(fileName).\(fileExtension)")
            onFinish()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("❌ 再生エラー: \(error.localizedDescription)")
            onFinish()
        }
    }
    
    // 再生完了時に呼ばれるデリゲートメソッド
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}

// MARK: - 最初の画面
struct FirstView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("🎬 音声再生デモ")
                    .font(.largeTitle)
                NavigationLink("▶ 再生画面へ") {
                    AudioPlayView()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

// MARK: - 音声再生画面
struct AudioPlayView: View {
    @StateObject private var player = AudioPlayerViewModel()
    @State private var navigateNext = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("🎧 再生中...")
                .font(.title)
            
            ProgressView()
            
            // 再生完了後、自動的にこのリンクが有効になる
            NavigationLink("", destination: NextView(), isActive: $navigateNext)
                .hidden()
        }
        .onAppear {
            // Xcode に追加した mp3 ファイル名（拡張子不要）
            player.playSound(fileName: "sound") {
                navigateNext = true
            }
        }
    }
}

// MARK: - 遷移先画面
struct NextView: View {
    var body: some View {
        Text("✅ 再生が完了しました！")
            .font(.largeTitle)
            .padding()
    }
}

// MARK: - Preview
#Preview {
    FirstView()
}