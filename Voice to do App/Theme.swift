import SwiftUI
import Foundation

// アプリ全体のテーマ種別
enum AppThemeKind: String, CaseIterable, Identifiable {
    case future      // 既存の青ベース
    case engineer    // 暗いグレー + 黄緑文字
    case emperor     // 暗い赤 + 薄い灰文字
    case paradox     // 暗い紫 + 薄い黄文字
    case singularity // 白背景 + 黒文字（特殊扱い）
    case abyss       // 黒背景 + 白文字

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .future: return "Future"
        case .engineer: return "Engineer"
        case .emperor: return "Emperor"
        case .paradox: return "Paradox"
        case .singularity: return "Singularity"
        case .abyss: return "Abyss"
        }
    }
}

// ユーザ設定に基づいて現在のテーマを管理
enum ThemeManager {
    static func currentKind() -> AppThemeKind {
        SortPreference.loadThemeKind()
    }

    static func applyTheme(kind: AppThemeKind) {
        let palette = ThemePalette(kind: kind)
        // ナビゲーションバーは全テーマ共通で暗いグレーに固定
        let navColor = UIColor(white: 0.08, alpha: 1.0)
        let navTextColor = UIColor.white

        // Window 背景（ステータスバー / ノッチ背面）
        let windowColor = palette.navBackground
        UIWindow.appearance().backgroundColor = windowColor
        if #available(iOS 13.0, *) {
            UIView.appearance(whenContainedInInstancesOf: [UITabBarController.self]).backgroundColor = windowColor
        }

        // Navigation bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = navColor
        nav.titleTextAttributes = [.foregroundColor: navTextColor]
        nav.largeTitleTextAttributes = [.foregroundColor: navTextColor]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = navTextColor
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().barTintColor = navColor

        // Tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = palette.tabBackground
        tab.shadowColor = .clear

        // 選択時
        tab.stackedLayoutAppearance.selected.iconColor = palette.tabSelected
        tab.inlineLayoutAppearance.selected.iconColor = palette.tabSelected
        tab.compactInlineLayoutAppearance.selected.iconColor = palette.tabSelected
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: palette.tabSelected]
        tab.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: palette.tabSelected]
        tab.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: palette.tabSelected]
        // 非選択時
        tab.stackedLayoutAppearance.normal.iconColor = palette.tabUnselected
        tab.inlineLayoutAppearance.normal.iconColor = palette.tabUnselected
        tab.compactInlineLayoutAppearance.normal.iconColor = palette.tabUnselected
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: palette.tabUnselected]
        tab.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: palette.tabUnselected]
        tab.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: palette.tabUnselected]

        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = palette.tabBackground
        UITabBar.appearance().backgroundColor = palette.tabBackground
        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
        UITabBar.appearance().unselectedItemTintColor = palette.tabUnselected
        UITabBar.appearance().tintColor = palette.tabSelected
        refreshVisibleNavigationBars(with: nav, tint: navTextColor, background: navColor)
    }

    static func applyCurrentTheme() {
        applyTheme(kind: currentKind())
    }

    // 既存の UINavigationBar にも最新の外観を即時適用する
    private static func refreshVisibleNavigationBars(with appearance: UINavigationBarAppearance, tint: UIColor, background: UIColor) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                for nav in window.collectNavigationControllers() {
                    let bar = nav.navigationBar
                    bar.standardAppearance = appearance
                    bar.scrollEdgeAppearance = appearance
                    bar.compactAppearance = appearance
                    if #available(iOS 15.0, *) {
                        bar.compactScrollEdgeAppearance = appearance
                    }
                    bar.tintColor = tint
                    bar.isTranslucent = false
                    bar.barTintColor = background
                    bar.setNeedsLayout()
                    bar.layoutIfNeeded()
                }
            }
    }
}

private extension UIWindow {
    func collectNavigationControllers() -> [UINavigationController] {
        guard let root = rootViewController else { return [] }
        return collect(from: root)
    }

