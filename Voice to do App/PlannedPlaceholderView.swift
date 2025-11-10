import SwiftUI
import SwiftData

struct PlannedPlaceholderView: View {
    @State private var page: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    PlannedListPage()
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder(title: "予定") }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TopBarPlaceholder: View {
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

struct PlannedListPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<RecordingEntity>(\.recordedAt, order: .forward)])
    private var records: [RecordingEntity]
    init() {}

    var body: some View {
        Group {
            if scheduledUpcoming().isEmpty {
                Color.clear.overlay(
                    VStack(spacing: 12) {
                        Text("予定はありません")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        Text("キーパッドから新規作成してください")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                )
            } else {
                List {
                    ForEach(scheduledUpcoming(), id: \.id) { rec in
                        Button {
                            NotificationRouter.shared.presentPlannedEditor(for: rec.id)
                        } label: {
                            PlannedRowView(entity: rec)
                        }
                        .buttonStyle(.plain)
                        .disabled(isWithinOneMinute(rec))
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
                // 直接NavigationLink(destination:)を使用し、型ベース遷移に依存しない
            }
        }
    }

    private func scheduledUpcoming() -> [RecordingEntity] {
        let now = Date()
        return records.filter { $0.status == "scheduled" && $0.recordedAt > now }
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
    }

    private func isWithinOneMinute(_ rec: RecordingEntity) -> Bool {
        let threshold = rec.recordedAt.addingTimeInterval(-60)
        return Date() >= threshold
    }
}

private struct PlannedRowView: View {
    let entity: RecordingEntity
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle(entity))
                    .foregroundStyle(.white)
                Text(entity.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding(.vertical, 6)
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
}
