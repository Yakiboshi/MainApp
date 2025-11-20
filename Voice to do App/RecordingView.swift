import SwiftUI
import SwiftData
import AVFoundation
import Foundation
import Combine

// 録音画面：表示と同時に自動録音開始。停止で保存→通知→閉じる
struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorderViewModel()
    @StateObject private var routeManager = AudioRouteManager()
    // 二重保存防止ガード
    @State private var didFinalize: Bool = false

    let date: Date

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                // 背景（AudioPlayView と同グラデ）
                LinearGradient(
                    colors: [
                        Color(red: 12/255, green: 13/255, blue: 20/255),
                        Color(red: 48/255, green: 50/255, blue: 58/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: h/3)

                    // 経過時間（等幅）
                    Text(timeString(recorder.elapsedSec))
                        .font(.system(size: 44, weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .accessibilityLabel("録音経過時間")

                    Spacer().frame(height: 20)

                    // 軽量レベルメータ（バー型）
                    LightLevelMeterView(level: $recorder.level)
                        .frame(height: 80)
                        .padding(.horizontal, 32)

                    // 残り時間
                    Text("残り時間  \(timeString(recorder.remainingSec))")
                        .foregroundStyle(.white)
                        .font(.headline)
                        .padding(.top, 16)

                    // 入力切替ボタン（下から1/3付近）
                    Spacer()
                    VStack(spacing: 6) {
                        Button(action: {
                            routeManager.toggleBuiltInOutput()
                        }) {
                            Image(systemName: routeManager.hasExternalOutput
                                  ? "headphones.circle"
                                  : (routeManager.isUsingSpeaker ? "speaker.wave.2.circle.fill" : "phone.circle.fill"))
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(14)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("出力切り替え")
                        if routeManager.hasExternalOutput {
                            Text(routeManager.externalOutputName ?? "外部機器")
                                .font(Theme.circleButtonLabelFont)
                                .foregroundStyle(.white)
                        } else {
                            Text(routeManager.isUsingSpeaker ? "スピーカー" : "受話口")
                                .font(Theme.circleButtonLabelFont)
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer()

                    // 下部 3 ボタン（基準スタイル）
                    HStack(spacing: Theme.circleButtonSpacing) {
                        VStack(spacing: 6) {
                            Button(action: {
                                SoundManager.shared.play("cancell", ext: "mp3")
                                cancelAndClose()
                            }) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .font(Theme.circleButtonIconFont)
                                            .foregroundStyle(.white)
                                    )
                                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .accessibilityLabel("キャンセル")
                            Text("キャンセル")
                                .font(Theme.circleButtonLabelFont)
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 6) {
                            Button(action: { togglePause() }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                    .overlay(
                                        Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                                            .font(Theme.circleButtonIconFont)
                                            .foregroundStyle(.black)
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .accessibilityLabel(recorder.isPaused ? "再開" : "一時停止")
                            Text(recorder.isPaused ? "再開" : "一時停止")
                                .font(Theme.circleButtonLabelFont)
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 6) {
                            Button(action: { finishAndProceed() }) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                    .overlay(
                                        Image(systemName: "phone.down.fill")
                                            .font(Theme.circleButtonIconFont)
                                            .foregroundStyle(.white)
                                    )
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                            }
                            .accessibilityLabel("終了")
                            Text("終了")
                                .font(Theme.circleButtonLabelFont)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.bottom, h/12)
                }
            }
        }
        .onAppear {
            let maxMinutes = SortPreference.loadRecordingMaxMinutes()
            recorder.startRecording(for: date, maxDurationSec: maxMinutes * 60)
            routeManager.refreshOutputState()
        }
        // タイムアップ等で自動停止したときのフォールバック（保存に進む）
        .onChange(of: recorder.isRecording) { isRec in
            // 自動停止（上限到達等）時のみ遷移。手動終了後の二重呼び出しは didFinalize で抑止。
            if !isRec && !didFinalize {
                finishAndProceed()
            }
        }
    }

    private func togglePause() {
        if recorder.isPaused { recorder.resume() } else { recorder.pause() }
    }

    private func cancelAndClose() {
        recorder.cancel()
        dismiss()
    }

    private func finishAndProceed() {
        // 二重実行ガード（手動/自動の双方から呼ばれ得るため）
        guard !didFinalize else { return }
        didFinalize = true
        // 既に停止していても安全
        let newId = UUID()
        guard let res = recorder.stopRecording(renameToId: newId) else {
            // 停止失敗時は再試行を許可
            didFinalize = false
            return
        }
        // 保存日時は現在時刻（録音完了時）。予定日時は recordedAt（既存フィールド）
        let entity = RecordingEntity(
            id: newId,
            recordedAt: date,
            savedAt: Date(),
            fileName: res.fileName,
            duration: res.duration
        )
        modelContext.insert(entity)
        try? modelContext.save()
        // 新しい予定を通知キューに反映し、バッジベースも更新
        _ = AppBadgeManager.refresh(using: modelContext)
        LocalNotificationManager.shared.refreshAllNotifications(in: modelContext)
        NotificationRouter.shared.presentIntermediate(for: entity.id)
        dismiss()
    }

    private func timeString(_ t: Int) -> String {
        String(format: "%02d:%02d", max(0, t) / 60, max(0, t) % 60)
    }
}

// 軽量スクロール波形（Recorderの level を0.05sごとにサンプリングして縦線で描画）
private struct ScrollingWaveformView: View {
    @Binding var level: Double // 0...1
    let sampleCount: Int = 140
    @State private var samples: [Double] = []
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            let midY = size.height / 2
            let stepX = size.width / CGFloat(max(samples.count - 1, 1))
            var path = Path()
            for (idx, s) in samples.enumerated() {
                let x = CGFloat(idx) * stepX
                let amp = CGFloat(min(max(s, 0), 1)) * (size.height * 0.46)
                path.move(to: CGPoint(x: x, y: midY - amp))
                path.addLine(to: CGPoint(x: x, y: midY + amp))
            }
            ctx.stroke(path, with: .color(.white), lineWidth: 2)
        }
        .onReceive(timer) { _ in
            samples.append(level)
            if samples.count > sampleCount { samples.removeFirst(samples.count - sampleCount) }
        }
        .onAppear { samples = Array(repeating: 0, count: sampleCount) }
    }
}

// より軽量なバー型レベルメータ（描画負荷を抑える）
private struct LightLevelMeterView: View {
    @Binding var level: Double   // 0...1
    private let barCount = 9
    private let maxHeight: CGFloat = 70
    @State private var values: [Double] = Array(repeating: 0, count: 9)
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.95 - Double(i) * 0.06))
                    .frame(width: 6, height: 8 + CGFloat(values[i]) * maxHeight)
            }
        }
        .onReceive(timer) { _ in
            let v = min(max(level, 0), 1)
            var next = values
            next.removeFirst()
            next.append(v)
            // 緩やかな平滑化で過剰な再描画を抑制
            for idx in next.indices {
                values[idx] = values[idx] * 0.85 + next[idx] * 0.15
            }
        }
        .onAppear { values = Array(repeating: 0, count: barCount) }
    }
}
