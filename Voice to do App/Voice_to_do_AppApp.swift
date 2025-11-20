//
//  Voice_to_do_AppApp.swift
//  Voice to do App
//
//  Created by 焼星　指紋 on 2025/11/01.
//

import SwiftUI
import CoreText
import SwiftData
import UserNotifications

@main
struct Voice_to_do_AppApp: App {
    init() {
        // Register custom fonts (runtime) so Font.custom works without Info.plist UIAppFonts
        Fonts.register()
        // 初期テーマを適用
        ThemeManager.applyCurrentTheme()

        UITableView.appearance().backgroundColor = .clear
        UICollectionView.appearance().backgroundColor = .clear

        // 通知デリゲート設定とカテゴリ登録
        let center = UNUserNotificationCenter.current()
        center.delegate = AppNotificationCenterDelegate.shared
        let incomingCategory = UNNotificationCategory(
            identifier: "CALL_INCOMING",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([incomingCategory])
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            QuickPresetEntity.self,
            RecordingEntity.self,
            SoundFile.self,
            RelativeDatePresetEntity.self,
            UrlPresetEntity.self,
            TaskPresetEntity.self,
            TaskPresetItemEntity.self
        ])
    }
}
