import SwiftUI
import AVKit
import UIKit

// Time circuits header: background (aspect-fit, pinned to top) + two rows of
// grouped digits (YEAR/MON/DAY/HOUR/MIN). Slot rects are defined in image
// coordinate ratios (0..1) to avoid drift across devices or orientations.
struct TimeCircuitsOverlayView: View {
    struct RowValues {
        var year: String
        var month: String
        var day: String
        var hour: String
        var minute: String
    }

    var present: RowValues
    var destination: RowValues
    // スロット座標（0..1 の割合）。編集可能な定義を既定に使用
    var slotRatios: [CGRect] = TimeCircuitsOverlayView.editableSlotRatios // 10 rects: 5 top + 5 bottom

    // 背景“8”の色（両行とも適用）
    var backgroundEightColor: Color = .black // 指定: 黒の8を後ろに
    // 一時デバッグ: 各スロットを赤枠で表示
    var showDebugFrames: Bool = false
    // 目的地の前景色（バリデーションで切替）
    var destinationForeground: Color = .white

    private let bgName = "timecircuits2" // Images版を使用
    private let counts: [Int] = [4, 2, 2, 2, 2] // YEAR, MON, DAY, HOUR, MIN

    var body: some View {
        if let ui = UIImage(named: bgName) {
            ZStack(alignment: .topLeading) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(ui.size, contentMode: .fit)
                    .accessibilityHidden(true)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: HeaderBottomPreferenceKey.self,
                                value: proxy.frame(in: .named("AppRoot")).maxY
                            )
                        }
                    )

                GeometryReader { geo in
                    let w = geo.size.width
                    let scale = w / ui.size.width

                    // 上段（PRESENT）
                    let topRects = Array(slotRatios.prefix(5)).map { r in
                        CGRect(x: r.minX * ui.size.width * scale,
                               y: r.minY * ui.size.height * scale,
                               width: r.width * ui.size.width * scale,
                               height: r.height * ui.size.height * scale)
                    }
                    // 下段（DESTINATION）
                    let bottomRects = Array(slotRatios.suffix(5)).map { r in
                        CGRect(x: r.minX * ui.size.width * scale,
                               y: r.minY * ui.size.height * scale,
                               width: r.width * ui.size.width * scale,
                               height: r.height * ui.size.height * scale)
                    }

                    RowGroupView(values: present, rects: topRects, counts: counts, isDestination: false, foreground: .white, backgroundEightColor: backgroundEightColor)
                    RowGroupView(values: destination, rects: bottomRects, counts: counts, isDestination: true, foreground: destinationForeground, backgroundEightColor: backgroundEightColor)

                    if showDebugFrames {
                        DebugRectsOverlay(rects: topRects + bottomRects)
                    }
                }
                .allowsHitTesting(false)
            }
            .aspectRatio(ui.size, contentMode: .fit)
        } else {
            Color.clear.frame(height: 180)
        }
    }
}

private struct RowGroupView: View {
    let values: TimeCircuitsOverlayView.RowValues
    let rects: [CGRect] // 5 rects
    let counts: [Int]   // 5 counts
    let isDestination: Bool
    let foreground: Color
    let backgroundEightColor: Color

    private var fields: [String] { [values.year, values.month, values.day, values.hour, values.minute] }

    var body: some View {
        ForEach(0..<min(rects.count, counts.count), id: \.self) { idx in
            let rect = rects[idx]
            let need = counts[idx]
            let text = fields[idx]
            GroupSlotView(
                rect: rect,
                text: String(text.prefix(need)),
                count: need,
                foreground: foreground,
                backgroundEight: backgroundEightColor
            )
            .accessibilityLabel("\(isDestination ? "目的地" : "現在") セグメント\(idx+1)")
        }
    }
}

// 描画グループ（YEAR=4など）全体のアスペクト比を維持してスロットにフィットさせる。
// 背面に黒の“8”を count 分並べ、前面に実際の文字列を重ねる。
private struct GroupSlotView: View {
    let rect: CGRect
    let text: String
    let count: Int
    let foreground: Color
    let backgroundEight: Color

