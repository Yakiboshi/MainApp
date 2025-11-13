import SwiftUI
import UIKit
import SwiftyCrop

// SwiftyCrop ラッパー（型を単純化して型推論負荷を軽減）
struct IconCropperSheet: View {
    let image: UIImage
    let onFinish: (UIImage?) -> Void

    var body: some View {
        // SwiftyCrop の正式な引数ラベルに合わせる
        SwiftyCropView(
            imageToCrop: image,
            maskShape: MaskShape.circle,
            onComplete: { cropped in
                onFinish(cropped)
            }
        )
    }
}

// Identifiable なクロップ対象
struct CroppingImage: Identifiable { let id = UUID(); let image: UIImage }
