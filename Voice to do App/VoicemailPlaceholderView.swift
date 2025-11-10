import SwiftUI
import SwiftData

struct VoicemailPlaceholderView: View {
    @State private var page: Int = 0
    @State private var sortMode: SortMode = .sentOldest

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    VoicemailListPage(sortMode: sortMode)
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder_Voicemail(title: "留守電", sortMode: $sortMode) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TopBarPlaceholder_Voicemail: View {
    var title: String
    @Binding var sortMode: SortMode
    @State private var query: String = ""
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("検索（未実装）", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.lightBlue))
                Button(action: { cycleSort() }) { Text(labelForSort(sortMode)) }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.white.opacity(0.08))
        }
    }
    private func cycleSort() {
        let all = SortMode.allCases
        if let idx = all.firstIndex(of: sortMode) { sortMode = all[(idx+1) % all.count] }
    }
    private func labelForSort(_ mode: SortMode) -> String {
        switch mode {
        case .sentOldest: return "(発)古い順"
        case .sentNewest: return "(発)新規順"
        case .receivedOldest: return "(着)早い順"
        }
    }
}

private enum SortMode: CaseIterable { case sentOldest, sentNewest, receivedOldest }

struct VoicemailListPage: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [RecordingEntity]
    fileprivate let sortMode: SortMode
    fileprivate init(sortMode: SortMode) { self.sortMode = sortMode }

    var body: some View {
        Group {
            if voicemailItems().isEmpty {
                Color.clear.overlay(
                    Text("留守電はありません")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                )
            } else {
                List {
                    ForEach(voicemailItemsSorted(), id: \.id) { rec in
                        Button {
                            // 留守電起点で着信画面へ（拒否時スヌーズなし）
                            NotificationRouter.shared.openIncomingCall(messageId: rec.id.uuidString, fromVoicemail: true)
                        } label: {
                            VoicemailRowView(entity: rec)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                moveToHistory(rec)
                            } label: {
                                Label("履歴へ", systemImage: "archivebox")
                            }.tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear { VoicemailMigrator.migrateIfNeeded(context: context) }
    }

    private func voicemailItems() -> [RecordingEntity] {
        records.filter { ($0.status ?? "scheduled") == "missed" || $0.inVoicemailInbox }
    }

    private func voicemailItemsSorted() -> [RecordingEntity] {
        let items = voicemailItems()
        switch sortMode {
        case .sentOldest:
            return items.sorted { $0.recordedAt < $1.recordedAt }
        case .sentNewest:
            return items.sorted { $0.recordedAt > $1.recordedAt }
        case .receivedOldest:
            return items.sorted { ($0.answeredAt ?? .distantPast) < ($1.answeredAt ?? .distantPast) }
        }
    }

    private func moveToHistory(_ rec: RecordingEntity) {
        // ビュー更新中の状態変更によるクラッシュ/フリーズ回避のためメインキューで非同期実行
        DispatchQueue.main.async {
            rec.status = "answered"
            rec.answeredAt = Date()
            rec.inVoicemailInbox = false
            try? context.save()
        }
    }
}

private struct VoicemailRowView: View {
    let entity: RecordingEntity
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(title())
                    .foregroundStyle(.white)
                Text(entity.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func title() -> String {
        if let t = entity.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return "\(f.string(from: entity.recordedAt)) からの電話"
    }
}
