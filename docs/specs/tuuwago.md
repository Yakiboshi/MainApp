SwiftUIで、通話後の「アフターメッセージ」画面を作りたいです。

【画面仕様】
・画面上部から3分の1に詳細画面で設定した丸型の写真アイコン（SwiftyCropで登録された画像）を表示。
・その下に白色でタイトルを表示。
・そのさらに下に灰色で小さく「（音声ファイルを保存した日時）からの電話」というテキストを表示。
・その下に、SwiftDataで保存された「アフターメッセージ」を白色で中央揃えで表示。
　- 横幅は画面幅の5分の4に固定。
　- スクロール可能（スクロールビュー内に配置）。
・もし詳細設定で「タスク内容」と「制限時間」が保存されていれば、アフターメッセージの下にそれらを表示。
　- これらも同じスクロール領域内でスクロール可能。
　- 一番下のタスクがボタンに隠れないように、余白を追加。

・画面下部6分の1の高さにボタンを配置：
　- 左端：白い丸ボタン（中に黒の引き返すマーク）、下に小さく白文字で「聞き直し」。
　　　これを押すと通話後画面の子ビューで @CallConversationView.swift と同じ画面を表示（ただし波形の下に再生音声のバーを表示する別バージョンとして現れる）
　- 右端：白い丸ボタン（中に黒のチェックマーク）、下に小さく白文字で「完了」。
　- 中央：もし詳細設定で「ショートカット用URL」が有効な場合のみ表示。
　　　黄緑の丸ボタン（中に白のリンクマーク）、下に白文字で「ショートカット」。
　　　タップでGoogle Chrome（なければSafari）を開き、指定URLを開く。

・ボタン群の背面には、画面下端からボタン位置に向かってフェードアウトする黒の背景を追加。
　（タスクやメッセージ部分はこの背景の下に入る）

【使用技術】
SwiftUI / SwiftData / ScrollView / LinearGradient / Link or UIApplication.openURL

【希望コード仕様】
・構造化コメント入り
・ボタンアクション部分はダミー関数でOK
・可読性の高い命名
・プレビュー付き

以下参考コード

import SwiftUI

