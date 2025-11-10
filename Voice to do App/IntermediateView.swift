import SwiftUI
import SwiftData

struct IntermediateView: View {
    let recordingId: UUID
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [RecordingEntity]

    @State private var title: String = ""
    @State private var afterMessage: String = ""
    @State private var snooze: Int = 2 // 分、デフォルト2分（デバッグ）
    @State private var loaded: Bool = false

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("詳細設定")
                    .font(.title).bold()
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("タイトル").foregroundStyle(.white.opacity(0.9))
                    TextField("（発信日時）からの電話", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("アフターメッセージ").foregroundStyle(.white.opacity(0.9))
                    TextEditor(text: $afterMessage)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white))
                }
                .padding(.horizontal)

                HStack {
                    Text("スヌーズ（分）").foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Stepper(value: $snooze, in: 1...120) {
                        Text("\(snooze) 分").foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    saveAndProceed()
                } label: {
                    Text("次へ")
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.green.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 24)
        }
        .onAppear { if !loaded { load() } }
    }

    private func load() {
        loaded = true
        do {
            let descriptor = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == recordingId })
            if let rec = try context.fetch(descriptor).first {
                title = rec.title ?? defaultTitle(from: rec.recordedAt)
                afterMessage = rec.afterMessage ?? ""
                snooze = rec.snoozeMin ?? 2
            }
        } catch { }
    }

    private func saveAndProceed() {
        do {
            let descriptor = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == recordingId })
            if let rec = try context.fetch(descriptor).first {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                rec.title = t.isEmpty ? defaultTitle(from: rec.recordedAt) : t
                let am = afterMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                rec.afterMessage = am
                rec.snoozeMin = snooze
                try context.save()
            }
        } catch { }
        // 予定タブへ切替し、中間画面を閉じる
        NotificationRouter.shared.switchToTab(3)
        NotificationRouter.shared.dismissIntermediate()
        dismiss()
    }

    private func defaultTitle(from date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return "\(f.string(from: date)) からの電話"
    }
}

