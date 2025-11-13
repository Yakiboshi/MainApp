【画面構成と動作仕様】

・画面上部から約5分の2の位置に「詳細画面で設定した丸型の写真アイコン（SwiftyCropで登録済みの画像）」を大きく表示(640pt*640ptの大きさ)。
・その下に、詳細登録画面で入力された「タイトル文字列」を白色で中央配置。
・そのさらに下（タイトル直下）に、小さめの灰色文字で「（音声ファイルを保存した日時）からの電話」というテキストを表示。
・画面下部から6分の1ほどの位置に、横並びで2つの丸ボタン(64pt*64ptの大きさ)を配置：
　- 左：赤い丸（中に白の電話を切るアイコン）
　- 右：黄緑の丸（中に白の電話に出るアイコン）
　※これらのボタンは既に簡易UI実装済み。
・背景はダークグラデーション（通信、発信画面と同じ色の背景）。

【希望コード仕様】
・見やすくコメントを入れる
・色指定はColor(red: , green: , blue:) か Color(hex:) 形式で明示
・レイアウトはGeometryReaderかVStackを使用
・プレビュー付きで作成

以下サンプルコード

import SwiftUI

struct IncomingCallView: View {
    @Environment(\.dismiss) var dismiss
    
    // 既存のSwiftDataから取得する想定
    var title: String = "タイトル名"
    var callDate: Date = Date()
    var photo: UIImage? = UIImage(named: "sample") // SwiftyCrop画像
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.18),
                                    Color(red: 0.12, green: 0.12, blue: 0.24)],
                           startPoint: .top,
                           endPoint: .bottom)
            .ignoresSafeArea()
            
            VStack {
                Spacer().frame(height: UIScreen.main.bounds.height * 0.1)
                
                // 丸型写真
                if let image = photo {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 180, height: 180)
                }
                
                // タイトル
                Text(title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                // 日時テキスト
                Text("\(formattedDate(callDate)) からの電話")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
                
                // ローディングアニメーション
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Spacer()
                
                // 拒否・応答ボタン
                HStack(spacing: 80) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 80, height: 80)
                            Image(systemName: "phone.down.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 28))
                                .rotationEffect(.degrees(135))
                        }
                    }
                    
                    Button(action: {
                        // 音声再生画面へ遷移処理
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 80, height: 80)
                            Image(systemName: "phone.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 28))
                                .rotationEffect(.degrees(45))
                        }
                    }
                }
                .padding(.bottom, UIScreen.main.bounds.height * 0.1)
            }
        }
    }
    
    // 日付整形
    func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    IncomingCallView()
}
