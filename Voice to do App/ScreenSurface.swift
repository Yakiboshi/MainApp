import SwiftUI

// A reusable "screen/glass" effect wrapper to make any content look like
// it's being seen through a display surface. Includes scanlines, subtle noise,
// vignette and glare. Tuned for performance and reuse.
struct ScreenSurface<Content: View>: View {
    var cornerRadius: CGFloat = 10
    var scanlineOpacity: Double = 0.08
    var noiseOpacity: Double = 0.035
    var vignetteOpacity: Double = 0.35
    var glareOpacity: Double = 0.12
    @ViewBuilder var content: Content

    init(cornerRadius: CGFloat = 10,
         scanlineOpacity: Double = 0.08,
         noiseOpacity: Double = 0.035,
         vignetteOpacity: Double = 0.35,
         glareOpacity: Double = 0.12,
         @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.scanlineOpacity = scanlineOpacity
        self.noiseOpacity = noiseOpacity
        self.vignetteOpacity = vignetteOpacity
        self.glareOpacity = glareOpacity
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .compositingGroup()
                .overlay(Scanlines().opacity(scanlineOpacity).blendMode(.overlay))
                .overlay(NoisyOverlay().opacity(noiseOpacity).blendMode(.softLight))
                .overlay(VignetteOverlay(opacity: vignetteOpacity))
                .overlay(GlareOverlay().opacity(glareOpacity))
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
    }
}

private struct Scanlines: View {
    var body: some View {
        GeometryReader { geo in
            let pitch: CGFloat = max(2, geo.size.height / 180 * 2) // scale with height
            Canvas { ctx, size in
                ctx.opacity = 0.9
                let lineRect = CGRect(x: 0, y: 0, width: size.width, height: 1)
                let path = Path(CGRect(x: lineRect.minX, y: lineRect.minY, width: lineRect.width, height: lineRect.height))
                for y in stride(from: 0, to: size.height, by: pitch) {
                    var t = ctx
                    t.translateBy(x: 0, y: y)
                    t.fill(path, with: .color(.black))
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct NoisyOverlay: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { _ in
            GeometryReader { geo in
                Canvas { ctx, size in
                    let density = max(80, Int((size.width * size.height) / 9000))
                    for _ in 0..<density {
                        let x = CGFloat.random(in: 0..<size.width)
                        let y = CGFloat.random(in: 0..<size.height)
                        let alpha = Double.random(in: 0.02...0.08)
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        ctx.fill(Path(rect), with: .color(.white.opacity(alpha)))
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

private struct VignetteOverlay: View {
    var opacity: Double = 0.35
    var body: some View {
        GeometryReader { geo in
            let maxR = max(geo.size.width, geo.size.height)
            RadialGradient(colors: [.clear, .black.opacity(opacity)], center: .center, startRadius: maxR * 0.3, endRadius: maxR)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
    }
}

private struct GlareOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            LinearGradient(colors: [Color.white.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: w * 0.65, height: h * 0.45)
                .rotationEffect(.degrees(-18))
                .offset(x: -w * 0.05, y: -h * 0.10)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
    }
}

