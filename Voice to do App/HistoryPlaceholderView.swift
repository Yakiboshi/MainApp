import SwiftUI
import SwiftData

struct HistoryPlaceholderView: View {
    @State private var page: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    HistoryListPage()
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder_History(title: "履歴") }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TopBarPlaceholder_History: View {
    var title: String
    @State private var query: String = ""
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("検索（未実装）", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button(action: {}) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color.white.opacity(0.08))
        }
    }
}

struct HistoryListPage: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [RecordingEntity]
    init() {}

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
                    ForEach(historyItems(), id: \.id) { rec in
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
        records.filter { $0.status == "answered" }
            .sorted { (a, b) in
                let la = a.answeredAt ?? .distantPast
                let lb = b.answeredAt ?? .distantPast
                return la > lb
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
