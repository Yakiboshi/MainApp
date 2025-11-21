import SwiftUI
import SwiftData
import UIKit

struct PlannedPlaceholderView: View {
    @State private var page: Int = 0
    @State private var sortMode: SortMode = .sentOldest
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    PlannedListPage(sortMode: sortMode, query: query)
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder(title: "予定", sortMode: $sortMode, query: $query) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            sortMode = SortMode.fromPreference()
        }
    }
}

private struct TopBarPlaceholder: View {
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
            SortPreference.savePlanned(next.toPreference())
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
        switch SortPreference.loadPlanned() {
        case .sentOldest: return .sentOldest
        case .sentNewest: return .sentNewest
        case .receivedOldest: return .receivedOldest
        }
    }

    func toPreference() -> SortPreference.Planned {
        switch self {
        case .sentOldest: return .sentOldest
        case .sentNewest: return .sentNewest
        case .receivedOldest: return .receivedOldest
        }
    }
}

struct PlannedListPage: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor<RecordingEntity>(\.recordedAt, order: .forward)])
    private var records: [RecordingEntity]
    fileprivate let sortMode: SortMode
    fileprivate let query: String
    @State private var deleteTarget: RecordingEntity? = nil
    @State private var showDeleteConfirm: Bool = false
    private var confirmDelete: Bool { SortPreference.loadConfirmDelete() }
    fileprivate init(sortMode: SortMode, query: String) { self.sortMode = sortMode; self.query = query }

    var body: some View {
        Group {
            if scheduledUpcoming().isEmpty {
                Color.clear.overlay(
                    VStack(spacing: 12) {
                        Text("予定はありません")
                            .font(.headline)
                            .foregroundStyle(Theme.secondaryText)
                        Text("キーパッドから新規作成してください")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                )
            } else {
                ZStack {
                    List {
                        ForEach(sortedPlanned(), id: \.id) { rec in
                            let row = PlannedRowView(entity: rec,
                                                     isSnoozed: isSnoozed(rec))
                            Group {
                                if isSnoozed(rec) {
                                    // スヌーズ中: 編集不可、行タップ無効（削除のみ）
                                    row
                                } else {
                                    Button {
                                        SoundManager.shared.play("list", ext: "mp3")
                                        NotificationRouter.shared.presentPlannedEditor(for: rec.id)
                                    } label: {
                                        row
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isWithinOneMinute(rec))
                                }
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    handleDelete(rec)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.bottom, listBottomPadding)
                }
                // 直接NavigationLink(destination:)を使用し、型ベース遷移に依存しない
            }
        }
        .alert("削除しますか", isPresented: $showDeleteConfirm, presenting: deleteTarget) { target in
            Button("はい", role: .destructive) { playAndDelete(target) }
            Button("いいえ", role: .cancel) { }
        } message: { _ in
            Text("この予定を削除してよろしいですか？")
        }
        // 予定の追加・削除・日時変更は SwiftData のクエリ経由で常に最新が反映される
    }

    private func scheduledUpcoming() -> [RecordingEntity] {
        let now = Date()
        return records.filter { ($0.status ?? "scheduled") == "scheduled" && $0.recordedAt > now && matchesQuery($0) }
    }

    private func sortedPlanned() -> [RecordingEntity] {
        let items = scheduledUpcoming()
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
        delete(rec)
    }

    private func delete(_ rec: RecordingEntity) {
        // 1) 通知キャンセル
        NotificationManager.shared.cancelAllNotifications(for: rec.id.uuidString)
        // 2) ファイル削除
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rec.fileName)
        try? FileManager.default.removeItem(at: url)
        // 3) DB削除
        withAnimation {
            context.delete(rec)
            try? context.save()
        }
        // 通知キューとバッジベースを更新
        _ = AppBadgeManager.refresh(using: context)
        LocalNotificationManager.shared.refreshAllNotifications(in: context)
    }

    private func isWithinOneMinute(_ rec: RecordingEntity) -> Bool {
        let threshold = rec.recordedAt.addingTimeInterval(-60)
        return Date() >= threshold
    }
}

private struct PlannedRowView: View {
    let entity: RecordingEntity
    var isSnoozed: Bool = false
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
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44 * scale, height: 44 * scale)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(displayTitle(entity))
                    .foregroundStyle(Theme.primaryText)
                    .font(.system(size: 20 * scale, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSnoozed {
                    Text("スヌーズ中")
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(Color.green.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(scheduledDateText(entity))
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if isSnoozed {
                    Text("スヌーズ")
                        .font(.system(size: 11 * scale))
                        .foregroundStyle(Color.green.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 8 * scale)
        .listRowBackground(Color.clear)
    }

    private func displayTitle(_ rec: RecordingEntity) -> String {
        if let t = rec.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t
        }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return "\(f.string(from: rec.recordedAt)) からの電話"
    }

    private func scheduledDateText(_ rec: RecordingEntity) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: rec.recordedAt)
    }
}

// MARK: - Main base date / hazard
private extension PlannedListPage {
    private func isSnoozed(_ rec: RecordingEntity) -> Bool {
        rec.isSnoozed
    }

    var listBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 160 : 120
    }
}
