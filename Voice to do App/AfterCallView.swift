import SwiftUI

struct AfterCallView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("通話後")
                    .font(.largeTitle).bold()
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    // キーパッドへ遷移（タブ切替）して全画面を閉じる
                    NotificationRouter.shared.switchToTab(2)
                    NotificationRouter.shared.dismissIncomingCall()
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
        .onAppear {
            // AfterCall 遷移完了後に着信画面を裏で閉じる（確実性のため1秒遅延）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NotificationRouter.shared.dismissIncomingCall()
            }
        }
    }
}
