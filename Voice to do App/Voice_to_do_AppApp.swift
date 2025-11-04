//
//  Voice_to_do_AppApp.swift
//  Voice to do App
//
//  Created by 焼星　指紋 on 2025/11/01.
//

import SwiftUI
import CoreText
import SwiftData

@main
struct Voice_to_do_AppApp: App {
    init() {
        // Register custom fonts (runtime) so Font.custom works without Info.plist UIAppFonts
        Fonts.register()
        // Style the whole app to exact app blue (#1B1E63)
        let color = UIColor(red: 27/255.0, green: 30/255.0, blue: 99/255.0, alpha: 1.0)
        // Window background for status bar/notch area
        UIWindow.appearance().backgroundColor = color
        // TabBarController 配下のコンテナ背景を青に固定（白帯の発生源を除去）
        if #available(iOS 13.0, *) {
            UIView.appearance(whenContainedInInstancesOf: [UITabBarController.self]).backgroundColor = color
        }
        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear

        // Navigation bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = color
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = .white

        // Tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = color
        appearance.shadowColor = .clear
        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.inlineLayoutAppearance.selected.iconColor = .white
        appearance.compactInlineLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.8)
        appearance.inlineLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.8)
        appearance.compactInlineLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.8)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.8)]
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.8)]
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.8)]
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().barTintColor = color
        UITabBar.appearance().backgroundColor = color
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        UITabBar.appearance().unselectedItemTintColor = UIColor.white.withAlphaComponent(0.85)
        UITabBar.appearance().tintColor = .white

        // Keep TabBar opaque blue via appearance; avoid setting container views to prevent content layering issues
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [QuickPresetEntity.self])
    }
}
