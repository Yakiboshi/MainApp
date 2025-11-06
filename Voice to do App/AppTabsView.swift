import SwiftUI

// 下部ナビゲーション（UIのみ）＋中央キーパッド（UIのみ）
struct AppTabsView: View {
    @State private var selectedIndex: Int = 2 // 0:設定 1:履歴 2:キーパッド 3:予定 4:留守電
    // MARK: Layout constants（独立して編集できます）
    // 高さの数値は縦幅ではなく「画面下端からの距離」として扱う
    private let tmpKeypadBottomOffset: CGFloat = 75

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
                Spacer()
                // キーパッドは横幅指定なし。下端からの距離のみ維持。
                KeypadUI()
                    .padding(.bottom, tmpKeypadBottomOffset)
            }
        }
        // safeAreaInset でナビ上端＝コンテンツ下端を定義
        .safeAreaInset(edge: .bottom) {
            BottomNavBar(items: items, selectedIndex: $selectedIndex)
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
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: -2)
    }
}

// 余計な高さ計測（PreferenceKey）は削除し簡素化

// MARK: - Central Keypad UI (UIのみ)
private struct KeypadUI: View {
    // 比率の記録（現行見た目から算出した固定値）
    private struct Metrics {
        // グループ幅は親の幅に追従（明示比率は定義しない）
        // 横方向のキー間隔（幅に対する比率）。例: 280pt幅時に約30pt → 30/280 ≒ 0.107
        static let spacingXRatio: CGFloat = 0.107
        // 縦方向の行間（幅に対する比率）。例: 280pt幅時に約30pt → 0.107
        static let rowSpacingRatio: CGFloat = 0.107
        // コールボタンの上方向オフセット（幅に対する比率）。例: 16/280 ≒ 0.057
        static let callLiftRatio: CGFloat = 0.057
        // 各キー直径（幅に対する比率）= 3列・両端にスペーシング2つを加味
        static var diameterRatio: CGFloat { (1 - 2*spacingXRatio) / 3 }
        // グループの高さ比（行×4 + 行間×3 + コール直径 − リフト）
        static var heightToWidthRatio: CGFloat {
            4*diameterRatio + 3*rowSpacingRatio + diameterRatio - callLiftRatio
        }
    }

    var body: some View {
        GeometryReader { geo in
            // 親の幅ベースで決定（GeometryReaderは高さを広げがちなので外側で比率拘束する）
            let groupW: CGFloat = geo.size.width
            let d = groupW * Metrics.diameterRatio
            let sx = groupW * Metrics.spacingXRatio
            let sy = groupW * Metrics.rowSpacingRatio
            let callLift = groupW * Metrics.callLiftRatio

            VStack(spacing: sy) {
                VStack(spacing: sy) {
                    keypadRow([.digit(1), .digit(2), .digit(3)], diameter: d, spacing: sx)
                    keypadRow([.digit(4), .digit(5), .digit(6)], diameter: d, spacing: sx)
                    keypadRow([.digit(7), .digit(8), .digit(9)], diameter: d, spacing: sx)
                    HStack(spacing: sx) {
                        KeyButtonUI(diameter: d, systemName: "clock", soundName: "kleft")
                        KeyButtonUI(diameter: d, title: "0", soundName: "k0")
                        KeyButtonUI(diameter: d, systemName: "delete.left", soundName: "kright")
                    }
                }
                .padding(.bottom, callLift)
                HStack { Spacer(); CallButtonUI(diameter: d, soundName: "ke"); Spacer() }
                    .offset(y: -callLift)
            }
        }
        // GeometryReader 自身の高さを、横幅基準の比率で拘束して Keypad の位置決めを乱さない
        .aspectRatio(1.0 / KeypadUI.Metrics.heightToWidthRatio, contentMode: .fit)
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

// (ヘッダー関連ビューは削除済み)
