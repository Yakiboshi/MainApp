SwiftUI と SwiftData を使った擬似着信アプリを開発しています。
ローカル通知の動作が複雑なので、下記の仕様に完全に合致する
「通知キュー管理システム（LocalNotificationManager）」を実装してください。

──────────────────────────────
【アプリの概要】
──────────────────────────────
・ユーザーはアラーム時刻を選択し、録音を行い、タイトルや詳細と共に SwiftData に保存します。
・アラーム時刻になるとローカル通知が届きます。
・通知を開くと擬似着信画面に遷移し、録音した音声が再生されます。
・通知に反応されなかった場合、そのデータは「留守電リスト」に移動されます。

SwiftData のモデル名とプロパティ名は、私のアプリ内の既存のものと自動的に整合させてください。

──────────────────────────────
【通知の基本仕様】
──────────────────────────────

▼ 1. アラーム本体（25回通知）
・1つのアラームにつき「7秒間隔 × 25回（約175秒）」の通知を連続発行する。
・iOS の “ローカル通知64件上限” を守るため、同時に通知を予約できるアラームは 1件に制限する。
・25回通知が完了するまでは、他のアラームは予約しない。

▼ 2. キュー方式（順番待ち）
・SwiftData に保存されているアラームの中から、
　現在時刻より未来のデータを抽出し、時刻の早い順に並べる。
・通知が完全に終了したタイミングで、次のアラームを1件だけ予約する。
・予定時刻を過ぎてしまったアラームは通知登録せず、「留守電リスト」に移動する。

▼ 3. 通知無視時の挙動
・ユーザーが通知をタップしなかった場合でも、
　7秒×25回の通知がすべて発行し終わった時点でそのアラームは完了扱い。
・完了後、キューを再チェックして次のアラームを登録する。

──────────────────────────────
【スヌーズの仕様（重要）】
──────────────────────────────
・1つのアラームにつき “スヌーズを登録できるのは1回だけ”。
　（スヌーズが鳴った後、ユーザーが再びスヌーズを押した場合は改めて1回だけ登録可能）

・アプリ全体として、同時にスヌーズ予約を持てるアラームは「最大4件まで」。

・スヌーズは「7秒間隔 × 9回（約1分）」の通知で構成する。

・スヌーズは本体アラームの順番待ちキューには含めない。
　（スヌーズは独立した短期再通知として扱う）

・スヌーズ（9回×最大4件）と本体アラーム（25回）が
　ローカル通知64件上限を絶対に超えないように調整すること。

──────────────────────────────
【削除・変化時の仕様】
──────────────────────────────
・現在通知中のアラームデータが削除された場合 → 通知をキャンセルし、次の予定を予約する。
・順番待ちのアラームが削除された場合 → そのままスキップ。
・スヌーズ中のアラームが削除された場合 → スヌーズ通知もキャンセルする。

──────────────────────────────
【必要なクラス・関数（名前はAI側で調整可）(既存のファイルがある場合はそちらを上書きする形で大丈夫)】
──────────────────────────────
・LocalNotificationManager（UNUserNotificationCenterDelegate）
・scheduleMainAlarm()        → 本体25回通知
・scheduleSnooze()           → 9回通知（1データにつき1回）
・refreshQueue()             → 順番待ち構築
・convertExpiredToVoicemail()→ 留守電へ移動
・handleNotificationFinished() → 次のアラーム登録

SwiftData のモデル構造は、既存のモデル名／プロパティ名／保存方式に合わせて自動で最適化してください。

──────────────────────────────
【欲しいもの】
──────────────────────────────
・LocalNotificationManager の完成コード
・本体アラームの予約処理コード
・スヌーズの予約処理コード
・キュー管理・留守電処理・削除処理のコード
・NotificationCenter の delegate 設定
・擬似着信画面へ遷移するための userInfo 付き通知生成

──────────────────────────────
【UI側の変更】
──────────────────────────────
・着信画面にて応答と拒否ボタンの間に「再通知」ボタンを用意、
 -スヌーズの際は再通知ボタンを押すことで登録できる。
 -見た目は応答、拒否ボタンと同じ大きさで白色、黒色のくり返しのマークを挿入。　下には小さく白色のスヌーズのテキスト
 -再通知ボタンの右下に残り回数を表示、すでに同時に4回登録されている場合はボタンを無効にする。
 -押した後はスヌーズ登録と同時にキーパッド画面に遷移
 -本来の拒否ボタンはスヌーズ登録せずにキーパッド画面へ、その際データは留守電へ行く。
・予定のリストコンテンツの中の表示内容変更
 -データ作成日時を消して、代わりに着信日時に変更
 -現時点でローカル通知登録されている予定の1分後、2分後、3分後に登録されている順番待ちデータは、リストの着信日時の文字を黄色にして、その下に灰色で小さく、"前の着信に埋もれて発信されない可能性があります。"というテキストを挿入。
・同時刻での予約を不可能にする
 -予定が登録されたらキーパッドで同時刻で登録しようとした際にDISTINATIONTIMEを赤色になりコールボタンを遷移不可の状態になるようにする。
 -予定画面にて予定時刻を変更した際も同様にバリテーションを再登録。また予定日時変更の際に別の予定と被せるようにできない(被ったら完了ボタンを押せない)ようにする。
 -予定が削除された場合は、同時にバリテーションを解除する。

以上の仕様に完全準拠した実装コードを生成してください。

以下システムのサンプルコード
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class LocalNotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = LocalNotificationManager()

    func scheduleMainAlarm(for alarm: AlarmEntity) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for i in 0..<25 {
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(i * 7),
                repeats: false
            )

            let content = UNMutableNotificationContent()
            content.title = alarm.title
            content.sound = .default
            content.userInfo = ["alarmID": alarm.id.uuidString]

            let request = UNNotificationRequest(
                identifier: "\(alarm.id.uuidString)-main-\(i)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    func scheduleSnooze(for alarm: AlarmEntity) {
        guard alarm.snoozeActive == false else { return }

        for i in 0..<9 {
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval((i * 7) + 60),
                repeats: false
            )

            let content = UNMutableNotificationContent()
            content.title = "Snooze: \(alarm.title)"
            content.sound = .default
            content.userInfo = ["alarmID": alarm.id.uuidString]

            let request = UNNotificationRequest(
                identifier: "\(alarm.id.uuidString)-snooze-\(i)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }

        alarm.snoozeActive = true
    }

    func handleNotificationFinished() {
        let alarms = fetchFutureAlarms()

        for alarm in alarms where alarm.targetDate < Date() {
            alarm.isVoicemail = true
        }

        if let next = alarms
            .filter({ $0.targetDate > Date() })
            .sorted(by: { $0.targetDate < $1.targetDate })
            .first {

            scheduleMainAlarm(for: next)
        }
    }

    private func fetchFutureAlarms() -> [AlarmEntity] {
        // AIが自動で SwiftData の構文に変換
        return []
    }
}
