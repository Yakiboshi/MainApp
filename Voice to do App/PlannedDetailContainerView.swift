import SwiftUI
import SwiftData

struct PlannedDetailContainerView: View {
    @Environment(\.modelContext) private var context
    let recordingId: UUID

    var body: some View {
        Group {
            if let rec = fetch() {
                PlannedDetailView(entity: rec)
            } else {
                ZStack {
                    Theme.appGradient.ignoresSafeArea()
                    Text("対象の予定が見つかりません")
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func fetch() -> RecordingEntity? {
        do {
            let fd = FetchDescriptor<RecordingEntity>(predicate: #Predicate { $0.id == recordingId })
            return try context.fetch(fd).first
        } catch {
            return nil
        }
    }
}

