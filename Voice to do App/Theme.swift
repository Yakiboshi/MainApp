import SwiftUI

enum Theme {
    // Exact app blue (sampled approximate from keypadUI.png bottom/nav)
    // sRGB: #1B1E63 (27, 30, 99)
    static let appBlue = Color(red: 27/255, green: 30/255, blue: 99/255)
    // Optional subtle variants if needed
    static let bgTop = appBlue
    static let bgBottom = appBlue
    static let tabBlue = appBlue

    // Segment
    static let segmentBackground = Color.black.opacity(0.82)
    static let segmentText = Color.white
    static let segmentPresentText = Color(red: 0.90, green: 1.0, blue: 0.90) // slight green tint
    static let segmentBorderActive = Color.white
    static let segmentDash = Color.white.opacity(0.6)

    // Label plate
    static let plateFill = Color(red: 0.92, green: 0.78, blue: 0.40)
    static let plateText = Color(red: 0.20, green: 0.12, blue: 0.02)

    // Keys
    static let keyFillTop = Color(red: 0.22, green: 0.35, blue: 0.78)
    static let keyFillBottom = Color(red: 0.14, green: 0.22, blue: 0.55)
    static let keyStroke = Color.white.opacity(0.7)
}
