import SwiftUI
import SwiftData

struct VoicemailPlaceholderView: View {
    @State private var page: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appGradient.ignoresSafeArea()
                TabView(selection: $page) {
                    VoicemailListPage()
                        .tag(0)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .safeAreaInset(edge: .top) { TopBarPlaceholder_Voicemail(title: "留守電") }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TopBarPlaceholder_Voicemail: View {
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

struct VoicemailListPage: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [RecordingEntity]
    init() {}

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
                    ForEach(voicemailItems(), id: \.id) { rec in
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
        records.filter { $0.status == "missed" || $0.inVoicemailInbox }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    private func moveToHistory(_ rec: RecordingEntity) {
        rec.status = "answered"
        rec.answeredAt = Date()
        rec.inVoicemailInbox = false
        try? context.save()
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
