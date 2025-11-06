#ヘッダー画像、時刻表示の制作の手順

背景画像を用意して、iphoneの幅いっぱいにアスペクト比を固定して表示し、背景画像の中にある枠の中(黒い部分)に数字テキストをぴったり収めて、ユーザーの入力に応じて数字が変更されるようにしたいです。（異機種、横画面表示の際に画像内の数字が全くずれないようにするため）

背景画像 @timecircuits2.png
数字　フォントBTTFTimeCircuitsUPDATEDAGAINIMSORRYを使用。

現時点で考えている実装手順。

1.背景画像のサイズを算出し、数字をはめ込む枠（スロット）(全10枠)を、画像内座標の割合で保持
slot1 = (xRatio, yRatio, wRatio, hRatio) （0.0〜1.0）
（完成後こちらでより正確に座標設定するためコード上の設定できる場所を指定する。）

画面に表示する際は、背景画像を Aspect Fit（横幅いっぱい & アスペクト比維持）で配置。
実際に画面上に描かれる背景の矩形 fittedRect を求め、
scale = fittedRect.width / bgWidth、offset = fittedRect.origin を使って
slotRectOnScreen = CGRect( offset.x + xRatio * bgWidth * scale, ... ) を算出。

算出した slotRectOnScreen に数字をはめ込む。




以下参考コード

import SwiftUI
import AVKit // AVMakeRect用

struct NumberOverlayView: View {
    let bgImage = UIImage(named: "background")! // 元画像
    // 画像内のスロット枠（割合）。例：x=20%, y=35%, w=40%, h=12%
    let slotRatio = CGRect(x: 0.20, y: 0.35, width: 0.40, height: 0.12)

    // 表示する数字（画像でもTextでもOK）
    let digits: [String] // 例: ["1","2","3","4"]

    var body: some View {
        GeometryReader { geo in
            let container = CGRect(origin: .zero, size: geo.size)
            // 背景をAspectFitさせた実表示矩形
            let fitted = AVMakeRect(aspectRatio: bgImage.size, insideRect: container)
            let scale = fitted.width / bgImage.size.width

            ZStack {
                // 背景
                Image(uiImage: bgImage)
                    .resizable()
                    .aspectRatio(bgImage.size, contentMode: .fit)
                    .frame(width: geo.size.width)
                    .position(x: fitted.midX, y: fitted.midY)

                // スロットの実表示矩形
                let slot = CGRect(
                    x: fitted.minX + slotRatio.minX * bgImage.size.width * scale,
                    y: fitted.minY + slotRatio.minY * bgImage.size.height * scale,
                    width: slotRatio.width * bgImage.size.width * scale,
                    height: slotRatio.height * bgImage.size.height * scale
                )

                // 数字の描画（例：Textで等幅フォント）
                HStack(spacing: 0) {
                    ForEach(digits, id: \.self) { d in
                        Text(d)
                            .font(.system(size: slot.height * 0.9, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
                .frame(width: slot.width, height: slot.height, alignment: .center)
                .position(x: slot.midX, y: slot.midY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .ignoresSafeArea() // 必要に応じて
    }
}