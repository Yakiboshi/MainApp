import SwiftUI

struct AppTabsView: View {
    @State private var selected: Tab = .keypad

    // 元の順序: 設定 / 履歴 / キーパッド / 予定 / 留守電
    enum Tab: Hashable { case settings, history, keypad, upcoming, voicemail }

    var body: some View {
        ZStack {
            Theme.appBlue.ignoresSafeArea()
            TabView(selection: $selected) {
                SettingsPlaceholderView()
                    .tabItem {
                        Image(systemName: "gearshape.fill").renderingMode(.template)
                        Text("設定")
                    }
                    .tag(Tab.settings)

                HistoryPlaceholderView()
                    .tabItem {
                        Image(systemName: "clock").renderingMode(.template)
                        Text("履歴")
                    }
                    .tag(Tab.history)

                KeypadView()
                    .tabItem {
                        Image(systemName: "phone.fill").renderingMode(.template)
                        Text("キーパッド")
                    }
                    .tag(Tab.keypad)

                UpcomingPlaceholderView()
                    .tabItem {
                        Image(systemName: "calendar").renderingMode(.template)
                        Text("予定")
                    }
                    .tag(Tab.upcoming)

                VoicemailPlaceholderView()
                    .tabItem {
                        Image(systemName: "tray.fill").renderingMode(.template)
                        Text("留守電")
                    }
                    .tag(Tab.voicemail)
            }
            .background(Theme.appBlue.ignoresSafeArea())
            .zIndex(1)
        }
        .onAppear { selected = .keypad }
        .tint(.white)
        .toolbarBackground(Theme.appBlue, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

private struct SettingsPlaceholderView: View {
    var body: some View {
        Text("設定（仮）")
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.appBlue.ignoresSafeArea())
    }
}
private struct HistoryPlaceholderView: View {
    var body: some View {
        Text("履歴（仮）")
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.appBlue.ignoresSafeArea())
    }
}
private struct UpcomingPlaceholderView: View {
    var body: some View {
        Text("着信予定（仮）")
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.appBlue.ignoresSafeArea())
    }
}
private struct VoicemailPlaceholderView: View {
    var body: some View {
        Text("留守電（仮）")
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.appBlue.ignoresSafeArea())
    }
}
