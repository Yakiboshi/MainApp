import SwiftUI

// 背景のみの極小ビュー（他UIは未実装）
struct AppTabsView: View {
    var body: some View {
        Theme.appGradient.ignoresSafeArea()
    }
}
