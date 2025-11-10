//
//  ContentView.swift
//  Voice to do App
//
//  Created by 焼星　指紋 on 2025/11/01.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var notifRouter = NotificationRouter.shared
    @Environment(\.modelContext) private var modelContext
    var body: some View {
        AppTabsView()
            .task {
                // アプリ起動時に通知/マイク権限を確認（初回は要求）
                PermissionManager.requestLaunchPermissions()
                // 既存データのサニタイズ（初回のみ）
                DataSanitizer.runIfNeeded(context: modelContext)
                // 起動時に留守電移行の監査を実行（既存のモデルコンテキストを使用）
                VoicemailMigrator.migrateIfNeeded(context: modelContext)
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
            // 履歴詳細をルート提示（タブ外の新規画面）
            .fullScreenCover(isPresented: Binding(get: {
                notifRouter.showHistoryDetailForRecordingId != nil
            }, set: { newVal in
                if !newVal { notifRouter.dismissHistoryDetail() }
            })) {
                if let rid = notifRouter.showHistoryDetailForRecordingId {
                    HistoryDetailContainerView(recordingId: rid)
                        .ignoresSafeArea()
                }
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
            // 予定編集をルート提示（タブ外の新規画面）
            .fullScreenCover(isPresented: Binding(get: {
                notifRouter.showPlannedEditorForRecordingId != nil
            }, set: { newVal in
                if !newVal { notifRouter.dismissPlannedEditor() }
            })) {
                if let rid = notifRouter.showPlannedEditorForRecordingId {
                    PlannedDetailContainerView(recordingId: rid)
                        .ignoresSafeArea()
                }
            }
            .transaction { $0.disablesAnimations = true }
    }
}

#Preview {
    ContentView()
}
