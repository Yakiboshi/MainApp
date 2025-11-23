import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AudioEditorKit
import AVFoundation

struct SoundSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private enum Step {
        case source
        case trim
        case volume
    }

    private enum SourceSelection: Equatable {
        case `default`
        case imported(URL)
    }

    @State private var selectedOriginalURL: URL?
    @State private var workingURL: URL?
    @State private var editedURL: URL?
    @State private var trimStartForExport: Double = 0.0
    @State private var currentDuration: Double = 0.0
    @State private var selectedVolume: VolumeLevel = .normal
    @State private var isPickingFile: Bool = false
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var step: Step = .source
    @State private var showEditor: Bool = false

    // 4 分（240 秒）上限
    private let maxDurationSeconds: Double = 4 * 60

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Color.red)
                        .font(.footnote)
                }

                contentForStep()

                Spacer()

                bottomBar
            }
            .padding()
            .navigationTitle("着信音")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isProcessing)
        .fullScreenCover(isPresented: Binding(get: {
            showEditor
        }, set: { newVal in
            if !newVal { showEditor = false }
        })) {
            if let currentWorkingURL = workingURL {
                AudioTrimmingView(
                    audioURL: currentWorkingURL,
                    displayName: selectedOriginalURL?.lastPathComponent ?? currentWorkingURL.lastPathComponent
                ) { url in
                    if let url {
                        do {
                            let local = try copyToTemporary(url: url)
                            editedURL = local
                            workingURL = local
                            trimStartForExport = 0.0 // トリム済みファイルの先頭を使用
                            step = .volume
                            errorMessage = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    showEditor = false
                }
            } else {
                Button("閉じる") { showEditor = false }
            }
        }
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let picked = urls.first {
                    do {
                        try validateDuration(of: picked)
                        let local = try makeEditableLocalCopy(from: picked)
                        let duration = try loadDuration(of: local)
                        selectedOriginalURL = picked
                        workingURL = local
                        editedURL = nil
                        trimStartForExport = 0.0
                        currentDuration = duration
                        errorMessage = nil
                        if duration <= 7.0 {
                            // 7秒以下はトリミングをスキップして音量設定へ
                            step = .volume
                            showEditor = false
                        } else {
                            step = .trim
                            showEditor = true
                        }
                    } catch {
                        selectedOriginalURL = nil
                        workingURL = nil
                        editedURL = nil
                        errorMessage = error.localizedDescription
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func processAudio() {
        let sourceURL = editedURL ?? workingURL ?? selectedOriginalURL
        // デフォルトを選択した場合はカスタム音源をクリア
        if sourceURL == nil {
            isProcessing = true
            errorMessage = nil
            CustomRingtoneManager.removeCustomRingtone(in: context)
            isProcessing = false
            dismiss()
            return
        }
        guard let url = sourceURL else { return }
        isProcessing = true
        errorMessage = nil

        CustomRingtoneManager.importAndStoreCustomRingtone(
            from: url,
            trimStart: trimStartForExport,
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

    /// FileImporter が返すセキュリティスコープ付き URL を read/write 可能な一時領域にコピーする。
    private func makeEditableLocalCopy(from source: URL) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let ext = source.pathExtension.isEmpty ? nil : source.pathExtension
        var dst = tmpDir.appendingPathComponent("trim-\(UUID().uuidString)")
        if let ext { dst.appendPathExtension(ext) }

        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped { source.stopAccessingSecurityScopedResource() }
        }
        // 既存ファイルがあれば削除してからコピー
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.copyItem(at: source, to: dst)
        return dst
    }

    /// エディタなどから返された URL を、一時領域にコピーして保持する（セキュリティスコープ不要版）。
    private func copyToTemporary(url: URL) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let ext = url.pathExtension.isEmpty ? nil : url.pathExtension
        var dst = tmpDir.appendingPathComponent("trim-\(UUID().uuidString)")
        if let ext { dst.appendPathExtension(ext) }
        try? FileManager.default.removeItem(at: dst)
        try FileManager.default.copyItem(at: url, to: dst)
        return dst
    }

    /// アセットの長さを検証（4分以内）
    private func validateDuration(of url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else {
            throw NSError(domain: "SoundSettingSheet", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "音声の長さを取得できませんでした。別のファイルをお試しください。"
            ])
        }
        if duration > maxDurationSeconds {
            throw NSError(domain: "SoundSettingSheet", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "4分より長い音声は読み込み対象外です。4分以内のファイルを選択してください。"
            ])
        }
    }

    private func loadDuration(of url: URL) throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else {
            throw NSError(domain: "SoundSettingSheet", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "音声の長さを取得できませんでした。"
            ])
        }
        return duration
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text(titleForStep)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Spacer()
            Text(stepLabel)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private func contentForStep() -> some View {
        switch step {
        case .source:
            sourceSelector
        case .trim:
            trimView
        case .volume:
            volumeView
        }
    }

    private var sourceSelector: some View {
        VStack(spacing: 12) {
            Button {
                // デフォルト音源を使用
                selectedOriginalURL = nil
                workingURL = nil
                editedURL = nil
                trimStartForExport = 0.0
                errorMessage = nil
                step = .volume
            } label: {
                HStack {
                    Image(systemName: "music.note")
                    Text("デフォルト音源を使う")
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
            }
            Button {
                isPickingFile = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("音声ファイルを選択")
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
            }
            Text("MP3/M4A/WAV など 4 分以内のファイルを選択できます。")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private var trimView: some View {
        VStack(spacing: 16) {
            if let currentWorkingURL = workingURL {
                Text(selectedOriginalURL?.lastPathComponent ?? currentWorkingURL.lastPathComponent)
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("AudioEditorKitでトリミングを開く") {
                    showEditor = true
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.white)
                Text("編集を保存すると音量設定へ進みます。")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.7))
            } else {
                Text("音声が見つかりません。")
                    .foregroundStyle(Color.white)
            }
        }
    }

    private var volumeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("音量を選択")
                .font(.headline)
                .foregroundStyle(Color.white)
            Picker("音量", selection: $selectedVolume) {
                Text("小さい 30%").tag(VolumeLevel.small)
                Text("やや小さい 60%").tag(VolumeLevel.mediumSmall)
                Text("普通 100%").tag(VolumeLevel.normal)
                Text("やや大きめ 150%").tag(VolumeLevel.mediumLarge)
                Text("大きめ 200%").tag(VolumeLevel.large)
            }
            .pickerStyle(.inline)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack {
            Button("戻る") { goBack() }
                .disabled(!canGoBack)
            Spacer()
            switch step {
            case .source:
                Button("次へ") { step = workingURL == nil ? .volume : .trim }
                    .disabled(false)
            case .trim:
                Button("音量へ") { step = .volume }
                    .disabled(workingURL == nil)
            case .volume:
                Button(isProcessing ? "保存中..." : "書き出し") {
                    processAudio()
                }
                .disabled(isProcessing)
            @unknown default:
                EmptyView()
            }
        }
    }

    private var canGoBack: Bool {
        step != .source
    }

    private func goBack() {
        switch step {
        case .source:
            break
        case .trim:
            step = .source
        case .volume:
            step = workingURL == nil ? .source : .trim
        @unknown default:
            step = .source
        }
    }

    private var titleForStep: String {
        switch step {
        case .source: return "音源を選択"
        case .trim: return "トリミング (AudioEditorKit)"
        case .volume: return "音量設定"
        @unknown default: return ""
        }
    }

    private var stepLabel: String {
        switch step {
        case .source: return "1/3"
        case .trim: return "2/3"
        case .volume: return "3/3"
        @unknown default: return ""
        }
    }

    private var sourceDescription: String {
        if workingURL == nil && editedURL == nil && selectedOriginalURL == nil {
            return "デフォルト音源"
        }
        return selectedOriginalURL?.lastPathComponent ?? "カスタム音源"
    }

    private func volumeDescription(_ v: VolumeLevel) -> String {
        switch v {
        case .small: return "小さい (30%)"
        case .mediumSmall: return "やや小さい (60%)"
        case .normal: return "普通 (100%)"
        case .mediumLarge: return "やや大きめ (150%)"
        case .large: return "大きめ (200%)"
        }
    }
}
