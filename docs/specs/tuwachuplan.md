SwiftUIで、擬似着信の「応答後」に表示される音声再生画面を作りたいです。

【画面仕様】
・背景は着信画面と同じダークグラデーション
・画面上部から3分の1に、詳細登録画面で設定された丸型の写真アイコン（SwiftyCropで登録済みの画像）を配置。
・その下に「音声再生時間（例：00:25）」を白色の大きな文字で中央表示。
・中央に「疑似的な波形アニメーション」（音声が流れているように見える動く波線）。
・画面下部から6分の1の位置に、赤い丸ボタン（中に白の電話を切るマーク）を中央配置。(簡易UIで機能をすでに実装済みの次の画面へ遷移するボタン)
・その真下に小さく白文字で「通話終了」と表示。


【希望コード仕様】
・見やすくコメントを追加
・波形は疑似的なアニメーション（ランダムな高さの線を繰り返し動かす）

以下サンプルコード

import SwiftUI

struct VoiceCallView: View {
    @Environment(\.dismiss) var dismiss
    
    var photo: UIImage? = UIImage(named: "sample") // SwiftyCrop画像
    @State private var elapsedTime: Double = 25
    @State private var waveValues: [CGFloat] = Array(repeating: 0.5, count: 20)
    @State private var animateWave = false
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.18),
                                    Color(red: 0.12, green: 0.12, blue: 0.24)],
                           startPoint: .top,
                           endPoint: .bottom)
            .ignoresSafeArea()
            
            VStack {
                Spacer().frame(height: UIScreen.main.bounds.height * 0.1)
                
                // 丸型写真
                if let image = photo {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 160, height: 160)
                }
                
                // 再生時間表示
                Text(formatTime(elapsedTime))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 24)
                
                // 疑似波形アニメーション
                WaveformView(isAnimating: $animateWave)
                    .frame(height: 80)
                    .padding(.vertical, 20)
                
                Spacer()
                
                // 通話終了ボタン
                VStack(spacing: 8) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 80, height: 80)
                            Image(systemName: "phone.down.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 30))
                                .rotationEffect(.degrees(135))
                        }
                    }
                    Text("通話終了")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                .padding(.bottom, UIScreen.main.bounds.height * 0.1)
            }
        }
        .onAppear {
            startWaveAnimation()
        }
    }
    
    // 秒数を分:秒に整形
    func formatTime(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%02d : %02d", min, sec)
    }
    
    // 疑似波形アニメーション制御
    func startWaveAnimation() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
            animateWave = true
        }
    }
}

// 疑似波形を描画するサブビュー
struct WaveformView: View {
    @Binding var isAnimating: Bool
    @State private var values: [CGFloat] = (0..<30).map { _ in CGFloat.random(in: 0.2...1.0) }
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<values.count, id: \.self) { i in
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: geo.size.height * values[i])
                }
            }
            .onChange(of: isAnimating) { newValue in
                if newValue {
                    Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            values = (0..<30).map { _ in CGFloat.random(in: 0.2...1.0) }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VoiceCallView()
}
