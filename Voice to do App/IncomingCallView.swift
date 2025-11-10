import SwiftUI
import UserNotifications

struct IncomingCallView: View {
    let messageId: String?
    private let ringtone = RingtonePlayer()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var router = NotificationRouter.shared
    @State private var showCall: Bool = false

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
                        // 拒否: 残通知キャンセル→スヌーズ再登録（デバッグ既定: 60秒）→閉じる
                        NotificationManager.shared.cancelAllNotifications(for: messageId)
                        if let mid = messageId, !mid.isEmpty {
                            NotificationManager.shared.scheduleSnooze(for: mid, snoozeSeconds: 60)
                        }
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
                        // 応答: ループ着信音停止→通話画面へ
                        ringtone.stop()
                        showCall = true
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
        .onAppear {
            // 残りのローカル通知をキャンセル
            NotificationManager.shared.cancelAllNotifications(for: messageId)
            // ループ再生開始（原音）
            ringtone.startLooping()
        }
        .onDisappear {
            // 停止
            ringtone.stop()
        }
        .fullScreenCover(isPresented: $showCall) {
            CallConversationView(messageId: messageId ?? "")
                .ignoresSafeArea()
        }
        .onChange(of: router.showAfterCallForMessageId) { mid in
            guard mid != nil else { return }
            // 通話画面を裏で閉じる（AfterCall はルートで表示される）
            showCall = false
        }
    }
}
