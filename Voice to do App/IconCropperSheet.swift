import SwiftUI
import UIKit

struct IconCropperSheet: View {
    let image: UIImage
    let onFinish: (UIImage?) -> Void

    @State private var containerSize: CGSize = .zero
    @State private var circleCenter: CGPoint?
    @State private var circleRadius: CGFloat = 0
    @State private var dragStartCenter: CGPoint?
    @State private var didInitializeLayout = false

    init(image: UIImage, onFinish: @escaping (UIImage?) -> Void) {
        // 端末向きなどを考慮して一度正位置に正規化してから扱う
        self.image = IconCropperSheet.normalized(image)
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Text("アイコンをトリミング")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                Spacer()

                GeometryReader { geo in
                    ZStack {
                        let size = geo.size

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)

                        let center = currentCenter(in: size)
                        let fullRect = CGRect(origin: .zero, size: size)
                        let circleRect = CGRect(
                            x: center.x - circleRadius,
                            y: center.y - circleRadius,
                            width: circleRadius * 2,
                            height: circleRadius * 2
                        )

                        // 円マスクの外側を薄いグレーで暗くする
                        Path { path in
                            path.addRect(fullRect)
                            path.addEllipse(in: circleRect)
                        }
                        .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: circleRadius * 2, height: circleRadius * 2)
                            .position(currentCenter(in: size))
                            .contentShape(Circle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if dragStartCenter == nil {
                                            dragStartCenter = currentCenter(in: size)
                                        }
                                        guard let start = dragStartCenter else { return }
                                        let proposed = CGPoint(
                                            x: start.x + value.translation.width,
                                            y: start.y + value.translation.height
                                        )
                                        circleCenter = clampCenter(proposed, in: size)
                                    }
                                    .onEnded { _ in
                                        dragStartCenter = nil
                                    }
                            )
                    }
                    .onAppear {
                        if didInitializeLayout == false {
                            didInitializeLayout = true
                            containerSize = geo.size
                            let rect = imageRect(in: geo.size)
                            let radius = min(rect.width, rect.height) * 0.35
                            circleRadius = radius
                            circleCenter = CGPoint(x: rect.midX, y: rect.midY)
                        }
                    }
                    .onChange(of: geo.size) { _, newSize in
                        containerSize = newSize
                    }
                }

                Spacer()

                HStack {
                    Button("キャンセル") {
                        onFinish(nil)
                    }
                    .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Button("この範囲を使う") {
                        onFinish(cropImage())
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 70) // 下部に少し余白をとってボタンを上げる
            }
        }
    }

    private func currentCenter(in container: CGSize) -> CGPoint {
        if let center = circleCenter {
            return center
        }
        return CGPoint(x: container.width / 2, y: container.height / 2)
    }

    private func imageRect(in container: CGSize) -> CGRect {
        let imageSize = image.size
        guard imageSize.width > 0,
              imageSize.height > 0,
              container.width > 0,
              container.height > 0
        else {
            return CGRect(origin: .zero, size: container)
        }

        let scale = min(container.width / imageSize.width,
                        container.height / imageSize.height)
        let displaySize = CGSize(width: imageSize.width * scale,
                                 height: imageSize.height * scale)
        let origin = CGPoint(
            x: (container.width - displaySize.width) / 2,
            y: (container.height - displaySize.height) / 2
        )
        return CGRect(origin: origin, size: displaySize)
    }

    private func clampCenter(_ point: CGPoint, in container: CGSize) -> CGPoint {
        let rect = imageRect(in: container)
        let minX = rect.minX + circleRadius
        let maxX = rect.maxX - circleRadius
        let minY = rect.minY + circleRadius
        let maxY = rect.maxY - circleRadius

        let x = min(max(point.x, minX), maxX)
        let y = min(max(point.y, minY), maxY)
        return CGPoint(x: x, y: y)
    }

    private func cropImage() -> UIImage? {
        guard containerSize.width > 0,
              containerSize.height > 0,
              let cg = image.cgImage
        else { return nil }

        let imageSize = image.size
        let rectInContainer = imageRect(in: containerSize)
        let displayScale = min(containerSize.width / imageSize.width,
                               containerSize.height / imageSize.height)

        let center = circleCenter ?? CGPoint(x: rectInContainer.midX, y: rectInContainer.midY)

        let centerInImagePoints = CGPoint(
            x: (center.x - rectInContainer.origin.x) / displayScale,
            y: (center.y - rectInContainer.origin.y) / displayScale
        )
        let radiusInImagePoints = circleRadius / displayScale

        var cropRectPoints = CGRect(
            x: centerInImagePoints.x - radiusInImagePoints,
            y: centerInImagePoints.y - radiusInImagePoints,
            width: radiusInImagePoints * 2,
            height: radiusInImagePoints * 2
        )

        let scaleFactor = image.scale
        cropRectPoints.origin.x *= scaleFactor
        cropRectPoints.origin.y *= scaleFactor
        cropRectPoints.size.width *= scaleFactor
        cropRectPoints.size.height *= scaleFactor

        let imageBounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let finalRect = cropRectPoints.integral.intersection(imageBounds)

        guard let cropped = cg.cropping(to: finalRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: image.size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// Identifiable なクロップ対象
struct CroppingImage: Identifiable { let id = UUID(); let image: UIImage }
