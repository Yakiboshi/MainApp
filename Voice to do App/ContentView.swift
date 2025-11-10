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
            // 通話フローのすべて（着信/通話/通話後）を単一カバーで制御（無アニメ）
            .fullScreenCover(isPresented: Binding(get: {
                notifRouter.hasAnyCallOverlay
            }, set: { newVal in
                if !newVal {
                    notifRouter.dismissAfterCall(); notifRouter.dismissCall(); notifRouter.dismissIncomingCall()
                }
            })) {
                CallOverlayContainer()
            }
            .transaction { $0.disablesAnimations = true }
            // 詳細設定（中間画面）をルート提示
            .fullScreenCover(isPresented: Binding(get: {
                notifRouter.showIntermediateForRecordingId != nil
            }, set: { newVal in
                if !newVal { notifRouter.dismissIntermediate() }
            })) {
                if let rid = notifRouter.showIntermediateForRecordingId {
                    IntermediateView(recordingId: rid)
                        .ignoresSafeArea()
                }
            }
            .transaction { $0.disablesAnimations = true }
    }
}

#Preview {
    ContentView()
}
