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
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

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
                let iconSize = min(proxy.size.width * (isPad ? 0.6 : 0.55), isPad ? 340 : 280)
                // 上部から 2/5 の位置にアイコン中心が来るように調整
                let centerY = h * (isPad ? 0.32 : 0.40)
                let topPadding = max(0, centerY - iconSize / 2)

                VStack(spacing: 12) {
                    // 上マージン
                    Spacer().frame(height: topPadding)

                    // 丸型写真（なければプレースホルダ）
                    Group {
                        if let data = recording?.iconImageData ?? DefaultIconStore.load(),
                           let ui = UIImage(data: data) {
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

                    // 下部ボタン（録音画面に合わせたスタイル）
                    let scale = isPad ? 2.0 : 1.0
                    let buttonSize = Theme.circleButtonSize * scale
                    let iconFont = Font.system(size: 22 * scale, weight: .bold)
                    let labelFont = Font.system(size: 12 * scale, weight: .medium)
                    HStack(spacing: Theme.circleButtonSpacing * scale) {
                        // 拒否
                        VStack(spacing: 8) {
                            Button {
                                SoundManager.shared.play("start", ext: "mp3")
                                // 残通知キャンセル → 分岐
                                if let mid = messageId, let uuid = UUID(uuidString: mid) {
                                    if !fromVoicemail {
                                        // 通常着信: 留守電へ移行
                                        do {
                                            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
                                            if let rec = try context.fetch(fd).first {
                                                rec.status = "missed"
                                                rec.inVoicemailInbox = true
                                                rec.isSnoozed = false
                                                try? context.save()
                                                // 留守電数が変わるため、バッジベースを更新してから再スケジュール
                                                _ = AppBadgeManager.refresh(using: context)
                                                LocalNotificationManager.shared.refreshAllNotifications(in: context)
                                            }
                                        } catch { }
                                    }
                                }
                                NotificationManager.shared.cancelAllNotifications(for: messageId)
                                if fromVoicemail {
                                    // 留守電からの着信: 留守電タブへ戻る
                                    NotificationRouter.shared.switchToTab(4)
                                } else {
                                    // 通常着信: キーパッドへ戻る
                                    NotificationRouter.shared.switchToTab(2)
                                }
                                NotificationRouter.shared.dismissIncomingCall()
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.92, green: 0.18, blue: 0.16))
                                        .frame(width: buttonSize, height: buttonSize)
                                    Image(systemName: "phone.down.fill")
                                        .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                                        .font(iconFont)
                                }
                            }
                            Text("拒否")
                                .font(labelFont)
                                .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                        }

                        // 再通知（スヌーズ） ※留守電起点では非表示
                        if !fromVoicemail {
                            VStack(spacing: 6) {
                                Button {
                                    guard let rec = recording else { return }
                                    LocalNotificationManager.shared.scheduleSnooze(for: rec, in: context)
                                    NotificationRouter.shared.switchToTab(2)
                                    NotificationRouter.shared.dismissIncomingCall()
                                    dismiss()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: buttonSize, height: buttonSize)
                                            .overlay(
                                                Image(systemName: "repeat")
                                                    .foregroundStyle(Color.black)
                                                    .font(iconFont)
                                            )
                                    }
                                }

                                VStack(spacing: 2) {
                                    Text("スヌーズ")
                                        .font(labelFont)
                                        .foregroundStyle(Color.white)
                                }
                            }
                        }

                        // 応答
                        VStack(spacing: 8) {
                            Button {
                                SoundManager.shared.play("start", ext: "mp3")
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
                                                rec.isSnoozed = false
                                                try? context.save()
                                                // 履歴側の未完了タスク数が変わる可能性があるため、バッジベースを更新してから再スケジュール
                                                _ = AppBadgeManager.refresh(using: context)
                                                LocalNotificationManager.shared.refreshAllNotifications(in: context)
                                            }
                                        } catch {}
                                    }
                                    NotificationRouter.shared.presentCall(for: mid)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.10, green: 0.78, blue: 0.22))
                                        .frame(width: buttonSize, height: buttonSize)
                                    Image(systemName: "phone.fill")
                                        .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                                        .font(iconFont)
                                }
                            }
                            Text("応答")
                                .font(labelFont)
                                .foregroundStyle(Color(red: 1, green: 1, blue: 1))
                        }
                    }
                    .padding(.bottom, isPad ? h / 9 : h / 6)
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

            // 残りのローカル通知をキャンセル（着信画面表示中は鳴らさない）
            NotificationManager.shared.cancelAllNotifications(for: messageId)
            // 擬似着信音ループ再生（プレビュー時は抑止）
            if !isPreview {
                let url = CustomRingtoneManager.currentRingtoneURL()
                ringtone.startLooping(with: url)
            }

            // 新仕様ではスヌーズ回数制限は設けないため、事前チェックは不要
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
