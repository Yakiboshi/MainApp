//
//  ContentView.swift
//  Voice to do App
//
//  Created by 焼星　指紋 on 2025/11/01.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var notifRouter = NotificationRouter.shared
    var body: some View {
        AppTabsView()
            .task {
                // アプリ起動時に通知/マイク権限を確認（初回は要求）
                PermissionManager.requestLaunchPermissions()
            }
            .fullScreenCover(isPresented: Binding(get: {
                notifRouter.incomingMessageId != nil
            }, set: { newVal in
                if !newVal { notifRouter.dismissIncomingCall() }
            })) {
                IncomingCallView(messageId: notifRouter.incomingMessageId)
                    .ignoresSafeArea()
            }
            // 通話後画面をルートから提示（この表示完了後に着信画面を裏で閉じる）
            .fullScreenCover(isPresented: Binding(get: {
                notifRouter.showAfterCallForMessageId != nil
            }, set: { newVal in
                if !newVal { notifRouter.showAfterCallForMessageId = nil }
            })) {
                AfterCallView()
                    .ignoresSafeArea()
            }
    }
}

#Preview {
    ContentView()
}
