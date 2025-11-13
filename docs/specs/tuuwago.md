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
