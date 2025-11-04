import SwiftUI
import UIKit
import Combine

// 下部ナビゲーション（UIのみ）＋中央キーパッド（UIのみ）
struct AppTabsView: View {
    @State private var selectedIndex: Int = 2 // 0:設定 1:履歴 2:キーパッド 3:予定 4:留守電

    private let items: [NavItem] = [
        .init(title: "設定", system: "gearshape.fill"),
        .init(title: "履歴", system: "clock"),
        .init(title: "キーパッド", system: "phone.fill"),
        .init(title: "予定", system: "calendar"),
        .init(title: "留守電", system: "tray.fill")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.appGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                TopTimeHeader(imageName: "timecircuits2", topPadding: 50)
                KeypadUI()
                    .padding(.bottom, 32) // ナビとの間隔を+20pt拡張（他間隔は固定）
                BottomNavBar(items: items, selectedIndex: $selectedIndex)
            }
        }
    }
}

private struct NavItem: Identifiable {
    let id = UUID()
    let title: String
    let system: String
}

private struct BottomNavBar: View {
    let items: [NavItem]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    Button(action: { selectedIndex = idx }) {
                        VStack(spacing: 3) {
                            Image(systemName: item.system)
                                .font(.system(size: 18, weight: .semibold))
                            Text(item.title)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(idx == selectedIndex ? Color.white : Color.white.opacity(0.85))
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.bottom, 8)
            .background(Theme.tabBlue)
        }
        .ignoresSafeArea(edges: .bottom)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: -2)
    }
}

// MARK: - Central Keypad UI (UIのみ)
private struct KeypadUI: View {
    var body: some View {
        GeometryReader { geo in
            // 端末別レイアウト（iPhone/ iPad）
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            // 基準幅（直径算出用）。iPadは広めに確保
            let baseWidth = isPad ? min(geo.size.width * 0.50, 480) : min(geo.size.width * 0.62, 250)
            let baseColSpacing: CGFloat = isPad ? 20 : 10
            let keyDPre = (baseWidth - baseColSpacing * 2) / 3 // 基準直径
            let visibleDiameter = keyDPre * (isPad ? 0.95 : 0.85)

            // 横/縦の間隔。iPadでは少し広め
            let colSpacing: CGFloat = isPad ? (baseColSpacing + 30) : (baseColSpacing + 20)
            let rowSpacing: CGFloat = isPad ? 28 : 20
            // 中央列の中心を維持するため、列間に合わせて幅を再計算
            let contentW = keyDPre * 3 + colSpacing * 2
            // 0行とコールの見かけの間隔を維持。iPadはわずかに増やす
            let callLift: CGFloat = isPad ? 20 : 16

            VStack(spacing: rowSpacing) {
                VStack(spacing: rowSpacing) {
                    keypadRow([.digit(1), .digit(2), .digit(3)], diameter: visibleDiameter, spacing: colSpacing)
                    keypadRow([.digit(4), .digit(5), .digit(6)], diameter: visibleDiameter, spacing: colSpacing)
                    keypadRow([.digit(7), .digit(8), .digit(9)], diameter: visibleDiameter, spacing: colSpacing)
                    HStack(spacing: colSpacing) {
                        KeyButtonUI(diameter: visibleDiameter, systemName: "clock", soundName: "kleft")
                        KeyButtonUI(diameter: visibleDiameter, title: "0", soundName: "k0")
                        KeyButtonUI(diameter: visibleDiameter, systemName: "delete.left", soundName: "kright")
                    }
                }
                .padding(.bottom, callLift) // 見かけの 0 行 ↔ コール間を rowSpacing に揃える
                // Call button（中心は現状のまま）
                HStack { Spacer()
                    CallButtonUI(diameter: visibleDiameter, soundName: "ke")
                    Spacer() }
                .offset(y: -callLift)
            }
            .frame(width: contentW)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isPad ? .top : .bottom)
        }
        .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 520 : 420)
    }

    private enum Key: Hashable { case digit(Int) }

    @ViewBuilder
    private func keypadRow(_ keys: [Key], diameter: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(keys, id: \.self) { k in
                switch k {
                case .digit(let n): KeyButtonUI(diameter: diameter, title: String(n), soundName: "k\(n)")
                }
            }
        }
    }
}

private struct KeyButtonUI: View {
    var diameter: CGFloat
    var title: String? = nil
    var systemName: String? = nil
    var soundName: String? = nil
    @State private var pressed = false

