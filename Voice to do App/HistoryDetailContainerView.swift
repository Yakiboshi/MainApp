import SwiftUI
import SwiftData

struct HistoryDetailContainerView: View {
    @Environment(\.modelContext) private var context
    let recordingId: UUID

    var body: some View {
        Group {
            if let rec = fetch() {
                HistoryDetailScreen(entity: rec)
            } else {
                ZStack {
                    Theme.appGradient.ignoresSafeArea()
                    Text("対象の履歴が見つかりません")
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func fetch() -> RecordingEntity? {
        do {
            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == recordingId })
            return try context.fetch(fd).first
        } catch { return nil }
    }
}

private struct HistoryDetailScreen: View {
    let entity: RecordingEntity
    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button {
                        NotificationRouter.shared.dismissHistoryDetail()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left").bold()
                            Text("戻る")
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding([.top, .horizontal])

                Spacer()

                VStack(spacing: 12) {
                    Text(title())
                        .font(.title2).bold()
                        .foregroundStyle(.white)
                    if let at = entity.answeredAt {
                        Text(at.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()
            }
        }
    }

    private func title() -> String {
        if let t = entity.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return "\(f.string(from: entity.recordedAt)) からの電話"
    }
}