    func collect(from controller: UIViewController) -> [UINavigationController] {
        var result: [UINavigationController] = []
        if let nav = controller as? UINavigationController {
            result.append(nav)
        }
        for child in controller.children {
            result.append(contentsOf: collect(from: child))
        }
        if let presented = controller.presentedViewController {
            result.append(contentsOf: collect(from: presented))
        }
        return result
    }
}

// テーマ別のカラー定義
struct ThemePalette {
    let kind: AppThemeKind

    init(kind: AppThemeKind) {
        self.kind = kind
    }

    var navColor: Color {
        switch kind {
        case .future:
            return Theme.appBlue
        case .engineer:
            return Color(red: 0.22, green: 0.24, blue: 0.16)
        case .emperor:
            return Color(red: 0.40, green: 0.1, blue: 0.1)
        case .paradox:
            return Color(red: 0.24, green: 0.00, blue: 0.40)
        case .singularity:
            return Color.black
        case .abyss:
            return Color(red: 0.10, green: 0.10, blue: 0.10)
        }
    }

    var navButton: Color {
        switch kind {
        case .future:
            return .white
        case .engineer:
            return Color(red: 0.82, green: 1.0, blue: 0.72)   // 黄緑
        case .emperor:
            return .white
        case .paradox:
            return Color(red: 1.0, green: 0.96, blue: 0.76)   // 薄い黄
        case .singularity:
            return .white
        case .abyss:
            return .white
        }
    }
    
    var deNavButton: Color {
        switch kind {
        case .future:
            return Color.white.opacity(0.70)
        case .engineer:
            return Color(red: 0.62, green: 0.75, blue: 0.55)
        case .emperor:
            return Color.white.opacity(0.70)
        case .paradox:
            return Color(red: 0.7, green: 0.68, blue: 0.5)
        case .singularity:
            return Color.white.opacity(0.70)
        case .abyss:
            return Color.white.opacity(0.70)
        }
    }
    
    // SwiftUI Colors
    var bgTop: Color {
        switch kind {
        case .future:
            return Color(red: 44/255, green: 55/255, blue: 140/255)
        case .engineer:
            return Color(red: 0.18, green: 0.18, blue: 0.20)
        case .emperor:
            return Color(red: 0.32, green: 0.06, blue: 0.06)
        case .paradox:
            return Color(red: 0.26, green: 0.16, blue: 0.38)
        case .singularity:
            return Color(red: 0.98, green: 0.98, blue: 0.99)
        case .abyss:
            return Color(red: 0.06, green: 0.06, blue: 0.06)
        }
    }

    var bgBottom: Color {
        switch kind {
        case .future:
            return Color(red: 18/255, green: 23/255, blue: 84/255)
        case .engineer:
            return Color(red: 0.05, green: 0.05, blue: 0.07)
        case .emperor:
            return Color(red: 0.14, green: 0.02, blue: 0.02)
        case .paradox:
            return Color(red: 0.12, green: 0.04, blue: 0.24)
        case .singularity:
            return Color(red: 0.92, green: 0.92, blue: 0.94)
        case .abyss:
            return Color.black
        }
    }

    var primaryText: Color {
        switch kind {
        case .future:
            return .white
        case .engineer:
            return Color(red: 0.82, green: 1.0, blue: 0.72)   // 黄緑
        case .emperor:
            return Color(white: 0.92)                         // 薄い灰
        case .paradox:
            return Color(red: 1.0, green: 0.96, blue: 0.76)   // 薄い黄
        case .singularity:
            return .black
        case .abyss:
            return .white
        }
    }

    var secondaryText: Color {
        primaryText.opacity(0.75)
    }

    var keypadDigitText: Color {
        primaryText
    }

