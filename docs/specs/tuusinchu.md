iOSアプリのSwiftUIで以下のレイアウトを作成してください：

背景色は黒色の暗めのグラデーション（上が濃く、下がやや明るめ）。

画面上部から3分の1程度の位置に「通信中」という白いテキストを中央に表示。

画面中央に、読み込み中を表す「アクティビティインジケータ（ProgressView）」を配置。

画面下部の6分の1程度の位置に、赤い丸のボタン（中に白いバツマーク「×」）を配置。

赤いボタンをタップすると、前の画面に戻る（.dismiss()で閉じる）。

ボタンは丸く、影付きで、中央下に固定。

🧾【SwiftUI サンプルコード】
import SwiftUI

struct CommunicationView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                    .frame(height: UIScreen.main.bounds.height / 3)

                // 通信中テキスト
                Text("通信中")
                    .foregroundColor(.white)
                    .font(.title)
                    .bold()

                Spacer()

                // アクティビティインジケータ
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2.0)

                Spacer()

                // 閉じるボタン
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(.bottom, UIScreen.main.bounds.height / 6)
            }
        }
    }
}

#Preview {
    CommunicationView()
}

作成手順は、背景→VstackでUIパーツ配置→微調整　でお願いします。
