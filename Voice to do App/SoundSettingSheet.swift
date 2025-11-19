import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

struct SoundSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var useDefault: Bool = true
    @State private var userURL: URL?
    @State private var startTime: Double = 0
    @State private var maxStartTime: Double = 0
    @State private var volume: VolumeLevel = .normal
    @State private var isLoading: Bool = false
    @State private var isPickingFile: Bool = false
    @State private var errorMessage: String?

    @StateObject private var previewPlayer = AudioPlayerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // タイトル
            Text("着信音を変更")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.top, 16)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.top, 8)
            }

            if isLoading {
                Spacer()
                ProgressView("変換中...")
                    .padding()
                Spacer()
            } else {
                Form {
                    Section(header: Text("音源")) {
                        Picker("音源", selection: $useDefault) {
                            Text("デフォルト音源").tag(true)
                            Text("ユーザー音源").tag(false)
                        }
                        .pickerStyle(.segmented)

                        if !useDefault {
                            Button("音声ファイルを選択") {
                                isPickingFile = true
                            }

                            if let url = userURL {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Button {
                                            playOriginalPreview(url: url)
                                        } label: {
                                            Image(systemName: previewPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        }
                                        Slider(value: $startTime, in: 0...maxStartTime)
                                    }
                                    Text("開始位置: \(String(format: "%.1f", startTime)) 秒（最大 \(String(format: "%.1f", maxStartTime)) 秒）")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button("トリミング部分を7秒プレビュー") {
                                        previewTrimmedSegment()
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }

                    Section(header: Text("音量")) {
                        Picker("音量", selection: $volume) {
                            Text("小さい 30%").tag(VolumeLevel.small)
                            Text("やや小さい 60%").tag(VolumeLevel.mediumSmall)
                            Text("普通 100%").tag(VolumeLevel.normal)
                            Text("やや大きめ 150%").tag(VolumeLevel.mediumLarge)
                            Text("大きめ 200%").tag(VolumeLevel.large)
                        }
                    }
                }
            }

            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .disabled(isLoading)
                .padding()

                Spacer()

                Button("完了") {
                    applyChanges()
                }
                .disabled(isLoading || (!useDefault && userURL == nil))
                .padding()
            }
        }
        .interactiveDismissDisabled(isLoading)
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                userURL = url
                configureDuration(for: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .onAppear {
            // 過去の音量プリセットから初期値を復元（なければ普通）
            let preset = SortPreference.loadNotificationVolumePreset()
            volume = VolumeLevel(from: preset)
        }
    }

    private func configureDuration(for url: URL) {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        let maxStart = max(0.0, duration - 7.0)
        maxStartTime = maxStart
        if startTime > maxStart {
            startTime = maxStart
        }
    }

    private func playOriginalPreview(url: URL) {
        if previewPlayer.isPlaying {
            previewPlayer.stop()
        } else {
            previewPlayer.playURL(url, loops: 0, volume: volume.rawValue) {
                // no-op
            }
        }
    }

    private func previewTrimmedSegment() {
        guard let src = effectiveSourceURL() else { return }
        guard let out = NotificationSoundProvider.customSoundFileURL()?
            .deletingLastPathComponent()
            .appendingPathComponent("notification_preview.wav") else {
            return
        }
        isLoading = true
        errorMessage = nil
        NotificationSoundExporter.exportTrimmedFadeOutWAV(
            inputURL: src,
            outputURL: out,
            trimStart: useDefault ? 0 : startTime,
            volume: volume
        ) { error in
            if let error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            } else {
                self.previewPlayer.playURL(out, loops: 0, volume: 1.0) {
                    // no-op
                }
                self.isLoading = false
            }
        }
    }

    private func effectiveSourceURL() -> URL? {
        if useDefault {
            return Bundle.main.url(forResource: "ks035", withExtension: "wav")
        } else {
            return userURL
        }
    }

    private func applyChanges() {
        guard let outputURL = NotificationSoundProvider.customSoundFileURL() else {
            errorMessage = "保存先パスの取得に失敗しました"
            return
        }

        isLoading = true
        errorMessage = nil

        deleteOldSound()

        guard let sourceURL = effectiveSourceURL() else {
            errorMessage = "音源ファイルが見つかりませんでした"
            isLoading = false
            return
        }

        SortPreference.saveNotificationVolumePreset(volume.toPreset)

        NotificationSoundExporter.exportTrimmedFadeOutWAV(
            inputURL: sourceURL,
            outputURL: outputURL,
            trimStart: useDefault ? 0 : startTime,
            volume: volume
        ) { error in
            if let error {
                self.errorMessage = "変換に失敗しました: \(error.localizedDescription)"
                self.isLoading = false
            } else {
                if useDefault {
                    saveDefaultFlagToSwiftData(outputURL)
                } else {
                    saveURLToSwiftData(outputURL, originalURL: sourceURL)
                }

                Task { @MainActor in
                    LocalNotificationManager.shared.refreshAllNotifications(in: context)
                }

                self.isLoading = false
                self.dismiss()
            }
        }
    }

    private func saveDefaultFlagToSwiftData(_ url: URL) {
        let entity = NotificationSoundEntity()
        entity.isDefault = true
        entity.soundURL = url.absoluteString
        entity.displayName = "デフォルト"
        entity.updatedAt = Date()
        context.insert(entity)
        try? context.save()
    }

    private func saveURLToSwiftData(_ url: URL, originalURL: URL) {
        let entity = NotificationSoundEntity()
        entity.soundURL = url.absoluteString
        entity.isDefault = false
        entity.displayName = originalURL.lastPathComponent
        entity.updatedAt = Date()
        context.insert(entity)
        try? context.save()
    }

    private func deleteOldSound() {
        let fetch = FetchDescriptor<NotificationSoundEntity>()
        if let old = try? context.fetch(fetch).first {
            if let path = old.soundURL,
               let url = URL(string: path),
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            context.delete(old)
            try? context.save()
        }
    }
}

