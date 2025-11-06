import SwiftUI

    enum Theme {
    // Base brand blue
    // sRGB: #1B1E63 (27, 30, 99)
    static let appBlue = Color(red: 27/255, green: 30/255, blue: 99/255)

    // Background gradient (soft, eye-friendly; tuned to keypadUI2.png 近似)
    static let bgTop = Color(red: 44/255, green: 55/255, blue: 140/255)
    static let bgBottom = Color(red: 18/255, green: 23/255, blue: 84/255)
    static let tabBlue = appBlue
    static var appGradient: LinearGradient {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Segment
    static let segmentBackground = Color.black.opacity(0.82)
    static let segmentText = Color.white
        static let segmentPresentText = Color(red: 0.90, green: 1.0, blue: 0.90) // slight green tint
        static let segmentPlaceholder = Color(white: 0.55) // 濃い灰色プレースホルダ
    static let segmentBorderActive = Color.white
    static let segmentDash = Color.white.opacity(0.6)

    // Label plate
    static let plateFill = Color(red: 0.92, green: 0.78, blue: 0.40)
    static let plateText = Color(red: 0.20, green: 0.12, blue: 0.02)

    // Keys
    static let keyFillTop = Color(red: 0.22, green: 0.35, blue: 0.78)
    static let keyFillBottom = Color(red: 0.14, green: 0.22, blue: 0.55)
    static let keyStroke = Color.white.opacity(0.7)

    // Call button
    static let callFillTop = Color(red: 0.08, green: 0.70, blue: 0.32)
    static let callFillBottom = Color(red: 0.04, green: 0.55, blue: 0.24)

    // Aux sheet background (slightly more cyan than screen background)
    // Slightly more blue and 85% opacity
    static let auxSheetBackground = Color(red: 0.10, green: 0.44, blue: 0.95, opacity: 0.85)
    static let auxSheetBackgroundDark = Color(red: 0.06, green: 0.30, blue: 0.75, opacity: 0.90)
    // Aux sheet background for Preset (yellow-green tone)
    static let auxPresetBackground = Color(red: 0.52, green: 0.85, blue: 0.22, opacity: 0.85)
    static let auxPresetBackgroundDark = Color(red: 0.36, green: 0.66, blue: 0.14, opacity: 0.90)
}
