import SwiftUI
import SwiftData
import UserNotifications
import UIKit

// 着信画面（擬似着信）
// docs/specs/chakusinplan.md の仕様に合わせた簡易UI。
// - 背景: ダークグラデーション（明示色指定）
// - 上部: 丸型の写真アイコン（SwiftyCrop 登録画像想定）
// - 中央: タイトル（白）と「保存日時からの電話」（灰色）
// - 下部: 丸型ボタン 2 つ（拒否/応答）
struct IncomingCallView: View {
    // ルーティング/状態
    let messageId: String?
    let fromVoicemail: Bool
    private let ringtone = RingtonePlayer()
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var router = NotificationRouter.shared

    // 表示用データ（SwiftData から取得）
    @State private var recording: RecordingEntity? = nil

    // プレビュー判定（プレビュー時はサウンドを抑止）
    private var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    Color(red: 12/255, green: 13/255, blue: 20/255),
                    Color(red: 48/255, green: 50/255, blue: 58/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()


            GeometryReader { proxy in
                let h = proxy.size.height
                // アイコンは端末幅に追従（上限 280pt）
                let iconSize = min(proxy.size.width * 0.55, 280)
                // 上部から 2/5 の位置にアイコン中心が来るように調整
                let centerY = h * 0.40
                let topPadding = max(0, centerY - iconSize / 2)

                VStack(spacing: 12) {
                    // 上マージン
                    Spacer().frame(height: topPadding)

                    // 丸型写真（なければプレースホルダ）
                    Group {
                        if let data = recording?.iconImageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: iconSize, height: iconSize)
                                .clipShape(Circle())
                                .shadow(radius: 10)
                        } else {
                            Circle()
                                .fill(Color(red: 0.70, green: 0.72, blue: 0.75))
                                .frame(width: iconSize, height: iconSize)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(Color(red: 0.45, green: 0.47, blue: 0.50))
                                        .padding(iconSize * 0.25)
                                )
                        }
                    }

                    // タイトル
                    Text(recording?.title?.isEmpty == false ? (recording?.title ?? "") : "(タイトル名)")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 1, green: 1, blue: 1))
                        .padding(.top, 8)

                    // 日時テキスト（保存日時）。タイトルが自動生成でない場合のみ表示
                    if let rec = recording, shouldShowSubText(rec) {
                        Text("\(formattedDate(savedDate(for: rec))) からの電話")
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.72, green: 0.72, blue: 0.76))
                            .padding(.bottom, 8)
                    }

                    Spacer()

                    // 下部ボタン（6分の1 位置付近）
                    HStack(spacing: 80) {
                        // 拒否
                        VStack(spacing: 8) {
                            Button {
                                // 残通知キャンセル →（必要なら）スヌーズ再登録 → 終了
                                NotificationManager.shared.cancelAllNotifications(for: messageId)
                                if !fromVoicemail, let mid = messageId, !mid.isEmpty {
                                    var seconds: TimeInterval = 120 // 既定: 2分（保険）
                                    if let rec = recording, let m = rec.snoozeMin { seconds = TimeInterval(m * 60) }
                                    NotificationManager.shared.scheduleSnooze(for: mid, snoozeSeconds: seconds)
                                }
                                dismiss()
                                NotificationRouter.shared.dismissIncomingCall()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.92, green: 0.18, blue: 0.16))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "phone.down.fill")
                                        .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                                        .font(.system(size: 24, weight: .semibold))
                                }
                            }
                            Text("拒否")
                                .font(.caption)
                                .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                        }

                        // 応答
                        VStack(spacing: 8) {
                            Button {
                                // ループ着信音停止 → 履歴反映 → 通話画面へ
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
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.10, green: 0.78, blue: 0.22))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "phone.fill")
                                        .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                                        .font(.system(size: 24, weight: .semibold))
                                }
                            }
                            Text("応答")
                                .font(.caption)
                                .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                        }
                    }
                    .padding(.bottom, h / 6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            // 表示用データを読込
            if let mid = messageId, let uuid = UUID(uuidString: mid) {
                do {
                    let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
                    recording = try context.fetch(fd).first
                } catch { recording = nil }
            }

            // 残りのローカル通知をキャンセル
            NotificationManager.shared.cancelAllNotifications(for: messageId)
            // ループ再生開始（プレビュー時は抑止）
            if !isPreview { ringtone.startLooping() }
        }
        .onDisappear { ringtone.stop() }
        .onChange(of: router.showAfterCallForMessageId) { mid in
            // ルートが AfterCall を提示（UI側の追加処理はなし）
            guard mid != nil else { return }
        }
    }

    // MARK: - Helpers
    // 日付表示（yyyy/MM/dd HH:mm）
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }

    // タイトルが自動生成のものかどうか（新旧判定）
    private func isAutoGeneratedTitle(_ title: String) -> Bool {
        let suffix = " からの電話"
        guard title.hasSuffix(suffix) else { return false }
        let base = String(title.dropLast(suffix.count))
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.date(from: base) != nil
    }

    private func shouldShowSubText(_ rec: RecordingEntity) -> Bool {
        let title = (rec.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        if rec.isAutoTitle { return false }
        if isAutoGeneratedTitle(title) { return false }
        return true
    }

    // 保存日時を取得（savedAt → ファイル作成日時 → 今）
    private func savedDate(for rec: RecordingEntity) -> Date {
        if let d = rec.savedAt { return d }
        // 既存データの救済（ファイル属性）
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rec.fileName)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let d = attrs[.creationDate] as? Date {
            return d
        }
        return Date()
    }
}

#Preview {
    IncomingCallView(messageId: nil, fromVoicemail: false)
}
