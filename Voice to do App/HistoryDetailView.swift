import SwiftUI

struct HistoryDetailView: View {
    let entity: RecordingEntity
    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(title())
                    .font(.title2).bold()
                    .foregroundStyle(.white)
                if let at = entity.answeredAt {
                    Text(at.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding()
        }
    }

    private func title() -> String {
        if let t = entity.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return "\(f.string(from: entity.recordedAt)) からの電話"
    }
}

