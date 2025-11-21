import SwiftUI
import SwiftData
import UIKit

struct HistoryPlaceholderView: View {
    @State private var page: Int = 0
    @State private var sortMode: SortMode = .sentOldest
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    HistoryListPage(sortMode: sortMode, query: query)
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder_History(title: "履歴", sortMode: $sortMode, query: $query) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            sortMode = SortMode.fromPreference()
        }
    }
}

private struct TopBarPlaceholder_History: View {
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
            .background(Color.white.opacity(0.08))
        }
    }
    private func cycleSort() {
        let all = SortMode.allCases
        if let idx = all.firstIndex(of: sortMode) {
            let next = all[(idx+1) % all.count]
            sortMode = next
            SortPreference.saveHistory(next.toPreference())
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
        switch SortPreference.loadHistory() {
        case .sentOldest: return .sentOldest
        case .sentNewest: return .sentNewest
        case .receivedOldest: return .receivedOldest
        }
    }

    func toPreference() -> SortPreference.History {
        switch self {
        case .sentOldest: return .sentOldest
        case .sentNewest: return .sentNewest
        case .receivedOldest: return .receivedOldest
        }
    }
}

struct HistoryListPage: View {
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
            if historyItems().isEmpty {
                Color.clear.overlay(
                    Text("履歴はありません")
                        .font(.headline)
                        .foregroundStyle(Theme.secondaryText)
                )
            } else {
                ZStack {
                    List {
                        ForEach(historyItemsSorted(), id: \.id) { rec in
                            Button {
                                SoundManager.shared.play("list", ext: "mp3")
                                NotificationRouter.shared.presentHistoryDetail(for: rec.id)
                            } label: {
                                HistoryRowView(entity: rec)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: canDelete(rec)) {
                                if canDelete(rec) {
                                    Button(role: .destructive) {
                                        handleDelete(rec)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                } else if !rec.tasks.isEmpty {
                                    Button {} label: {
                                        Text("タスク未完了")
                                    }
                                    .tint(.gray)
                                } else {
                                    Button(role: .destructive) {
                                        handleDelete(rec)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.bottom, listBottomPadding)
                }
                // タップでルーター経由のフルスクリーン画面を提示
            }
        }
        .alert("削除しますか", isPresented: $showDeleteConfirm, presenting: deleteTarget) { target in
            Button("はい", role: .destructive) { playAndDelete(target) }
            Button("いいえ", role: .cancel) { }
        } message: { _ in
            Text("この履歴を削除してよろしいですか？")
        }
    }

    private func historyItems() -> [RecordingEntity] {
        records.filter { ($0.status ?? "scheduled") == "answered" && matchesQuery($0) }
    }

    private func historyItemsSorted() -> [RecordingEntity] {
        let items = historyItems()
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
        // ファイル削除
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(rec.fileName)
        try? FileManager.default.removeItem(at: url)
        // DB削除
        withAnimation {
            context.delete(rec)
            try? context.save()
        }
    }

    private func hasDeadline(_ rec: RecordingEntity) -> Bool {
        if let d = rec.deadlineDays, d > 0 { return true }
        if let h = rec.deadlineHours, h > 0 { return true }
        if let m = rec.deadlineMinutes, m > 0 { return true }
        return false
    }

    private func remainingTasks(_ rec: RecordingEntity) -> Int {
        rec.tasks.filter { !$0.isDone }.count
    }

    private func computeDeadline(for rec: RecordingEntity) -> Date? {
        let base = rec.deadlineBaseAt ?? rec.answeredAt ?? rec.recordedAt
        if let d = rec.deadlineDays, d > 0 {
            var comp = Calendar.current.dateComponents([.year, .month, .day], from: base)
            let startOfDay = Calendar.current.date(from: comp) ?? base
            guard let plus = Calendar.current.date(byAdding: .day, value: d, to: startOfDay) else { return nil }
            var c = Calendar.current.dateComponents([.year, .month, .day], from: plus)
            c.hour = 23; c.minute = 59; c.second = 0
            return Calendar.current.date(from: c)
        }
        if (rec.deadlineHours ?? 0) > 0 || (rec.deadlineMinutes ?? 0) > 0 {
            var sec = 0
            if let h = rec.deadlineHours { sec += max(0, h) * 3600 }
            if let m = rec.deadlineMinutes { sec += max(0, m) * 60 }
            return base.addingTimeInterval(TimeInterval(sec))
        }
        return nil
    }

    private func isDeadlineExpired(_ rec: RecordingEntity) -> Bool {
        guard let deadline = computeDeadline(for: rec) else { return false }
        return Date() >= deadline
    }

    private func canDelete(_ rec: RecordingEntity) -> Bool {
        // タスクなし → 削除可
        guard !rec.tasks.isEmpty else { return true }
        // タスクあり: 全タスク完了なら締切に関係なく削除可
        if remainingTasks(rec) == 0 { return true }
        // それ以外（タスク未完了）は削除不可
        return false
    }

    var listBottomPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 160 : 120
    }
}

private struct HistoryRowView: View {
    let entity: RecordingEntity
    var body: some View {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let scale: CGFloat = isPad ? 2.0 : 1.0
        let remaining = entity.tasks.filter { !$0.isDone }.count
        let hasTasks = !entity.tasks.isEmpty
        let deadline = computeDeadline()
        let expired = isDeadlineExpired(deadline: deadline)

        HStack(spacing: 12 * scale) {
            // 左: 丸型アイコン（保存画像）
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
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.7)))
            }