    init(diameter: CGFloat, title: String, soundName: String? = nil) {
        self.diameter = diameter; self.title = title; self.systemName = nil; self.soundName = soundName
    }
    init(diameter: CGFloat, systemName: String, soundName: String? = nil) {
        self.diameter = diameter; self.systemName = systemName; self.title = nil; self.soundName = soundName
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed.toggle() }
            if let s = soundName { SoundManager.shared.play(s) }
            DispatchQueue.main.asyncAfter(deadline: .now()+0.10) {
                withAnimation(.easeInOut(duration: 0.08)) { pressed = false }
            }
        }) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.keyFillTop, Theme.keyFillBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                Group {
                    if let title { Text(title).font(.system(size: 28, weight: .semibold)) }
                    else if let systemName { Image(systemName: systemName).font(.system(size: 24, weight: .semibold)) }
                }
                .foregroundStyle(.white)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(pressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

private struct CallButtonUI: View {
    var diameter: CGFloat
    var soundName: String = "ke"
    @State private var pressed = false
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed.toggle() }
            SoundManager.shared.play(soundName)
            DispatchQueue.main.asyncAfter(deadline: .now()+0.12) {
                withAnimation(.easeInOut(duration: 0.08)) { pressed = false }
            }
        }) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.callFillTop, Theme.callFillBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                Image(systemName: "phone.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

// MARK: - Top image header (時刻表示エリアの土台)
private struct TopTimeHeader: View {
    var imageName: String
    var topPadding: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let ui = UIImage(named: imageName) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(ui.size, contentMode: .fit)
                } else {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                }
            }
            // 現在時刻オーバーレイ（上段） — 時刻は現状のまま（修正なし）
            if UIDevice.current.userInterfaceIdiom == .pad {
                TimeRowOverlay(layout: .defaultPad)
                    .allowsHitTesting(false)
            } else {
                TimeRowOverlay(layout: .defaultPhone)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, topPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .clipped()
        .modifier(TopSafeEdge())
    }
}

private struct TopSafeEdge: ViewModifier {
    func body(content: Content) -> some View {
        content.ignoresSafeArea(edges: [.top])
    }
}

// iPadではTopSafeAreaPinで天井に密着し、高さは画像のFitに任せます（iPhoneは指定高さ）

// MARK: - Time row overlay (現在時刻: 上段)
private struct TimeRowOverlay: View {
    struct Layout {
        var topInset: CGFloat
        var leftInset: CGFloat
        // 一文字あたりの絶対横幅（pt）
        var charWidthPt: CGFloat
    }


    var layout: Layout
    @State private var now: Date = Date()

    var body: some View {
        GeometryReader { _ in
            // 1文字分の幅をptで指定（オーバーフロー時の自動縮小は行わない）
            let charW = layout.charWidthPt
            let yearW = charW * 4
            let smallW = charW * 2
            let fontSize = max(charW, 1)

            HStack(spacing: 0) {
                DigitText(text: yearText, width: yearW, fontSize: fontSize)
                DigitText(text: two(month), width: smallW, fontSize: fontSize)
                DigitText(text: two(day), width: smallW, fontSize: fontSize)
                DigitText(text: two(hour), width: smallW, fontSize: fontSize)
                DigitText(text: two(minute), width: smallW, fontSize: fontSize)
            }
            .offset(x: layout.leftInset, y: layout.topInset)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    // MARK: - Date comps
    private var calendar: Calendar { var c = Calendar.current; c.timeZone = .current; return c }
    private var yearText: String { String(calendar.component(.year, from: now)) }
    private var month: Int { calendar.component(.month, from: now) }
    private var day: Int { calendar.component(.day, from: now) }
    private var hour: Int { calendar.component(.hour, from: now) }
    private var minute: Int { calendar.component(.minute, from: now) }
    private func two(_ v: Int) -> String { String(format: "%02d", v) }
}

// デフォルトレイアウト定義を Layout 側に持たせ、`.defaultPhone`/`.defaultPad` の省略記法を有効にする
private extension TimeRowOverlay.Layout {
    // 初期値（pt指定）: 必要に応じてここを編集
    static let defaultPhone = Self(
        topInset: 30, leftInset: 0,
        charWidthPt: 55
    )
    static let defaultPad = Self(
        topInset: 28, leftInset: 28,
        charWidthPt: 36
    )
}

private struct DigitText: View {
    var text: String
    var width: CGFloat
    var fontSize: CGFloat

    var body: some View {
        Text(text)
            .font(.custom("BTTFTimeCircuitsUPDATEDAGAINIMSORRY", size: fontSize))
            .foregroundStyle(Theme.segmentPresentText)
            .frame(width: width, alignment: .center)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

// 初期化に伴い、個別ギャップビューは不要
