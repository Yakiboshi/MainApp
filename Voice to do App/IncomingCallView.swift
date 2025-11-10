import SwiftUI

struct IncomingCallView: View {
    let messageId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("擬似着信")
                    .font(.largeTitle).bold()
                    .foregroundStyle(.white)
                if let id = messageId, !id.isEmpty {
                    Text("ID: \(id)")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                HStack(spacing: 32) {
                    Button {
                        // とりあえず画面のみ：閉じる
                        dismiss()
                        NotificationRouter.shared.dismissIncomingCall()
                    } label: {
                        Text("拒否")
                            .font(.title3).bold()
                            .frame(width: 120, height: 52)
                            .background(Color.red.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Button {
                        // とりあえず画面のみ：閉じる
                        dismiss()
                        NotificationRouter.shared.dismissIncomingCall()
                    } label: {
                        Text("応答")
                            .font(.title3).bold()
                            .frame(width: 120, height: 52)
                            .background(Color.green.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.bottom, 32)
            }
            .padding()
        }
    }
}

