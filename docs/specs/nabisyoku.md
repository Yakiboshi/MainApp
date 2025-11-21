

# 🟥 **原因①：TabView が NavigationStack の “中” にある**

これが最も多い失敗原因。

```
NavigationStack {
    TabView { ... } ← これ、ダメ
}
```

こうなっていると、**ナビゲーションの appearance に吸収されて、TabBar が色反映しません。**

---

# 🟩 **【解決策】TabView は root に置く**

```swift
TabView {
    …
}
```

→ その上に NavigationStack を置かない
→ NavigationStack を使いたい場合は “各タブ内で個別に” 使う

```swift
TabView {
    NavigationStack {
        KeypadView()
    }
    .tabItem { … }

    NavigationStack {
        SettingsView()
    }
    .tabItem { … }
}
```

---

# 🟥 **原因②：`UITabBarAppearance` が App.init() に入っていない**

これも非常に多いパターン。

以下は **必ず App struct の init(){} の “中” に書くこと**：

```swift
init() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(red: 20/255, green: 24/255, blue: 80/255, alpha: 1)

    UITabBar.appearance().standardAppearance = appearance
    if #available(iOS 15.0, *) {
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
```

もしここが **body に入っていたり、ContentView に入っていると反映されません。**

---

# 🟥 **原因③：TabView の背景に `.background()` を書いている**

SwiftUI がタブバーを再構築してしまい、UIKit 設定を “無視” することがあります。

例：

```swift
TabView {
   …
}
.background(Color.black)  ← これはトラブルの元
```

→ `.background` を使うと TabBar が透明になりやすいので注意。

---

# 🟥 **原因④：TabView を別の view に包んでいる**

以下も色が反映されない原因。

```
ZStack {
    Color.white
    TabView { ... }  ← これも反映されない原因になる
}
```

**TabView はできるだけ root 直下に置く必要があります。**

---

# 🟦 **あなたが今すぐ確認すべきチェックリスト（これを見れば 99% 解決）**

| チェック項目                              | YES / NO |
| ----------------------------------- | -------- |
| TabView がアプリの root になっている           | □        |
| NavigationStack が TabView の上に来ていない  | □        |
| App.init() に appearance を書いている      | □        |
| タブバーの `.background` をいじっていない        | □        |
| ZStack wrapping で TabView を覆っていない   | □        |
| TabView の上にスクリーン全体 gradient を当てていない | □        |

---

# 🟣 **正しい構造（これなら必ず色が変わる）**

### App.swift

```swift
@main
struct Voice_to_do_appApp: App {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 20/255, green: 24/255, blue: 80/255, alpha: 1)
        appearance.stackedLayoutAppearance.normal.iconColor = .white
        appearance.stackedLayoutAppearance.selected.iconColor = .green

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()   // ← ここが root
        }
    }
}
```

### MainTabView.swift

```swift
struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                KeypadView()
            }
            .tabItem {
                Label("キーパッド", systemImage: "phone")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("履歴", systemImage: "clock")
            }
        }
    }
}
```

---

