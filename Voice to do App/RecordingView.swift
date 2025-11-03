import SwiftUI

struct RecordingView: View {
    let scheduledDate: Date

    var body: some View {
        VStack(spacing: 16) {
            Text("録音（仮）")
                .font(.title).bold()
            Text("予定時刻: \(scheduledDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote)
            Text("ここで接続音→録音実装予定")
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Recording")
    }
}

