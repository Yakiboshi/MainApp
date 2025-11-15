import SwiftUI
import SwiftData

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
    }
}

private struct TopBarPlaceholder: View {
    var title: String
    @Binding var sortMode: SortMode
    @Binding var query: String
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

struct PlannedListPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<RecordingEntity>(\.recordedAt, order: .forward)])
    private var records: [RecordingEntity]
    @State private var mainBaseDate: Date? = nil
    fileprivate let sortMode: SortMode
    fileprivate let query: String
    fileprivate init(sortMode: SortMode, query: String) { self.sortMode = sortMode; self.query = query }

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
                ZStack {
                    List {
                        ForEach(sortedPlanned(), id: \.id) { rec in
                            Button {
                                NotificationRouter.shared.presentPlannedEditor(for: rec.id)
                            } label: {
                                PlannedRowView(entity: rec, isHazard: isHazard(rec))
                            }
                            .buttonStyle(.plain)
                            .disabled(isWithinOneMinute(rec))
                            .listRowBackground(Color.clear)
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
                    .background(Color.clear)
                }
                // 直接NavigationLink(destination:)を使用し、型ベース遷移に依存しない
            }
        }
        .onAppear { updateMainBaseDate() }
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
        // キューを更新
        LocalNotificationManager.shared.handleNotificationFinished(for: rec.id.uuidString, in: context)
    }

    private func isWithinOneMinute(_ rec: RecordingEntity) -> Bool {
        let threshold = rec.recordedAt.addingTimeInterval(-60)
        return Date() >= threshold
    }
}

private struct PlannedRowView: View {
    let entity: RecordingEntity
    var isHazard: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            if let data = entity.iconImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            } else {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 44, height: 44)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.7)))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle(entity))
                    .foregroundStyle(.white)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(scheduledDateText(entity))
                    .font(.caption)
                    .foregroundStyle(isHazard ? Color.yellow : Color.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if isHazard {
                    Text("前の着信に埋もれて発信されない可能性があります。")
                        .font(.caption2)
                        .foregroundStyle(Color.gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 8)
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
    private func updateMainBaseDate() {
        LocalNotificationManager.shared.fetchPendingSummary { summary in
            guard let firstId = summary.mainMessageIds.first,
                  let uuid = UUID(uuidString: firstId) else {
                self.mainBaseDate = nil
                return
            }
            do {
                let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == uuid })
                if let rec = try context.fetch(fd).first {
                    self.mainBaseDate = rec.recordedAt
                } else {
                    self.mainBaseDate = nil
                }
            } catch {
                self.mainBaseDate = nil
            }
        }
    }

    private func isHazard(_ rec: RecordingEntity) -> Bool {
        guard let base = mainBaseDate else { return false }
        let delta = rec.recordedAt.timeIntervalSince(base)
        let windows: [TimeInterval] = [60, 120, 180]
        // 1,2,3分差を ±1秒の誤差内で判定
        return windows.contains(where: { abs(delta - $0) <= 1 })
    }
}