    private let fontName = "BTTFTimeCircuitsUPDATEDAGAINIMSORRY"
    private let baseFontSize: CGFloat = 100

    var body: some View {
        let template = String(repeating: "8", count: max(1, count))
        let lineHeight = measureLineHeight()
        let scaleH = rect.height / max(1, lineHeight)
        let widthsTemplate = measureGlyphWidths(for: template)
        let sumTemplate = widthsTemplate.reduce(0, +)
        let gaps = max(1, count - 1)
        let neededUnscaledWidth = rect.width / scaleH
        let spacing = max(0, (neededUnscaledWidth - sumTemplate) / CGFloat(gaps))

        let t = String(text.prefix(count))
        let widthsText = measureGlyphWidths(for: t)
        ZStack(alignment: .topLeading) {
            GlyphRow(string: template,
                     widths: widthsTemplate,
                     spacing: spacing,
                     fontName: fontName,
                     baseFontSize: baseFontSize,
                     color: backgroundEight)
            GlyphRow(string: t,
                     widths: widthsText,
                     spacing: spacing,
                     fontName: fontName,
                     baseFontSize: baseFontSize,
                     color: foreground)
        }
        .scaleEffect(scaleH, anchor: .topLeading)
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .position(x: rect.midX, y: rect.midY)
    }

    private func measureLineHeight() -> CGFloat {
        if let f = UIFont(name: fontName, size: baseFontSize) { return f.lineHeight }
        return baseFontSize
    }

    private func measureGlyphWidths(for string: String) -> [CGFloat] {
        guard let uiFont = UIFont(name: fontName, size: baseFontSize) else {
            return Array(repeating: baseFontSize * 0.6, count: string.count)
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: uiFont]
        return string.map { ch in
            let s = String(ch) as NSString
            return s.size(withAttributes: attrs).width
        }
    }
}

// 1行を明示的にグリフ幅と可変スペースでレイアウトするビュー
private struct GlyphRow: View {
    let string: String
    let widths: [CGFloat]
    let spacing: CGFloat
    let fontName: String
    let baseFontSize: CGFloat
    let color: Color

    var body: some View {
        let lh = (UIFont(name: fontName, size: baseFontSize)?.lineHeight ?? baseFontSize)
        let totalWidth = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        let accum = makeOffsets(widths: widths, spacing: spacing)

        ZStack(alignment: .topLeading) {
            ForEach(Array(string.enumerated()), id: \.offset) { idx, ch in
                let w = widths.indices.contains(idx) ? widths[idx] : 0
                let x = accum.indices.contains(idx) ? accum[idx] : 0
                Text(String(ch))
                    .font(.custom(fontName, size: baseFontSize))
                    .foregroundStyle(color)
                    .frame(width: w, height: lh, alignment: .topLeading)
                    .position(x: x + w / 2, y: lh / 2)
            }
        }
        .frame(width: totalWidth, height: lh, alignment: .topLeading)
    }

    private func makeOffsets(widths: [CGFloat], spacing: CGFloat) -> [CGFloat] {
        var arr: [CGFloat] = []
        arr.reserveCapacity(widths.count)
        var x: CGFloat = 0
        for w in widths { arr.append(x); x += w + spacing }
        return arr
    }
}

// デバッグ用オーバレイ（スロット枠を赤線で可視化）
private struct DebugRectsOverlay: View {
    let rects: [CGRect]
    var body: some View {
        ForEach(Array(rects.enumerated()), id: \.offset) { _, r in
            Color.clear
                .frame(width: r.width, height: r.height)
                .overlay(Rectangle().stroke(Color.red, lineWidth: 1))
                .position(x: r.midX, y: r.midY)
        }
    }
}

