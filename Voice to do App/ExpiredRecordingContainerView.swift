import SwiftUI
import SwiftData

struct ExpiredRecordingContainerView: View {
    @Environment(\.modelContext) private var context
    let recordingId: UUID

    var body: some View {
        Group {
            if let rec = fetch() {
                ExpiredRecordingView(entity: rec)
            } else {
                ZStack {
                    Theme.appGradient.ignoresSafeArea()
                    Text("対象の録音が見つかりません")
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func fetch() -> RecordingEntity? {
        do {
            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == recordingId })
            return try context.fetch(fd).first
        } catch {
            return nil
        }
    }
}

private struct ExpiredRecordingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entity: RecordingEntity

    private let router = NotificationRouter.shared

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack {
                Spacer()
                Text("予定時刻が過ぎました。")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
                HStack {
                    VStack(spacing: 6) {
                        Button {
                            deleteRecording()
                        } label: {
                            Circle()
                                .fill(Color.red)
                                .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                .overlay(
                                    Image(systemName: "trash")
                                        .foregroundStyle(.white)
                                        .font(Theme.circleButtonIconFont)
                                )
                        }
                        Text("録音を削除")
                            .foregroundStyle(.white)
                            .font(Theme.circleButtonLabelFont)
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        Button {
                            moveToHistory()
                        } label: {
                            Circle()
                                .fill(Color.green)
                                .frame(width: Theme.circleButtonSize, height: Theme.circleButtonSize)
                                .overlay(
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(.white)
                                        .font(Theme.circleButtonIconFont)
                                )
                        }
                        Text("履歴へ")
                            .foregroundStyle(.white)
                            .font(Theme.circleButtonLabelFont)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    private func deleteRecording() {
        // 音声ファイルを削除
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(entity.fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        context.delete(entity)
        try? context.save()
        router.dismissExpiredRecording()
        dismiss()
    }

    private func moveToHistory() {
        // タイトルを「時刻が超えた音声ファイル(番号)」に設定し、履歴表示用フラグを立てる
        let prefix = "時刻が超えた音声ファイル("
        let fd = FetchDescriptor<RecordingEntity>()
        let all = (try? context.fetch(fd)) ?? []
        let count = all.filter { ($0.title ?? "").hasPrefix(prefix) }.count
        entity.title = "時刻が超えた音声ファイル(\(count + 1))"
        entity.isExpired = true
        entity.status = "answered"
        entity.answeredAt = Date()
        try? context.save()

        router.dismissExpiredRecording()
        // 履歴タブへ遷移
        router.switchToTab(1)
        dismiss()
    }
}

