import SwiftUI
import AVFoundation

/// 簡易トリミングビュー:
/// - 選択した音声の長さを取得し、7秒固定ブロックの開始位置をスライダーで指定する。
/// - 実際のトリミングとフェード処理は NotificationSoundExporter に委譲する。
struct AudioTrimmingView: View {
    let audioURL: URL
    @Binding var startTime: Double
    let trimDuration: Double = 7.0

    @State private var totalDuration: Double = 0
    @State private var maxStart: Double = 0
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("トリミング開始位置")
                    .foregroundStyle(Color.white)
                Spacer()
                if totalDuration > 0 {
                    Text(String(format: "%.1f / %.1f 秒", startTime, totalDuration))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .font(.caption)
                }
            }

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if totalDuration <= 0 {
                Text("音声の長さを取得できませんでした")
                    .foregroundStyle(Color.white.opacity(0.7))
                    .font(.footnote)
            } else {
                Slider(
                    value: Binding(
                        get: { startTime },
                        set: { newValue in
                            startTime = min(max(0, newValue), maxStart)
                        }
                    ),
                    in: 0...maxStart
                )
                .tint(.white)
            }
        }
        .onAppear(perform: loadDurationIfNeeded)
    }

    private func loadDurationIfNeeded() {
        guard totalDuration == 0, !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: audioURL)
            let duration = CMTimeGetSeconds(asset.duration)
            let safeDuration = duration.isFinite && duration > 0 ? duration : 0
            let maxStart = max(0, safeDuration - trimDuration)
            DispatchQueue.main.async {
                self.totalDuration = safeDuration
                self.maxStart = maxStart
                if self.startTime > maxStart {
                    self.startTime = maxStart
                }
                self.isLoading = false
            }
        }
    }
}
