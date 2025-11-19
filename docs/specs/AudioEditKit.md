了解です！
以下に **あなたが CODEX にそのまま送れる「実装依頼文」** を作成しました。

これは CODEX が混乱しないように
**目的 → 手順 → 実装ポイント → 必要な挿入コード**
の順で整理してあります。

あなた仕様の

* SwiftUI で使うための UIViewRepresentable ラッパー作成
* AudioEditorKit のカスタマイズ（7秒固定トリミング）
* フェードアウトは外部処理関数で実施
* 音量調整も外部処理
* 完了ボタン押下で値を渡して WAV 変換

のすべてが解決できる依頼文です。

---

# ✅ **CODEX に送る実装依頼文（完全版・コピペOK）**

---

## 📌 **目的**

SwiftUI アプリ内で AudioEditorKit（UIKit）を利用し、
波形画面で **7秒固定のトリミング開始位置を選ばせる UI** を実装してください。

トリミング後の実際の加工処理（フェードアウト＋音量調整＋wav 出力）は
既存の外部関数 `exportTrimmedFadeOutWAV()` に任せます。

そのため、この依頼では **トリミング UI と値の受け渡し部分だけ実装してください。**

---

## 📌 **依頼内容（実装ToDo）**

### **1. AudioEditorKit を SwiftUI で使うための UIViewRepresentable ラッパーを作成**

ファイル名：
`AudioTrimmingView.swift`

役割：

* SwiftUI から呼べるように UIViewControllerRepresentable を使ってラップする
* 内部で `AEWaveformViewController` を生成し、音声URLをセットする
* AudioEditorKit 側の `onTrimRangeChanged(start, end)` を使い、
  **開始位置（start）のみを SwiftUI に反映**
* 終了位置（end）は常に start + 7.0 秒 に固定する

---

### **2. 7秒固定のトリミング仕様にカスタマイズ**

AudioEditorKit のデフォルトでは
「開始位置」「終了位置」のハンドルを自由に動かせます。

しかし今回は：

* ユーザーは **開始位置だけ** 動かす
* 終了位置は強制的に `start + 7.0` にする

このため、`onTrimRangeChanged` をフックして
AudioEditorKit に「終了位置を start+7 に上書きする」ようにしてください。

---

### **3. フェードアウトと音量調整は外部処理**

今回の依頼では AudioEditorKit 内に加工ロジックは入れません。

トリミング画面の役割は：

* 開始位置（startTime）だけをユーザーに選ばせる
* 完了ボタンで `startTime` を親ビューへ返す

加工は外部の関数に任せます：

```swift
exportTrimmedFadeOutWAV(
    inputURL: selectedAudioURL,
    outputURL: destinationURL,
    trimStart: startTime,
    volume: selectedVolume
)
```

---

### **4. 完了ボタンで startTime を親に返す**

小ウィンドウ（SoundSettingSheet）側の完了ボタンで：

1. AudioTrimmingView から受け取った `startTime`
2. ユーザーが選んだ音量（5段階）
3. 選ばれた音源URL

これらをまとめて WAV 変換関数へ渡します。

---

## 📌 **実装してほしいコードの構造**

以下のコードをもとに、必要な部分を完成させてください。

---

## ▶ **AudioTrimmingView.swift（ラッパー）**

```swift
import SwiftUI
import AudioEditorKit

struct AudioTrimmingView: UIViewControllerRepresentable {

    let audioURL: URL
    @Binding var startTime: Double     // SwiftUI → 親へ渡す値
    let trimDuration: Double = 7.0     // 固定値

    func makeUIViewController(context: Context) -> AEWaveformViewController {
        let vc = AEWaveformViewController()
        vc.audioURL = audioURL

        // AudioEditorKitの範囲変更コールバック
        vc.onTrimRangeChanged = { start, end in
            // 終了位置を 7秒固定に修正する
            let fixedEnd = start + trimDuration
            vc.setTrimRange(start: start, end: fixedEnd)

            // SwiftUI側へ開始位置だけ返す
            DispatchQueue.main.async {
                self.startTime = start
            }
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: AEWaveformViewController, context: Context) {
        uiViewController.audioURL = audioURL
    }
}
```

---

## ▶ **SoundSettingSheet.swift（小ウィンドウ側）**

```swift
struct SoundSettingSheet: View {
    @Environment(\.dismiss) var dismiss

    @State private var startTime: Double = 0.0
    @State private var selectedVolume: VolumeLevel = .normal
    @State private var selectedURL: URL?
    @State private var isLoading = false

    var body: some View {
        VStack {

            if let url = selectedURL {
                AudioTrimmingView(audioURL: url, startTime: $startTime)
                    .frame(height: 200)
            }

            Picker("音量", selection: $selectedVolume) {
                Text("小さい 30%").tag(VolumeLevel.small)
                Text("やや小さい 60%").tag(VolumeLevel.mediumSmall)
                Text("普通 100%").tag(VolumeLevel.normal)
                Text("やや大きめ 150%").tag(VolumeLevel.mediumLarge)
                Text("大きめ 200%").tag(VolumeLevel.large)
            }

            Button("完了") {
                isLoading = true
                processAudio()
            }
            .padding()
        }
    }

    func processAudio() {
        guard let url = selectedURL else { return }

        let outputURL = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds/notification.wav")

        exportTrimmedFadeOutWAV(
            inputURL: url,
            outputURL: outputURL,
            trimStart: startTime,
            volume: selectedVolume
        ) { error in
            if error == nil {
                DispatchQueue.main.async {
                    isLoading = false
                    dismiss()
                }
            }
        }
    }
}
```

---

# 📌 **要望（CODEX側が誤解しないように強めに書いています）**

```
※AudioEditorKit 側の内部処理や波形描画を変更しないでください  
※トリミング UI は開始位置だけ動かすようにしてください  
※終了位置 = 開始位置 + 7秒 で常に固定してください  
※フェードアウトと音量処理は外部関数で行うため編集 UI 側で処理しないでください  
※完了ボタンでは startTime と selectedVolume を必ず親へ返してください  
```

---

# 🎉 **これで CODEX が完全に目的を理解し、正しく実装できます！**

必要であれば：

* 同じトリミングUIを **SwiftUIだけで完全自作する版**
* 7秒固定トリマーの専用 UI デザイン案
* AIコーディングに渡す「音源変換 + SwiftData 保存」依頼文の統合版

も作成できます。

続けますか？
