# 通信中画面 ToDo

完成イメージ: `docs/specs/tuusinchuuUI.png`

## MVP実装タスク
- [ ] 背景グラデーション（上:濃い黒/紺 → 下:やや明るいグレー、`ignoresSafeArea()`）
- [ ] ナビ/ステータスバーを非表示（フルスクリーンに近い見え方）
- [ ] レイアウト土台に `GeometryReader` を使い、配置基準をデバイス高で算出
- [ ] 見出し「通信中」を画面高の約1/3位置・中央・白・太字で表示
- [ ] ローディング表示：中央に `ProgressView`（白、`scaleEffect(1.6〜2.0)`）
- [ ] 下部中央に赤い丸ボタン（白い `xmark`、影付き、直径56–72pt）を固定配置
- [ ] ボタンタップで `@Environment(\.dismiss)` を呼び、前画面へ戻る
- [ ] セーフエリア対応（ホームインジケータ上に十分な余白 / `safeAreaInset` または `padding(.bottom, ...)`）
- [ ] アクセシビリティ：
  - [ ] 見出しに `accessibilityAddTraits(.isHeader)`
  - [ ] ローディングに `accessibilityLabel("読み込み中")`
  - [ ] ×ボタンに `accessibilityLabel("通信を終了")`
- [ ] プレビュー追加（複数デバイス、ダークモード確認）

## 動作/体験の詳細
- ×ボタンタップ時、即時に閉じる（アニメーションは標準のdismiss）
- 触覚フィードバックは任意（`UIImpactFeedbackGenerator(style: .medium)`）
- レイアウトは縦向き前提。横向きでは中央寄せで破綻しないこと

## Polish（任意）
- [ ] ローディングをモックに近いドット点滅アニメに差し替え可能なモディファイアを用意
- [ ] グラデの色味を3色（上: #0D0F1A / 中: #1C2030 / 下: #2A2E39 など）で微調整
- [ ] ボタン影を `shadow(radius: 8, y: 2)` 程度で強調、押下時軽く縮小

## Definition of Done
- [ ] 画像 `docs/specs/tuusinchuuUI.png` と視覚的に概ね一致
- [ ] iPhone 15/14/SE(第3世代) で主要要素の位置が意図通り（1/3・中央・1/6）
- [ ] VoiceOver で主要要素の読み上げが適切
- [ ] ×タップで確実に前画面へ戻れる
