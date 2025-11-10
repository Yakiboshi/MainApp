import SwiftUI
import SwiftData

struct AfterCallView: View {
    let messageId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var afterMessage: String = ""
    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("通話後")
                    .font(.largeTitle).bold()
                    .foregroundStyle(.white)
                if !afterMessage.isEmpty {
                    Text(afterMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                }
                Spacer()
                Button {
                    // 無アニメーションで順に閉じる
                    withAnimation(nil) { NotificationRouter.shared.switchToTab(2) }
                    withAnimation(nil) {
                        NotificationRouter.shared.dismissCall()
                        NotificationRouter.shared.dismissIncomingCall()
                        NotificationRouter.shared.dismissAfterCall()
                    }
                    dismiss()
                } label: {
                    Text("完了")
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.green.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .padding()
        }
        .onAppear { loadAfterMessage() }
    }

    private func loadAfterMessage() {
        guard let mid = messageId, let uuid = UUID(uuidString: mid) else { return }
        do {
            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
            if let rec = try context.fetch(fd).first, let msg = rec.afterMessage {
                afterMessage = msg
            }
        } catch {}
    }
}
