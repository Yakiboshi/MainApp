import SwiftUI

// 初期化版のキーパッド画面（プレースホルダ）
struct KeypadView: View {
    var body: some View {
        ZStack {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("キーパッド（初期化済）")
                    .font(.title).bold()
                    .foregroundStyle(Theme.primaryText)
                Text("画像確認タイム → 実装 → 動作確認 の順で再構築します")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