    var keyFillTop: Color {
        switch kind {
        case .future:
            return Color(red: 0.22, green: 0.35, blue: 0.78)
        case .engineer:
            return Color(red: 0.51, green: 0.53, blue: 0.55)
        case .emperor:
            return Color(red: 0.55, green: 0.20, blue: 0.20)
        case .paradox:
            return Color(red: 0.45, green: 0.30, blue: 0.65)
        case .singularity:
            return Color(red: 0.88, green: 0.88, blue: 0.90)
        case .abyss:
            return Color(red: 0.30, green: 0.30, blue: 0.32)
        }
    }

    var keyFillBottom: Color {
        switch kind {
        case .future:
            return Color(red: 0.14, green: 0.22, blue: 0.55)
        case .engineer:
            return Color(red: 0.24, green: 0.25, blue: 0.27)
        case .emperor:
            return Color(red: 0.36, green: 0.10, blue: 0.10)
        case .paradox:
            return Color(red: 0.28, green: 0.16, blue: 0.46)
        case .singularity:
            return Color(red: 0.78, green: 0.78, blue: 0.80)
        case .abyss:
            return Color(red: 0.16, green: 0.16, blue: 0.18)
        }
    }

    var searchBackground: Color {
        switch kind {
        case .future:
            return Color(red: 167/255, green: 216/255, blue: 255/255)
        case .engineer:
            return Color(red: 0.64, green: 0.80, blue: 0.52)
        case .emperor:
            return Color(red: 0.52, green: 0.32, blue: 0.32)
        case .paradox:
            return Color(red: 0.44, green: 0.32, blue: 0.60)
        case .singularity:
            return .black
        case .abyss:
            return Color(red: 0.22, green: 0.22, blue: 0.24)
        }
    }

    var inputFieldBackground: Color {
        switch kind {
        case .future:
            return .white
        case .engineer:
            return Color(red: 0.72, green: 0.90, blue: 0.58)
        case .emperor:
            return Color(red: 0.52, green: 0.32, blue: 0.32)
        case .paradox:
            return Color(red: 0.44, green: 0.32, blue: 0.60)
        case .singularity:
            return .black
        case .abyss:
            return Color(red: 0.22, green: 0.22, blue: 0.24)
        }
    }

    var inputFieldText: Color {
        switch kind {
        case .future:
            return .black
        case .engineer:
            return Color(red: 0.14, green: 0.18, blue: 0.11)
        case .paradox:
            return Color(red: 1.0, green: 0.98, blue: 0.89)
        case .emperor, .abyss:
            return .white
        case .singularity:
            return .white
        }
    }

    // UIKit Colors forナビ/タブ
    var navBackground: UIColor {
        switch kind {
        case .future:
            return UIColor(red: 27/255.0, green: 30/255.0, blue: 99/255.0, alpha: 1.0)
        case .engineer:
            return UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        case .emperor:
            return UIColor(red: 0.25, green: 0.03, blue: 0.03, alpha: 1.0)
        case .paradox:
            return UIColor(red: 0.20, green: 0.08, blue: 0.30, alpha: 1.0)
        case .singularity:
            return UIColor(white: 0.99, alpha: 1.0)
        case .abyss:
            return UIColor.black
        }
    }

    var navText: UIColor {
        switch kind {
        case .future:      return .white
        case .engineer:    return UIColor(red: 0.82, green: 1.0, blue: 0.72, alpha: 1.0)
        case .emperor:     return UIColor(white: 0.92, alpha: 1.0)
        case .paradox:     return UIColor(red: 1.0, green: 0.96, blue: 0.76, alpha: 1.0)
        case .singularity: return .black
        case .abyss:       return .white
        }
    }

    var tabBackground: UIColor {
        navBackground
    }

    var tabSelected: UIColor {
        navText
    }

    var tabUnselected: UIColor {
        navText.withAlphaComponent(0.8)
    }
}

// テーマ変更通知
extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChange")
}

