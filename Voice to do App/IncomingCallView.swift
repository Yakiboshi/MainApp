import SwiftUI
import SwiftData
import UserNotifications

struct IncomingCallView: View {
    let messageId: String?
    let fromVoicemail: Bool
    private let ringtone = RingtonePlayer()
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var router = NotificationRouter.shared
    @State private var showAfter: Bool = false

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
                        // 拒否: 残通知キャンセル→スヌーズ再登録（留守電起点ではスヌーズしない）→閉じる
                        NotificationManager.shared.cancelAllNotifications(for: messageId)
                        if !fromVoicemail {
                            if let mid = messageId, !mid.isEmpty {
                                // snoozeMin（分）を参照。未設定は2分（デバッグ）
                                var seconds: TimeInterval = 120
                                if let uuid = UUID(uuidString: mid) {
                                    do {
                                        let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
                                        if let rec = try context.fetch(fd).first, let m = rec.snoozeMin {
                                            seconds = TimeInterval(m * 60)
                                        }
                                    } catch {}
                                }
                                NotificationManager.shared.scheduleSnooze(for: mid, snoozeSeconds: seconds)
                            }
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
                        // 応答: ループ着信音停止→履歴反映→通話画面（ルートカバー）へ
                        ringtone.stop()
                        if let mid = messageId, !mid.isEmpty {
                            if let uuid = UUID(uuidString: mid) {
                                do {
                                    let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
                                    if let rec = try context.fetch(fd).first {
                                        rec.status = "answered"
                                        rec.answeredAt = Date()
                                        rec.inVoicemailInbox = false
                                        try? context.save()
                                    }
                                } catch {}
                            }
                            NotificationRouter.shared.presentCall(for: mid)
                        }
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
        .onChange(of: router.showAfterCallForMessageId) { mid in
            guard mid != nil else { return }
            // ルートが AfterCall を提示
        }
    }
}
