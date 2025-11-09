import SwiftUI
import SwiftData

// 録音画面：表示と同時に自動録音開始。停止で保存→通知→閉じる
struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorderViewModel()

    let date: Date

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("録音")
                    .font(.title).bold()
                Text("予定時刻: \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if recorder.isRecording {
                Text("🎙️ 録音中…")
                    .font(.title3)
                    .foregroundStyle(.red)
            } else {
                Text("🛑 録音停止")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                guard recorder.isRecording, let result = recorder.stopRecording() else { return }
                // 保存
                let entity = RecordingEntity(recordedAt: date, fileName: result.fileName, duration: result.duration)
                modelContext.insert(entity)
                try? modelContext.save()
                // 通知登録
                NotificationManager.shared.scheduleNotification(for: date)
                // 画面を閉じる（フルスクリーンカバーを閉じる）
                dismiss()
            } label: {
                Text("録音終了")
                    .font(.title2).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
            }
            .disabled(!recorder.isRecording)
        }
        .padding()
        .onAppear {
            // 自動録音開始
            recorder.startRecording(for: date)
        }
    }
}
