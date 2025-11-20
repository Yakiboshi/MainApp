import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SoundSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var selectedURL: URL?
    @State private var startTime: Double = 0.0
    @State private var selectedVolume: VolumeLevel = .normal
    @State private var isPickingFile: Bool = false
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("擬似着信音を設定")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Color.red)
                        .font(.footnote)
                }

                Group {
                    if let url = selectedURL {
                        AudioTrimmingView(audioURL: url, startTime: $startTime)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 220)
                            .overlay(
                                Text("音声ファイルを選択してください")
                                    .foregroundStyle(Color.white.opacity(0.7))
                            )
                    }
                }

                Button {
                    isPickingFile = true
                } label: {
                    Label("音声ファイルを選択", systemImage: "music.note.list")
                }
                .buttonStyle(.borderedProminent)

                Picker("音量", selection: $selectedVolume) {
                    Text("小さい 30%").tag(VolumeLevel.small)
                    Text("やや小さい 60%").tag(VolumeLevel.mediumSmall)
                    Text("普通 100%").tag(VolumeLevel.normal)
                    Text("やや大きめ 150%").tag(VolumeLevel.mediumLarge)
                    Text("大きめ 200%").tag(VolumeLevel.large)
                }

                Spacer()

                HStack {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .disabled(isProcessing)

                    Spacer()

                    Button(isProcessing ? "保存中..." : "完了") {
                        processAudio()
                    }
                    .disabled(isProcessing || selectedURL == nil)
                }
            }
            .padding()
            .navigationTitle("着信音")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isProcessing)
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedURL = urls.first
                startTime = 0
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func processAudio() {
        guard let url = selectedURL else { return }
        isProcessing = true
        errorMessage = nil

        CustomRingtoneManager.importAndStoreCustomRingtone(
            from: url,
            trimStart: startTime,
            volume: selectedVolume,
            context: context
        ) { error in
            DispatchQueue.main.async {
                if let error {
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                } else {
                    self.isProcessing = false
                    self.dismiss()
                }
            }
        }
    }
}
