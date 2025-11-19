## **目的**

アプリ内（SwiftUI）でユーザーが選んだ音声を
**ローカル通知音に使える WAV ファイルとして加工し、SwiftData に保存する機能**
を実装してください。

UI は **小ウィンドウ（シート）** を使い、以下の流れで操作できるようにします。

---

# ▼ **【UI仕様】（小ウィンドウ）**

```
音源選択（デフォルト音源 or ユーザー音源）
↓
ユーザー音源選択時のみ：
・7秒トリミング開始位置スライダー
・7秒プレビュー再生機能
↓
音量設定（5段階）
    小さい:  30%
    やや小:  60%
    普通:    100%
    やや大:  150%
    大きい:  200%
↓
右下「完了」ボタン
↓
ローディング画面に切り替え
↓
wav変換 → SwiftData保存 → 旧音源削除 → 小ウィンドウを閉じる
```

---

# ▼ **【実装ToDo】**

### **1. 小ウィンドウ UI の作成**

* `SoundSettingSheet.swift` という名前で SwiftUI のシートを作成
* `@State` で以下を管理：

```
useDefault: Bool
userURL: URL?
startTime: Double
volume: VolumeLevel
isLoading: Bool
```

---

### **2. 音源選択 UI**

* Picker（デフォルト音源 / ユーザー音源）
* デフォルト音源の場合 → トリミングUIは非表示
* ユーザー音源の場合 → FileImporter または PhotosPicker で音源URL取得

---

### **3. 7秒トリミング UI**

* ユーザー音声の場合のみ表示
* startTime をスライダーで選択できるようにする
* プレビュー再生ボタンを設置
  （必要なら簡易再生処理を実装）

---

### **4. 5段階音量 Picker**

VolumeLevel enum を使用：

```swift
enum VolumeLevel: Float {
    case small = 0.3
    case mediumSmall = 0.6
    case normal = 1.0
    case mediumLarge = 1.5
    case large = 2.0
}
```

---

### **5. 完了ボタン**

* 右下に「完了」ボタン設定
* 押すと **ローディングモードへ切り替え**（ProgressView）

---

### **6. wav変換処理（バックグラウンド）**

以下の処理をまとめて行う：

1. ユーザー音声の場合：

   * 7秒にトリミング
   * 最後1秒フェードアウト
   * 音量はVolumeLevelの値だけ増減
   * 最終的に WAV で出力
     出力先：
     `tmp/notification.wav`

2. デフォルト音源の場合：
   wav変換は行わず、SwiftDataに「isDefault = true」を保存

3. wav変換には以下の関数を使用（後述）：

```
exportTrimmedFadeOutWAV()
```

---

### **7. SwiftData に保存**

Entity名： `NotificationSoundEntity`

保存内容：

* soundURL（String?）
* isDefault（Bool）

ルール：

* ユーザー音源 → soundURL に wav のパス
* デフォルト音源 → isDefault = true

---

### **8. 古い音源ファイル削除**

前回の設定がユーザー音源で、`soundURL` が残っている場合
→ 該当ファイルを FileManager で削除。

---

### **9. 小ウィンドウを閉じる**

wav変換 → SwiftData保存 → 古い音源削除 が成功したら
`dismiss()` を呼び出し、小ウィンドウを閉じる。

---

# ▼ **【必要なコード雛形（貼って続きの実装を行ってください）】**

---

## **1. 音源編集シート UI**

```swift
struct SoundSettingSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context

    @State private var useDefault = true
    @State private var userURL: URL?
    @State private var startTime: Double = 0
    @State private var volume: VolumeLevel = .normal
    @State private var isLoading = false

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("変換中...")
                    .padding()
            } else {
                Form {
                    Picker("音源", selection: $useDefault) {
                        Text("デフォルト音源").tag(true)
                        Text("ユーザー音源").tag(false)
                    }

                    if !useDefault {
                        Button("音声ファイルを選択") {
                            // FileImporter
                        }

                        if let url = userURL {
                            Slider(value: $startTime, in: 0...20)
                            Button("7秒プレビュー") {
                                preview7sec(url: url, start: startTime)
                            }
                        }
                    }

                    Picker("音量", selection: $volume) {
                        Text("小さい 30%").tag(VolumeLevel.small)
                        Text("やや小さい 60%").tag(VolumeLevel.mediumSmall)
                        Text("普通 100%").tag(VolumeLevel.normal)
                        Text("やや大きめ 150%").tag(VolumeLevel.mediumLarge)
                        Text("大きめ 200%").tag(VolumeLevel.large)
                    }
                }
            }

            HStack {
                Spacer()
                Button("完了") {
                    applyChanges()
                }
                .padding()
            }
        }
    }
```

---

## **2. 完了ボタン動作（wav変換 + SwiftData保存 + 削除）**

```swift
func applyChanges() {
    isLoading = true

    Task {
        deleteOldSound()

        if useDefault {
            saveDefaultFlagToSwiftData()
            isLoading = false
            dismiss()
            return
        }

        guard let sourceURL = userURL else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notification.wav")

        exportTrimmedFadeOutWAV(
            inputURL: sourceURL,
            outputURL: outputURL,
            trimStart: startTime,
            volume: volume
        ) { error in
            Task {
                if error == nil {
                    saveURLToSwiftData(outputURL)
                    isLoading = false
                    dismiss()
                } else {
                    print("変換エラー:", error!)
                }
            }
        }
    }
}
```

---

## **3. SwiftData 保存処理**

```swift
func saveDefaultFlagToSwiftData() {
    let entity = NotificationSoundEntity()
    entity.isDefault = true
    context.insert(entity)
    try? context.save()
}

func saveURLToSwiftData(_ url: URL) {
    let entity = NotificationSoundEntity()
    entity.soundURL = url.absoluteString
    entity.isDefault = false
    context.insert(entity)
    try? context.save()
}

func deleteOldSound() {
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
```

---

## **4. WAV変換関数（コピペして使用）**

→ CODEX に「この関数も実装に含めて」と依頼してください。

（長いため割愛しますが、前メッセージに送った `exportTrimmedFadeOutWAV` を貼り付けてください）

---



1. **WAVはサイズが大きい**（7秒で約1.1MB）
   → SwiftDataには「URL文字列だけ」保存すること
   → 実ファイルは tmp に置くこと

2. **変換処理は重いため Task { } で実行必須**

3. **フェードアウト処理はサンプル数を直接触るため CPU 負荷あり**
   7秒なら問題なし

4. **以前のwavが tmp から消えている場合がある**
   → 削除処理は `try?` で安全に行う

5. **通知音として使える形式は wav（リニアPCM）に固定する**

