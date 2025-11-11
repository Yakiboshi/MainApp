import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRouteManager: ObservableObject {
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInput: AVAudioSessionPortDescription?

    func refreshAvailableInputs() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 同一カテゴリ/モードで再設定しておく（voiceChat + Bluetooth対応）
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
            availableInputs = session.availableInputs ?? []
            // 現在の選択（preferredInput があればそれ、なければ currentRoute から）
            if let preferred = session.preferredInput {
                selectedInput = preferred
            } else if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                selectedInput = builtIn
            }
        } catch {
            // 失敗時は空のまま
        }
    }

    func select(_ input: AVAudioSessionPortDescription) {
        do {
            try AVAudioSession.sharedInstance().setPreferredInput(input)
            selectedInput = input
        } catch {
            // 失敗時は状態を変えない
        }
    }
}
