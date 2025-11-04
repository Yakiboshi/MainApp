import Foundation
import CoreText

enum Fonts {
    // Register bundled custom fonts at launch
    static func register() {
        registerFont(named: "BTTFTimeCircuitsUPDATEDAGAINIMSORRY", ext: "ttf")
    }

    private static func registerFont(named name: String, ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }
}