// 既存 Theme API をテーマ対応させる
enum Theme {
    // Base brand blue (Future のベースとして利用)
    static var appBlue: Color {
        Color(red: 27/255, green: 30/255, blue: 99/255)
    }

    // 背景グラデーション
    static var bgTop: Color {
        ThemePalette(kind: ThemeManager.currentKind()).bgTop
    }

    static var bgBottom: Color {
        ThemePalette(kind: ThemeManager.currentKind()).bgBottom
    }

    static var appGradient: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var isSingularity: Bool {
        ThemeManager.currentKind() == .singularity
    }

    // テキスト
    static var primaryText: Color {
        ThemePalette(kind: ThemeManager.currentKind()).primaryText
    }

    static var secondaryText: Color {
        ThemePalette(kind: ThemeManager.currentKind()).secondaryText
    }

    // Segment
    static var segmentBackground: Color { Color.black.opacity(0.82) }
    static var segmentText: Color { primaryText }
    static var segmentPresentText: Color { Color(red: 0.90, green: 1.0, blue: 0.90) } // slight green tint
    static var segmentPlaceholder: Color { Color(white: 0.55) } // 濃い灰色プレースホルダ
    static var segmentBorderActive: Color { primaryText }
    static var segmentDash: Color { primaryText.opacity(0.6) }

    // Label plate（現状のまま）
    static var plateFill: Color { Color(red: 0.92, green: 0.78, blue: 0.40) }
    static var plateText: Color { Color(red: 0.20, green: 0.12, blue: 0.02) }

    // Keys
    static var keyFillTop: Color {
        ThemePalette(kind: ThemeManager.currentKind()).keyFillTop
    }
    static var keyFillBottom: Color {
        ThemePalette(kind: ThemeManager.currentKind()).keyFillBottom
    }
    static var keyStroke: Color { primaryText.opacity(0.7) }

    // Call button（従来通りの緑系を維持）
    static var callFillTop: Color { Color(red: 0.08, green: 0.70, blue: 0.32) }
    static var callFillBottom: Color { Color(red: 0.04, green: 0.55, blue: 0.24) }

    // Aux sheet background (slightly more cyan than screen background)
    static var auxSheetBackground: Color {
        Color(red: 0.10, green: 0.44, blue: 0.95, opacity: 0.85)
    }
    static var auxSheetBackgroundDark: Color {
        Color(red: 0.06, green: 0.30, blue: 0.75, opacity: 0.90)
    }

    // Aux sheet background for Preset (yellow-green tone)
    static var auxPresetBackground: Color {
        Color(red: 0.52, green: 0.85, blue: 0.22, opacity: 0.85)
    }
    static var auxPresetBackgroundDark: Color {
        Color(red: 0.36, green: 0.66, blue: 0.14, opacity: 0.90)
    }

    // Light blue for tab/search backgrounds（テーマごとの searchBackground を利用）
    static var lightBlue: Color {
        ThemePalette(kind: ThemeManager.currentKind()).searchBackground
    }

    // 検索バー/詳細入力用の背景色（テーマごとに設定可能）
    static var inputFieldBackground: Color {
        ThemePalette(kind: ThemeManager.currentKind()).inputFieldBackground
    }

    // 入力文字色（テーマごとに設定可能）
    static var inputFieldText: Color {
        ThemePalette(kind: ThemeManager.currentKind()).inputFieldText
    }
    // テキストフィールド用の背景色（現在は全テーマ共通で白）
    static var textFieldBackground: Color {
        .white
    }

    // テキストフィールド内の入力文字色（仕様に合わせて常に黒）
    static var textFieldInputColor: Color {
        .black
    }

    // 共通の丸ボタンスタイル
    static let circleButtonSize: CGFloat = 64
    static let circleButtonSpacing: CGFloat = 40
    static let circleButtonIconFont: Font = .system(size: 22, weight: .bold, design: .default)
    static let circleButtonLabelFont: Font = .system(size: 12, weight: .medium, design: .rounded)
}
