import SwiftUI
import SwiftData

struct CallConversationView: View {
    let messageId: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = AudioPlayerViewModel()
    // AfterCall 表示は NotificationRouter 経由に変更（裏で通話画面を閉じるため）
    @State private var errorText: String? = nil

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("通話中")
                    .font(.largeTitle).bold()
                    .foregroundStyle(.white)
                if let msg = errorText {
                    Text(msg).foregroundStyle(.white).padding(.horizontal)
                } else {
                    ProgressView().tint(.white)
                }
                Spacer()
                Button {
                    // 手動終了 → AfterCallをリクエスト
                    player.stop()
                    NotificationRouter.shared.presentAfterCall(for: messageId)
                } label: {
                    Text("通話終了")
                        .font(.title3).bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.red.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .padding()
        }
        .onAppear { startPlayback() }
        .onDisappear { player.stop() }
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
}
