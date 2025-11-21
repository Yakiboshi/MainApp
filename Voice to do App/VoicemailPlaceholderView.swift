import SwiftUI
import SwiftData
import UIKit

struct VoicemailPlaceholderView: View {
    @State private var page: Int = 0
    @State private var sortMode: SortMode = .sentOldest
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
                ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    VoicemailListPage(sortMode: sortMode, query: query)
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder_Voicemail(title: "留守電", sortMode: $sortMode, query: $query) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            sortMode = SortMode.fromPreference()
        }
    }
}

private struct TopBarPlaceholder_Voicemail: View {
    var title: String
    @Binding var sortMode: SortMode
    @Binding var query: String
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("検索", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundColor(Theme.inputFieldText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.inputFieldBackground))
                Button(action: { cycleSort() }) { Text(labelForSort(sortMode)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.primaryText)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.black.opacity(0.12))
        }
    }
    private func cycleSort() {
        let all = SortMode.allCases
        if let idx = all.firstIndex(of: sortMode) {
            let next = all[(idx+1) % all.count]
            sortMode = next
            SortPreference.saveVoicemail(next.toPreference())
        }
    }
    private func labelForSort(_ mode: SortMode) -> String {
        switch mode {
        case .sentOldest: return "(発)古い順"
        case .sentNewest: return "(発)新規順"
        case .receivedOldest: return "(着)早い順"
        }
    }
}

private enum SortMode: CaseIterable {
    case sentOldest, sentNewest, receivedOldest

    static func fromPreference() -> SortMode {
        switch SortPreference.loadVoicemail() {
        case .sentOldest: return .sentOldest
        case .sentNewest: return .sentNewest
        case .receivedOldest: return .receivedOldest
        }
    }

    func toPreference() -> SortPreference.Voicemail {
        switch self {
        case .sentOldest: return .sentOldest
        case .sentNewest: return .sentNewest
        case .receivedOldest: return .receivedOldest
        }
    }
}

struct VoicemailListPage: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [RecordingEntity]
    fileprivate let sortMode: SortMode
    fileprivate let query: String
    @State private var deleteTarget: RecordingEntity? = nil
    @State private var showDeleteConfirm: Bool = false
    private var confirmDelete: Bool { SortPreference.loadConfirmDelete() }
    fileprivate init(sortMode: SortMode, query: String) { self.sortMode = sortMode; self.query = query }

    var body: some View {
        Group {
            if voicemailItems().isEmpty {
                Color.clear.overlay(
                    Text("留守電はありません")
                        .font(.headline)
                        .foregroundStyle(Theme.secondaryText)
                )
            } else {
                ZStack {
                    List {
                        ForEach(voicemailItemsSorted(), id: \.id) { rec in
                            Button {
                                // 留守電起点で着信画面へ（拒否時スヌーズなし）
                                SoundManager.shared.play("list", ext: "mp3")
                                NotificationRouter.shared.openIncomingCall(messageId: rec.id.uuidString, fromVoicemail: true)
                            } label: {
                                VoicemailRowView(entity: rec)
                                    .contentShape(Rectangle())
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
                    .background(Color.clear)
                    .padding(.bottom, listBottomPadding)
                }
            }
        }
        .alert("削除しますか", isPresented: $showDeleteConfirm, presenting: deleteTarget) { target in
            Button("はい", role: .destructive) { playAndDelete(target) }
            Button("いいえ", role: .cancel) { }
        } message: { _ in
            Text("この留守電を削除してよろしいですか？")
        }
        .onAppear { VoicemailMigrator.migrateIfNeeded(context: context) }
    }

    private func voicemailItems() -> [RecordingEntity] {
        records.filter { (($0.status ?? "scheduled") == "missed" || $0.inVoicemailInbox) && matchesQuery($0) }
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

    private func matchesQuery(_ rec: RecordingEntity) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        guard let t = rec.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return false }
        return t.localizedCaseInsensitiveContains(q) || t.localizedStandardContains(q)
    }

    private func moveToHistory(_ rec: RecordingEntity) {
        // ビュー更新中の状態変更によるクラッシュ/フリーズ回避のためメインキューで非同期実行
        DispatchQueue.main.async {
            rec.status = "answered"
            rec.answeredAt = Date()
            rec.inVoicemailInbox = false
            rec.isSnoozed = false
            try? context.save()
            // 留守電数・履歴バッジベースを更新
            _ = AppBadgeManager.refresh(using: context)
        }
    }

    private func handleDelete(_ rec: RecordingEntity) {
        if confirmDelete {
            deleteTarget = rec
            showDeleteConfirm = true
        } else {
            playAndDelete(rec)
        }
    }

    private func playAndDelete(_ rec: RecordingEntity) {
        SoundManager.shared.play("trush", ext: "mp3")
        // ファイル削除
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rec.fileName)
        try? FileManager.default.removeItem(at: url)
        // DB削除
        withAnimation {
            context.delete(rec)
            try? context.save()
        }
        _ = AppBadgeManager.refresh(using: context)
    }

    var listBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 160 : 120
    }
}

private struct VoicemailRowView: View {
    let entity: RecordingEntity
    var body: some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let scale: CGFloat = isPad ? 2.0 : 1.0
        HStack(spacing: 12 * scale) {
            if let data = entity.iconImageData ?? DefaultIconStore.load(),
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44 * scale, height: 44 * scale)
                    .clipShape(Circle())
                    .shadow(radius: 2 * scale)
            } else {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 44 * scale, height: 44 * scale)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.7)))
            }
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(title())
                    .foregroundStyle(Theme.primaryText)
                    .font(.system(size: 20 * scale, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(savedDateText())
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 8 * scale)
    }

    private func title() -> String {
        if let t = entity.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return "\(f.string(from: entity.recordedAt)) からの電話"
    }

    private func savedDateText() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
        if let d = entity.savedAt { return f.string(from: d) }
        return f.string(from: entity.recordedAt)
    }
}
