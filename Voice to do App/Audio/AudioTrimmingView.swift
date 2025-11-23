import AudioEditorKit
import SwiftUI
import UIKit

/// AudioEditorKit を使ったトリミング起動ビュー。ボタンでエディタを開き、編集結果の URL を呼び出し元へ返す。
struct AudioTrimmingView: View {
    let audioURL: URL
    let displayName: String
    let onEdited: (URL?) -> Void
    @State private var showEditor: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(displayName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                Button("AudioEditorKitで編集") {
                    showEditor = true
                }
                .buttonStyle(.borderedProminent)
            }
            Text("編集完了後のファイルを着信音として使用します。（7秒以内推奨）")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
        .fullScreenCover(isPresented: $showEditor) {
            AudioEditorKitWrapper(audioURL: audioURL) { outputURL in
                onEdited(outputURL)
                showEditor = false
            }
        }
    }
}

private struct AudioEditorKitWrapper: UIViewControllerRepresentable {
    let audioURL: URL
    let onComplete: (URL?) -> Void

    func makeUIViewController(context: Context) -> EditorHostViewController {
        EditorHostViewController(audioURL: audioURL, onComplete: onComplete)
    }

    func updateUIViewController(_ uiViewController: EditorHostViewController, context: Context) {
        uiViewController.audioURL = audioURL
    }
}

private final class EditorHostViewController: UIViewController {
    var audioURL: URL
    private let onComplete: (URL?) -> Void
    private var hasPresented = false

    init(audioURL: URL, onComplete: @escaping (URL?) -> Void) {
        self.audioURL = audioURL
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresented else { return }
        hasPresented = true

        let representable = AudioFileRepresentable(
            url: audioURL,
            aliasTitle: audioURL.lastPathComponent,
            descriptionText: ""
        )

        AudioEditorKit.presentEditor(audio: representable, parent: self) { [weak self] edited, url in
            guard let self else { return }
            let result = edited ? url : nil
            onComplete(result)
            dismiss(animated: true)
        }
    }
}