struct AfterCallView: View {
    // 仮のプロパティ
    var title: String = "タイトル名"
    var callDate: Date = Date()
    var afterMessage: String = "これはアフターメッセージの例です。長文でもスクロールできるようになっています。"
    var taskDeadline: Date? = Date().addingTimeInterval(3600)
    var taskText: String? = "資料を確認して返信する。"
    var shortcutURL: URL? = URL(string: "https://www.google.com")
    var photo: UIImage? = UIImage(named: "sample") // SwiftyCrop画像想定
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景グラデーション
            LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.3),
                                    Color(red: 0.05, green: 0.05, blue: 0.15)],
                           startPoint: .top,
                           endPoint: .bottom)
            .ignoresSafeArea()
            
            VStack {
                Spacer().frame(height: UIScreen.main.bounds.height * 0.1)
                
                // 丸型画像
                if let image = photo {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                        .shadow(radius: 8)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 160, height: 160)
                }
                
                // タイトル
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                // 日時
                Text("\(formattedDate(callDate)) からの電話")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10)
                
                // スクロール可能領域（アフターメッセージ＋タスク）
                ScrollView {
                    VStack(spacing: 20) {
                        // アフターメッセージ
                        Text(afterMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .frame(width: UIScreen.main.bounds.width * 0.8)
                        
                        // タスク表示（存在する場合のみ）
                        if let taskDeadline = taskDeadline,
                           let taskText = taskText {
                            VStack(spacing: 6) {
                                Text("タスク期限：\(formattedDate(taskDeadline))")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Text(taskText)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .frame(width: UIScreen.main.bounds.width * 0.8)
                            }
                        }
                        
                        Spacer().frame(height: 100) // ボタンに埋もれない余白
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                
                Spacer()
            }
            
            // 下フェード背景
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: UIScreen.main.bounds.height * 0.2)
            .ignoresSafeArea(edges: .bottom)
            
            // 下部ボタン群
            HStack {
                // 左：聞き直し
                VStack(spacing: 5) {
                    Button(action: {
                        dismiss()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(Image(systemName: "arrow.uturn.left")
                                        .foregroundColor(.black)
                                        .font(.system(size: 30)))
                    }
                    Text("聞き直し")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
                Spacer()
                
                // 中央：ショートカット（存在時のみ）
                if let shortcutURL = shortcutURL {
                    VStack(spacing: 5) {
                        Button(action: {
                            openURL(shortcutURL)
                        }) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 70, height: 70)
                                .overlay(Image(systemName: "link")
                                            .foregroundColor(.white)
                                            .font(.system(size: 28)))
                        }
                        Text("ショートカット")
                            .foregroundColor(.white)
                            .font(.footnote)
                    }
                    Spacer()
                }
                
                // 右：完了
                VStack(spacing: 5) {
                    Button(action: {
                        print("完了ボタンが押されました")
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(Image(systemName: "checkmark")
                                        .foregroundColor(.black)
                                        .font(.system(size: 28)))
                    }
                    Text("完了")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, UIScreen.main.bounds.height * 0.06)
        }
    }
    
    // 日付フォーマット
    func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }
    
    // URLをChromeまたはSafariで開く
    func openURL(_ url: URL) {
        let chromeURL = URL(string: "googlechrome://\(url.absoluteString.dropFirst(8))")!
        if UIApplication.shared.canOpenURL(chromeURL) {
            UIApplication.shared.open(chromeURL)
        } else {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    AfterCallView()
}
# TODO: 通話後（AfterCall）画面 実装タスク（確定仕様反映）

このTODOは、あなたからの指示（サブテキスト文言統一/日数モード仕様/ロック時の配色/モデル更新/URL押下挙動 等）を反映した最新の実装計画です。下記を実装してから本ドキュメント下部の仕様・参考コードを参照してください。

■ モデル/データ
- `RecordingEntity` に基準時刻 `deadlineBaseAt: Date?` を追加。
  - 初回「通話画面 → 通話後画面」遷移時に一度だけ保存（存在すれば上書きしない）。
- 画面表示に利用する項目を取得: `title`, `isAutoTitle`, `savedAt`, `afterMessage`, `linkURLString`, `iconImageData`, `tasks`, `deadlineHours/Minutes/Days`, `answeredAt`, `inVoicemailInbox`, `status`。
- `savedDate(for:)` ヘルパー: `savedAt` → ファイル作成日時 → `Date()` の順で決定。
- 期限日時の算出
  - 時間/分モード: `deadlineBaseAt + H/M` で厳密な日時を算出。
  - 日数モード: `deadlineBaseAt` を起点に「(D日後の) その日の 23:59」を締切とする。
    - 例: 11/4 応答・D=3 → 11/7 の 23:59 が締切（11/8 になったらアウト）。

■ 上部レイアウト
- 丸型アイコン（SwiftyCrop画像）。無い場合はプレースホルダ。
- タイトル（括弧なし・白）。空の場合は自動生成タイトルを用い、その場合は直下のサブテキスト（保存日時の「からの電話」）を非表示。
- サブテキスト: 「yyyy/MM/dd HH:mm からの電話」で統一。

■ アフターメッセージ
- 空ならセクション非表示。ある場合は中央寄せ、横幅は画面の 80%。
- スクロール可能領域に配置（タスクも同一領域でスクロール）。

■ タスク見出し/期限表示/一覧
- 見出し: 「Nつのタスクあり」を大きめ白・左寄せ（左に余白を確保）。
- 期限表示（ある場合のみ）
  - 時間/分モード: 「目標時刻まで 00:30」等。数値部分は通常の2倍サイズ・黄緑。残り60分未満で mm:ss 表示＋赤色に変更。自動更新（<60分は毎秒、それ以外は毎分）。
  - 日数モード: 「目標まで D 日後」改行「YYYY/MM/DD まで」。
    - 「目標まで」「日後」は不透明（半透明にしない）。
    - 2行目は日付のみ（時刻は表示しない）。
- 締切到達後のロック
  - すべてのチェックボックスを無効化。
  - ロック時点でチェック済みのタスク: テキストを黄緑。
  - 未チェックのタスク: テキストを赤。
- タスクUI
  - 左にチェック、右に本文。タップで `isDone` を即時保存（締切前のみ）。
  - タスク間に適度な余白＋中央に仕切り線を配置。
  - 最下部は下部ボタンに隠れないよう十分なボトム余白を確保。

■ 下部ボタン/フェード/挙動
- 下端に黒→透明のフェード背景（ボタン背面）。
- 左: 「聞き直し」白丸＋Uターン。フルスクリーンの再生ビュー（`ReListenPlayerView`）を表示。
- 中: 「ショートカット」黄緑丸＋リンク。`linkURLString` が https:// で始まる時のみ表示。
  - Chrome 優先・無ければ Safari。押下後も AfterCall 画面は維持。
- 右: 「完了」白丸＋チェック。

■ モデル更新（必須）
- 「完了」押下時: `status = "played"`, `inVoicemailInbox = false` を設定して保存。既存のルーティングでクローズ。
- 「ショートカット」押下時も同様に `status = "played"`, `inVoicemailInbox = false` を保存（画面は維持）。

■ ユーティリティ/フォーマット
- 日時表示フォーマッタ（`yyyy/MM/dd HH:mm`）。日数モードの締切表示は `yyyy/MM/dd` のみ。
- 残時間の算出/色分岐（60分閾値）用のタイマー管理。
- タイトルが自動生成かを判定するヘルパー（必要に応じて使用）。

■ 設定/プロジェクト
- `Info.plist` に `LSApplicationQueriesSchemes` で `googlechrome` を追加。

■ テスト観点
- URL なし/あり（Chrome あり/なし）、アフターメッセージなし/あり、タスクなし/あり、時間/分モード・日数モード、締切直前/経過後の見え方、下部ボタンでコンテンツが隠れないこと。

---
