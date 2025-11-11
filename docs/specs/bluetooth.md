ボタン（例：入力切替） をタップすると、利用可能な音声入力機器（受話口、スピーカー、Bluetoothなど）の一覧が表示される。

一覧は .confirmationDialog などで、ユーザーが選択できるUIで表示。

選択された入力機器に対して、AVAudioSession.setPreferredInput() を使用して入力を切り替える。

現在選択されている入力デバイス名も画面に表示する。

一覧の背景は黒、テキストは白。

ボタンの位置は画面下部から3分の1の中央揃えで、白のボタンに黒のスピーカーマイク、下に小さく「切り替え」と白テキスト

🛠 使用技術

AVFoundation

AVAudioSession

SwiftUI（iOS 15以降推奨）

実機で動作すること（マイクデバイス選択はシミュレータ不可）

✨ UIイメージ

「入力切替」ボタン：タップで下からデバイス選択肢

ダイアログ形式：iPhoneマイク / Bluetoothヘッドセット など

現在の選択状態が画面に表示される

以下サンプルコード

import SwiftUI
import AVFoundation

class AudioRouteManager: ObservableObject {
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInput: AVAudioSessionPortDescription?

    func fetchAvailableInputs() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try session.setActive(true)
            self.availableInputs = session.availableInputs ?? []
        } catch {
            print("AudioSession設定エラー: \(error)")
        }
    }

    func selectInput(_ input: AVAudioSessionPortDescription) {
        do {
            try AVAudioSession.sharedInstance().setPreferredInput(input)
            selectedInput = input
        } catch {
            print("入力の切り替えに失敗: \(error)")
        }
    }
}

struct AudioInputSelectorView: View {
    @StateObject private var audioRouteManager = AudioRouteManager()
    @State private var showingInputMenu = false

    var body: some View {
        VStack {
            Button(action: {
                audioRouteManager.fetchAvailableInputs()
                showingInputMenu = true
            }) {
                Label("入力切替", systemImage: "waveform.circle")
                    .font(.title2)
                    .padding()
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            if let selected = audioRouteManager.selectedInput {
                Text("現在の入力: \(selected.portName)")
                    .foregroundColor(.white)
                    .padding(.top)
            }
        }
        .confirmationDialog("入力デバイスを選択", isPresented: $showingInputMenu) {
            ForEach(audioRouteManager.availableInputs, id: \.uid) { input in
                Button(input.portName) {
                    audioRouteManager.selectInput(input)
                }
            }
        }
        .onAppear {
            audioRouteManager.fetchAvailableInputs()
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}
