import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRouteManager: ObservableObject {
    @Published var availableInputs: [AVAudioSessionPortDescription] = []
    @Published var selectedInput: AVAudioSessionPortDescription?
    @Published var isUsingSpeaker: Bool = false
    @Published var hasExternalOutput: Bool = false
    @Published var externalOutputName: String?

    // 現在の出力ルート状態を更新（内蔵/外部か、スピーカーかどうか）
    private func updateOutputState(from session: AVAudioSession) {
        let outputs = session.currentRoute.outputs
        if let external = outputs.first(where: { output in
            output.portType != .builtInSpeaker && output.portType != .builtInReceiver
        }) {
            hasExternalOutput = true
            externalOutputName = external.portName
            // 外部機器接続時は「スピーカー扱い」にしない（トグルは無効）
            isUsingSpeaker = false
        } else {
            hasExternalOutput = false
            externalOutputName = nil
            isUsingSpeaker = outputs.contains { $0.portType == .builtInSpeaker }
        }
    }

    func refreshAvailableInputs() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 同一カテゴリ/モードで再設定しておく（voiceChat + Bluetooth対応）
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            availableInputs = session.availableInputs ?? []
            // 現在の選択（preferredInput があればそれ、なければ currentRoute から）
            if let preferred = session.preferredInput {
                selectedInput = preferred
            } else if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                selectedInput = builtIn
            }
            updateOutputState(from: session)
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

    // 現在の出力ルートだけを最新化（録音開始後などに呼び出す）
    func refreshOutputState() {
        let session = AVAudioSession.sharedInstance()
        updateOutputState(from: session)
    }

    // 内蔵スピーカーへ切替（外部機器接続時はOS側で無視される）
    func routeToSpeaker() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.speaker)
            updateOutputState(from: session)
        } catch {
            // ignore
        }
    }

    // 受話口（レシーバー）側へ戻す
    func routeToEarpiece() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.none)
            updateOutputState(from: session)
        } catch {
            // ignore
        }
    }

    // 録音画面のトグル用：外部機器でなければスピーカー/受話口をトグル
    func toggleBuiltInOutput() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let hasExternal = outputs.contains { output in
            output.portType != .builtInSpeaker && output.portType != .builtInReceiver
        }
        // 外部機器接続時は切替を行わない（常に外部機器のまま）
        if hasExternal {
            updateOutputState(from: session)
            return
        }
        if isUsingSpeaker {
            routeToEarpiece()
        } else {
            routeToSpeaker()
        }
    }

    // 再生用: カテゴリを .playback に設定し、外部機器が無ければスピーカー出力をデフォルトにする
    static func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            // ignore
        }
    }

    // 録音以外の画面用: 既存セッションのまま、可能ならスピーカー出力に固定（外部機器があればそのまま）
    static func forceSpeakerIfPossible() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let hasExternal = outputs.contains { output in
            output.portType != .builtInSpeaker && output.portType != .builtInReceiver
        }
        guard !hasExternal else { return }
        do {
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            // ignore
        }
    }

    // 通信画面/通話画面に遷移したタイミングで、
    // 再生専用セッションを構成し、外部機器が無ければスピーカー出力をデフォルトにする
    static func configureForPreCall() {
        let session = AVAudioSession.sharedInstance()
        do {
            // 録音時以外はマイク入力を使わず、スピーカー再生を前提とする
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            // ignore
        }
    }

    // 外部機器接続時の入力優先順位を調整：入力が無い場合のみ内蔵マイクにフォールバック
    static func configureInputForRecording() {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let outputs = route.outputs

        let hasExternalOutput = outputs.contains { output in
            output.portType != .builtInSpeaker && output.portType != .builtInReceiver
        }
        // 内蔵スピーカー/受話口のみならデフォルトの builtInMic を使う
        guard hasExternalOutput else { return }

        // 外部入力を持つ機器（ヘッドセットマイク/BTハンズフリー/車載など）があればそれを優先
        let externalInputTypes: [AVAudioSession.Port] = [.headsetMic, .bluetoothHFP, .carAudio]
        let hasExternalInput = route.inputs.contains { input in
            externalInputTypes.contains(input.portType)
        }
        if hasExternalInput {
            return
        }

        // 出力のみの外部機器（例: Bluetoothスピーカー/イヤホン）の場合は内蔵マイクを使う
        if let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            do {
                try session.setPreferredInput(builtInMic)
            } catch {
                // ignore
            }
        }
    }

    // 録音終了時に、内蔵出力の場合だけラウドスピーカーに戻す
    static func restoreBuiltInSpeakerIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let hasExternal = outputs.contains { output in
            output.portType != .builtInSpeaker && output.portType != .builtInReceiver
        }
        // 外部機器接続時は何もしない（常に外部機器のまま）
        guard !hasExternal else { return }
        do {
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            // ignore
        }
    }
}
