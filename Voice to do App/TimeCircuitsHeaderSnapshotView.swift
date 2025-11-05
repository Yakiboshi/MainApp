import SwiftUI
import Combine

// Rasterizes TimeCircuitsHeaderView into an Image at the current size.
// This makes the whole header behave like a single bitmap: any scaling
// or compression applied to this view will uniformly affect both the
// background image and the overlay texts without internal misalignment.
struct TimeCircuitsHeaderSnapshotView: View {
    // PRESENT positions
    let yearTop: CGFloat
    let yearLeft: CGFloat
    let monLeft: CGFloat
    let dayLeft: CGFloat
    let hourLeft: CGFloat
    let minLeft: CGFloat

    // DESTINATION positions / values
    let destYearTop: CGFloat
    let destYear: String
    let destMonth: String
    let destDay: String
    let destHour: String
    let destMin: String

    // Preferred height of the header (matches design baseline of the component)
    var height: CGFloat = 180

    @State private var rendered: Image? = nil
    @State private var tick: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let key = "\(Int(size.width))x\(Int(size.height))|\(destYear)|\(destMonth)|\(destDay)|\(destHour)|\(destMin)|\(tick)"
            ZStack {
                if let rendered {
                    rendered
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    // Initial placeholder while first render completes
                    Color.black
                }
            }
            .task(id: key) {
                await render(size: size)
            }
            .onReceive(timer) { _ in tick &+= 1 }
        }
        .frame(height: height)
    }

    @MainActor
    private func render(size: CGSize) async {
        // Compose the vector/header view at the target size
        let content = TimeCircuitsHeaderView(
            yearTop: yearTop,
            yearLeft: yearLeft,
            monLeft: monLeft,
            dayLeft: dayLeft,
            hourLeft: hourLeft,
            minLeft: minLeft,
            destYearTop: destYearTop,
            destYear: destYear,
            destMonth: destMonth,
            destDay: destDay,
            destHour: destHour,
            destMin: destMin
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        #if os(iOS)
        #endif
        if let uiImage = renderer.uiImage {
            rendered = Image(uiImage: uiImage)
        }
    }
}