            // 中央: タイトル / 保存日時
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(title())
                    .foregroundStyle(Theme.primaryText)
                    .font(.system(size: 20 * scale, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(savedDateText())
                    .font(.system(size: 12 * scale))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 右: タスク/締切ステータス
            if hasTasks {
                VStack(alignment: .trailing, spacing: 4 * scale) {
                    if expired && remaining > 0 {
                        Text("タスク未完了")
                            .font(.system(size: 17 * scale, weight: .bold))
                            .foregroundStyle(.red)
                    } else if remaining == 0 {
                        Text("全タスク完了")
                            .font(.system(size: 17 * scale, weight: .bold))
                            .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.35))
                    } else {
                        HStack(spacing: 2 * scale) {
                            Text("残りタスク")
                                .font(.system(size: 12 * scale))
                                .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.35))
                            Text("\(remaining)個")
                                .font(.system(size: 16 * scale, weight: .bold))
                                .foregroundStyle(Color(red: 0.65, green: 0.95, blue: 0.35))
                        }
                    }

                    if let d = deadline {
                        if expired && remaining > 0 {
                            Text("期限超過")
                                .font(.system(size: 11 * scale))
                                .foregroundStyle(.red)
                        } else if remaining > 0 {
                            Text(deadlineLabel(for: d))
                                .font(.system(size: 11 * scale))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .frame(minWidth: 80 * scale)
            }
        }
        .padding(.vertical, 8 * scale)
        .listRowBackground(Color.clear)
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

    private func computeDeadline() -> Date? {
        let base = entity.deadlineBaseAt ?? entity.answeredAt ?? entity.recordedAt
        if let d = entity.deadlineDays, d > 0 {
            var comp = Calendar.current.dateComponents([.year, .month, .day], from: base)
            let startOfDay = Calendar.current.date(from: comp) ?? base
            guard let plus = Calendar.current.date(byAdding: .day, value: d, to: startOfDay) else { return nil }
            var c = Calendar.current.dateComponents([.year, .month, .day], from: plus)
            c.hour = 23; c.minute = 59; c.second = 0
            return Calendar.current.date(from: c)
        }
        if (entity.deadlineHours ?? 0) > 0 || (entity.deadlineMinutes ?? 0) > 0 {
            var sec = 0
            if let h = entity.deadlineHours { sec += max(0, h) * 3600 }
            if let m = entity.deadlineMinutes { sec += max(0, m) * 60 }
            return base.addingTimeInterval(TimeInterval(sec))
        }
        return nil
    }

    private func isDeadlineExpired(deadline: Date?) -> Bool {
        guard let d = deadline else { return false }
        return Date() >= d
    }

    private func deadlineLabel(for date: Date) -> String {
        let f = DateFormatter()
        if entity.deadlineDays != nil {
            f.dateFormat = "yyyy/MM/dd"
        } else {
            f.dateFormat = "yyyy/MM/dd HH:mm"
        }
        return f.string(from: date)
    }
}
