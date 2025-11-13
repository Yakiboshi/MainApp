import SwiftUI
import SwiftData
import UIKit
import Combine

struct CallConversationView: View {
    let messageId: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = AudioPlayerViewModel()
    // AfterCall 表示は NotificationRouter 経由に変更（裏で通話画面を閉じるため）
    @State private var errorText: String? = nil
    // UI 表示用
    @State private var photoImage: UIImage? = nil
    @State private var elapsedTime: Double = 0
    @State private var animateWave: Bool = false
    private let tick = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // 背景グラデーション（着信画面と同じ）
            LinearGradient(
                colors: [
                    Color(red: 12/255, green: 13/255, blue: 20/255),
                    Color(red: 48/255, green: 50/255, blue: 58/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                VStack {
                    Spacer().frame(height: proxy.size.height * 0.10)

                    // 丸型写真（SwiftyCrop 画像）。無い場合はプレースホルダ
                    Group {
                        if let image = photoImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 160)
                                .clipShape(Circle())
                                .shadow(radius: 10)
                        } else {
                            Circle()
                                .fill(Color(red: 0.70, green: 0.72, blue: 0.75))
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(Color(red: 0.45, green: 0.47, blue: 0.50))
                                        .padding(160 * 0.25)
                                )
                        }
                    }

                    // 再生時間（例: 00 : 25）
                    Text(formatTime(elapsedTime))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.top, 24)

                    // 疑似波形アニメーション
                    VStack(spacing: 8) {
                        WaveformView(isAnimating: $animateWave)
                            .frame(height: 40)
                            .padding(.horizontal, 48)
                        if let msg = errorText { Text(msg).foregroundStyle(.white.opacity(0.9)) }
                    }
                    .padding(.vertical, 16)

                    Spacer()

                    // 通話終了ボタン
                    VStack(spacing: 8) {
                        Button {
                            // 手動終了 → AfterCallをリクエスト
                            player.stop()
                            NotificationRouter.shared.presentAfterCall(for: messageId)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 80, height: 80)
                                Image(systemName: "phone.down.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 30))
                            }
                        }
                        Text("通話終了")
                            .foregroundStyle(.white)
                            .font(.footnote)
                    }
                    .padding(.bottom, proxy.size.height * 0.10)
                }
            }
        }
        .onAppear { startPlayback() }
        .onDisappear { player.stop() }
        .onReceive(tick) { _ in
            // 再生時間の更新と波形の状態反映
            elapsedTime = player.currentTime()
            animateWave = player.isPlaying
        }
    }

    private func startPlayback() {
        guard let uuid = UUID(uuidString: messageId) else {
            errorText = "再生対象が見つかりません (ID)"
            return
        }
        do {
            let descriptor = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
            if let rec = try context.fetch(descriptor).first {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = docs.appendingPathComponent(rec.fileName)
                if let data = rec.iconImageData, let img = UIImage(data: data) {
                    self.photoImage = img
                }
                elapsedTime = 0
                player.playURL(url, loops: 0) {
                    // 自動終了 → AfterCallをリクエスト
                    NotificationRouter.shared.presentAfterCall(for: messageId)
                }
            } else {
                errorText = "録音が見つかりません"
            }
        } catch {
            errorText = "読み込みエラー"
        }
    }

    // 秒数を mm : ss に整形
    private func formatTime(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%02d : %02d", min, sec)
    }
}

// 疑似波形を描画するサブビュー（ランダム高さのカプセルをアニメ）
private struct WaveformView: View {
    @Binding var isAnimating: Bool
    @State private var values: [CGFloat] = (0..<30).map { _ in CGFloat.random(in: 0.2...1.0) }
    @State private var timer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack { // full-size container so bars are centered within available width/height
                HStack(spacing: 3) {
                    ForEach(values.indices, id: \.self) { i in
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 3, height: geo.size.height * values[i])
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height) // occupy full GeometryReader space
            .onAppear { start() }
            .onDisappear { stop() }
            .onChange(of: isAnimating) { _ in
                isAnimating ? start() : stop()
            }
        }
    }

    private func start() {
        guard timer == nil, isAnimating else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                values = (0..<30).map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}