extension TimeCircuitsOverlayView {
    // =============== 編集ポイント（座標の直接指定）=================
    // 画像内の正規化座標（x, y, w, h すべて 0.0〜1.0）で、各枠を個別に調整できます。
    // スロット順序（計10枠）: 上段 [YEAR, MON, DAY, HOUR, MIN] + 下段 [YEAR, MON, DAY, HOUR, MIN]
    // 例: x=0.065 は画像左端から 6.5% の位置、w=0.22 は画像幅の 22% を意味します。
    // “u” 表記のご要望は y と解釈しています（x=横, y=縦, w=幅, h=高さ）。
    static var editableSlotRatios: [CGRect] {
        // 上段（PRESENT）
        let topY: CGFloat = 0.144
        let h: CGFloat = 0.129
        let x0: CGFloat = 0.0453  // YEAR
        let x1: CGFloat = 0.340   // MON
        let x2: CGFloat = 0.509   // DAY
        let x3: CGFloat = 0.678   // HOUR
        let x4: CGFloat = 0.847   // MIN
        let wYear: CGFloat = 0.242
        let wTwo: CGFloat  = 0.121

        let top: [CGRect] = [
            CGRect(x: x0, y: topY, width: wYear, height: h), // YEAR (4桁)
            CGRect(x: x1, y: topY, width: wTwo,  height: h), // MON  (2桁)
            CGRect(x: x2, y: topY, width: wTwo,  height: h), // DAY  (2桁)
            CGRect(x: x3, y: topY, width: wTwo,  height: h), // HOUR (2桁)
            CGRect(x: x4, y: topY, width: wTwo,  height: h), // MIN  (2桁)
        ]

        // 下段（DESTINATION）: x を個別に調整可能
        let bottomY: CGFloat = 0.6308
        let bx0: CGFloat = 0.0441
        let bx1: CGFloat = 0.3396
        let bx2: CGFloat = 0.5083
        let bx3: CGFloat = 0.676
        let bx4: CGFloat = 0.8453
        let bottom: [CGRect] = [
            CGRect(x: bx0, y: bottomY, width: wYear, height: h),
            CGRect(x: bx1, y: bottomY, width: wTwo,  height: h),
            CGRect(x: bx2, y: bottomY, width: wTwo,  height: h),
            CGRect(x: bx3, y: bottomY, width: wTwo,  height: h),
            CGRect(x: bx4, y: bottomY, width: wTwo,  height: h),
        ]
        return top + bottom
    }

    // 暫定のグループ枠（5列上段 + 5列下段）。YEAR(4), MON(2), DAY(2), HOUR(2), MIN(2) を考慮し、
    // YEAR 幅を広めに確保。それ以外は同等。
    static var defaultGroupSlotRatios: [CGRect] {
        // 水平パラメータ（割合）
        let startX: CGFloat = 0.065
        let gapX: CGFloat = 0.035
        let perDigitW: CGFloat = 0.055

        let yearW = perDigitW * 4
        let twoW = perDigitW * 2

        // 垂直パラメータ（割合）
        let topY: CGFloat = 0.26
        let bottomY: CGFloat = 0.69
        let digitH: CGFloat = 0.105

        let widths: [CGFloat] = [yearW, twoW, twoW, twoW, twoW]
        var x = startX
        var top: [CGRect] = []
        for w in widths {
            top.append(CGRect(x: x, y: topY, width: w, height: digitH))
            x += w + gapX
        }
        x = startX
        var bottom: [CGRect] = []
        for w in widths {
            bottom.append(CGRect(x: x, y: bottomY, width: w, height: digitH))
            x += w + gapX
        }
        return top + bottom
    }
}

#if DEBUG
struct TimeCircuitsOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let present = TimeCircuitsOverlayView.RowValues(year: "2025", month: "11", day: "06", hour: "12", minute: "34")
        let destination = TimeCircuitsOverlayView.RowValues(year: "2", month: "", day: "30", hour: "1", minute: "")
        VStack(spacing: 0) {
            TimeCircuitsOverlayView(present: present, destination: destination)
                .background(Color.black)
            Spacer()
        }
        .background(Theme.appGradient)
    }
}
#endif

// Reports the bottom Y (in AppRoot coordinates) of the header image area
// so parents can size overlays between header and bottom UI.
struct HeaderBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
