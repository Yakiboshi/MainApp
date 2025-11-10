import SwiftUI
import SwiftData

struct PlannedDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let entity: RecordingEntity

    @State private var title: String = ""
    @State private var scheduledAt: Date = .now
    @State private var loaded: Bool = false

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("予定の編集")
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                    Text(entity.recordedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("タイトル")
                        .foregroundStyle(.white)
                    TextField(defaultTitle(), text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("予定日時")
                        .foregroundStyle(.white)
                    DatePicker("", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.white)
                        .colorMultiply(.white)
                    if !isFutureDate {
                        Text("未来の時刻を入力してください")
                            .font(.footnote)
                            .foregroundStyle(Color.red)
                    }
                }
                .padding(.horizontal)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        // キャンセル: 何も保存せず閉じる
                        dismiss()
                    } label: {
                        Text("キャンセル")
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.18))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        saveAndClose()
                    } label: {
                        Text("完了")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.green.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!isFutureDate)
                    .opacity(isFutureDate ? 1.0 : 0.6)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
        }
        .onAppear { if !loaded { load() } }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() {
        loaded = true
        title = entity.title ?? ""
        scheduledAt = entity.recordedAt
    }

    private func saveAndClose() {
        guard isFutureDate else { return }
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { t = defaultTitle() }
        entity.title = t
        // afterMessage / snooze は今回は未編集のため変更しない
        if entity.recordedAt != scheduledAt {
            entity.recordedAt = scheduledAt
            // 通知を再スケジュール
            NotificationManager.shared.cancelAllNotifications(for: entity.id.uuidString)
            NotificationManager.shared.scheduleNotification(for: scheduledAt, messageId: entity.id.uuidString)
        }
        try? context.save()
        dismiss()
    }

    private func defaultTitle() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return "\(f.string(from: scheduledAt)) からの電話"
    }
}

private extension PlannedDetailView {
    var isFutureDate: Bool { scheduledAt > Date() }
}
