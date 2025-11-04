import SwiftUI
import UIKit

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
                TopTimeHeader(imageName: "taimusa-kitto", height: 250)
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
            // 基準（以前の横間隔=10ptでの直径を保持）
            let baseWidth = min(geo.size.width * 0.62, 250)
            let baseColSpacing: CGFloat = 10
            let keyDPre = (baseWidth - baseColSpacing * 2) / 3 // スペーシング10pt時の理論直径
            let visibleDiameter = keyDPre * 0.85               // 実際に描画する直径（既存比率を維持）

            // 要望: 横間隔を+20pt（= 30pt）に広げる。ただし2/5/8/0/コールの中心は不動。
            let colSpacing: CGFloat = baseColSpacing + 20      // 30pt
            let rowSpacing: CGFloat = 20                       // 行間は20ptのまま
            // コンテナ幅を左右対称に+40pt拡張し、中央列の中心を維持
            let contentW = keyDPre * 3 + colSpacing * 2
            let callLift: CGFloat = 16 // コールを上げている分（中心は変更しない）

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 420)
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
    var height: CGFloat = 160

    var body: some View {
        Group {
            if let ui = UIImage(named: imageName) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(imageName) // アセットにある場合はこちらで表示
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}
