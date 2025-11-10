import SwiftUI
import SwiftData

struct HistoryPlaceholderView: View {
    @State private var page: Int = 0
    @State private var sortMode: SortMode = .sentOldest

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    HistoryListPage(sortMode: sortMode)
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder_History(title: "履歴", sortMode: $sortMode) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TopBarPlaceholder_History: View {
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

struct HistoryListPage: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [RecordingEntity]
    fileprivate let sortMode: SortMode
    fileprivate init(sortMode: SortMode) { self.sortMode = sortMode }

    var body: some View {
        Group {
            if historyItems().isEmpty {
                Color.clear.overlay(
                    Text("履歴はありません")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                )
            } else {
                List {
                    ForEach(historyItemsSorted(), id: \.id) { rec in
                        Button {
                            NotificationRouter.shared.presentHistoryDetail(for: rec.id)
                        } label: {
                            HistoryRowView(entity: rec)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                delete(rec)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // タップでルーター経由のフルスクリーン画面を提示
            }
        }
    }

    private func historyItems() -> [RecordingEntity] {
        records.filter { ($0.status ?? "scheduled") == "answered" }
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
}

private struct HistoryRowView: View {
    let entity: RecordingEntity
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(title())
                    .foregroundStyle(.white)
                if let at = entity.answeredAt {
                    Text(at.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
    }

    private func title() -> String {
        if let t = entity.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return "\(f.string(from: entity.recordedAt)) からの電話"
    }
}
