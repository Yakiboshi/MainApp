import SwiftUI
import Combine

// 下部ナビゲーション（UIのみ）＋中央キーパッド（UIのみ）
struct AppTabsView: View {
    @State private var selectedIndex: Int = 2 // 0:設定 1:履歴 2:キーパッド 3:予定 4:留守電
    // 上段: 現在時刻, 下段: 目的地（キーパッド入力）
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var destination = DestinationTime()
    // 小ウィンドウ表示（見た目のみ）
    @State private var showAuxSheet: Bool = false
    @State private var containerHeight: CGFloat = 0
    @State private var keypadTopY: CGFloat = 0
    @State private var headerBottomY: CGFloat = 0
    @State private var bottomBarHeight: CGFloat = 0
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
            VStack(spacing: 20) {
                // ヘッダー（上段=現在時刻, 下段=入力中の目的地）
                TimeCircuitsOverlayView(
                    present: toRowValues(date: now),
                    destination: toRowValues(destination: destination),
                    showDebugFrames: false,
                    destinationForeground: destinationForegroundColor(now: now)
                )
                .padding(.top, 0)
                // Header bottom reporting via preference
                .onPreferenceChange(HeaderBottomPreferenceKey.self) { headerBottomY = $0 }

                Spacer()
                // キーパッドは横幅指定なし。下端からの距離のみ維持。
                KeypadUI(
                    onDigit: { n in destination.appendDigit(n) },
                    onBackspace: { destination.backspace() },
                    onLeftAux: { withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { showAuxSheet.toggle() } },
                    onOk: { /* TODO: バリデーション/遷移 */ },
                    callSoundNameProvider: { callSoundName(now: now) }
                )
                .background(
                    GeometryReader { p in
                        Color.clear
                            .preference(key: KeypadTopPreferenceKey.self, value: p.frame(in: .named("AppRoot")).minY)
                    }
                )
                .padding(.bottom, tmpKeypadBottomOffset)
            }
            // 小ウィンドウ（見た目のみ）: タブ上端〜ヘッダー下端の範囲を覆う。非表示時は完全に見えない。
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    let h = proxy.size.height
                    Color.clear.onAppear { containerHeight = h }
                    let navTopY = h - bottomBarHeight
                    let startY = headerBottomY
                    let endY = max(startY, navTopY)
                    let sheetHeight = endY - startY
                    if showAuxSheet && sheetHeight > 0 {
                        // Tappable dismiss area (header side)
                        Color.clear
                            .frame(height: startY)
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { showAuxSheet = false } }
                        // The sheet itself
                        AuxSheetPlaceholder(onClose: { withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { showAuxSheet = false } })
                            .frame(height: sheetHeight)
                            .offset(y: startY)
                            .transition(.move(edge: .bottom))
                            .zIndex(1)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showAuxSheet)
        }
        .coordinateSpace(name: "AppRoot")
        // safeAreaInset でナビ上端＝コンテンツ下端を定義
        .safeAreaInset(edge: .bottom) {
            BottomNavBar(items: items, selectedIndex: $selectedIndex, onAnyTap: { withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { showAuxSheet = false } })
                .background(
                    GeometryReader { p in
                        Color.clear.preference(key: BottomBarHeightPreferenceKey.self, value: p.size.height)
                    }
                )
        }
        .onReceive(timer) { now = $0 }
        .onPreferenceChange(KeypadTopPreferenceKey.self) { keypadTopY = $0 }
        .onPreferenceChange(BottomBarHeightPreferenceKey.self) { bottomBarHeight = $0 }
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
    var onAnyTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5)
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    Button(action: {
                        onAnyTap?()
                        selectedIndex = idx
                    }) {
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
    var onDigit: ((Int) -> Void)? = nil
    var onBackspace: (() -> Void)? = nil
    var onLeftAux: (() -> Void)? = nil
    var onOk: (() -> Void)? = nil
    var callSoundNameProvider: (() -> String)? = nil
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
                        KeyButtonUI(diameter: d, systemName: "clock", soundName: "kleft") {
                            onLeftAux?()
                        }
                        KeyButtonUI(diameter: d, title: "0", soundName: "k0") {
                            onDigit?(0)
                        }
                        RepeatBackspaceButtonUI(diameter: d) {
                            onBackspace?()
                        }
                    }
                }
                .padding(.bottom, callLift)
                HStack { Spacer(); CallButtonUI(diameter: d, soundNameProvider: callSoundNameProvider) { onOk?() }; Spacer() }
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
                case .digit(let n):
                    KeyButtonUI(diameter: diameter, title: String(n), soundName: "k\(n)") {
                        onDigit?(n)
                    }
                }
            }
        }
    }
}

// Keypad top Y reporting
private struct KeypadTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct BottomBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// 小ウィンドウの外観（見た目のみ。中身の機能は未実装）
private struct AuxSheetPlaceholder: View {
    var onClose: (() -> Void)? = nil
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background with slight darkening toward bottom
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Theme.auxSheetBackground, Theme.auxSheetBackgroundDark], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Close button (top-right)
            Button(action: { onClose?() }) {
                Text("閉じる")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.auxSheetBackground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.95)))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 8)
            .accessibilityLabel("閉じる")
        }
    }
}

// MARK: - Repeat backspace button (long press to auto-delete)
private struct RepeatBackspaceButtonUI: View {
    var diameter: CGFloat
    var onBackspace: (() -> Void)? = nil
    @State private var pressed = false
    @State private var repeatTimer: Timer? = nil

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed.toggle() }
            SoundManager.shared.play("kright")
            onBackspace?()
            DispatchQueue.main.asyncAfter(deadline: .now()+0.10) {
                withAnimation(.easeInOut(duration: 0.08)) { pressed = false }
            }
        }) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.keyFillTop, Theme.keyFillBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                Image(systemName: "delete.left").font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(pressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: 1.0, maximumDistance: 50, pressing: { isPressing in
            if !isPressing {
                stopRepeating()
            }
        }, perform: {
            startRepeating()
        })
    }

    private func startRepeating() {
        stopRepeating()
        // しきい値到達時にまず1回実行
        onBackspace?()
        // 以降は0.7秒間隔で実行
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            onBackspace?()
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

private struct KeyButtonUI: View {
    var diameter: CGFloat
    var title: String? = nil
    var systemName: String? = nil
    var soundName: String? = nil
    var action: (() -> Void)? = nil
    @State private var pressed = false

    init(diameter: CGFloat, title: String, soundName: String? = nil, action: (() -> Void)? = nil) {
        self.diameter = diameter; self.title = title; self.systemName = nil; self.soundName = soundName; self.action = action
    }
    init(diameter: CGFloat, systemName: String, soundName: String? = nil, action: (() -> Void)? = nil) {
        self.diameter = diameter; self.systemName = systemName; self.title = nil; self.soundName = soundName; self.action = action
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed.toggle() }
            if let s = soundName { SoundManager.shared.play(s) }
            action?()
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
    var soundNameProvider: (() -> String)? = nil
    var action: (() -> Void)? = nil
    @State private var pressed = false
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed.toggle() }
            let name = soundNameProvider?() ?? soundName
            SoundManager.shared.play(name)
            action?()
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

// MARK: - Helpers (AppTabsView)
private extension AppTabsView {
    func toRowValues(date: Date) -> TimeCircuitsOverlayView.RowValues {
        let cal = Calendar.current
        let y = String(format: "%04d", cal.component(.year, from: date))
        let m = String(format: "%02d", cal.component(.month, from: date))
        let d = String(format: "%02d", cal.component(.day, from: date))
        let h = String(format: "%02d", cal.component(.hour, from: date))
        let n = String(format: "%02d", cal.component(.minute, from: date))
        return .init(year: y, month: m, day: d, hour: h, minute: n)
    }

    func toRowValues(destination: DestinationTime) -> TimeCircuitsOverlayView.RowValues {
        .init(year: destination.year,
              month: destination.month,
              day: destination.day,
              hour: destination.hour,
              minute: destination.minute)
    }

    func destinationForegroundColor(now: Date) -> Color {
        // 部分入力でも即時NGにしたいケース
        if hasImmediateInvalid(destination, now: now) { return Color(red: 0.95, green: 0.2, blue: 0.2) }
        // 未入力がある間は白
        guard isComplete(destination) else { return .white }
        // 完成したら妥当性で色分け
        if destination.isValid(now: now) {
            return Color(red: 0.0, green: 0.85, blue: 0.35) // 青信号系の緑
        } else {
            return Color(red: 0.95, green: 0.2, blue: 0.2) // 赤信号
        }
    }

    func isComplete(_ d: DestinationTime) -> Bool {
        d.year.count == 4 && d.month.count == 2 && d.day.count == 2 && d.hour.count == 2 && d.minute.count == 2
    }

    func hasImmediateInvalid(_ d: DestinationTime, now: Date) -> Bool {
        // YEAR: 4桁かつ 現在の年より小さい → NG
        if d.year.count == 4, let y = Int(d.year) {
            let currentYear = Calendar.current.component(.year, from: now)
            if y < currentYear { return true }
        }
        // MON: 2桁かつ 13以上→NG
        if d.month.count == 2, let m = Int(d.month), m >= 13 { return true }
        // HOUR: 2桁かつ 25以上→NG
        if d.hour.count == 2, let h = Int(d.hour), h >= 25 { return true }
        // MIN: 2桁かつ 61以上→NG
        if d.minute.count == 2, let n = Int(d.minute), n >= 61 { return true }
        // DAY: 月に応じた上限を超えたらNG
        if d.month.count == 2, let m = Int(d.month), (1...12).contains(m), d.day.count == 2, let day = Int(d.day) {
            if let maxDay = maxDayFor(yearString: d.year, month: m) {
                if day > maxDay { return true }
            }
        }
        return false
    }

    func callSoundName(now: Date) -> String {
        // 緑（有効）なら k0、白/赤（未完成 or NG）なら ke
        if !hasImmediateInvalid(destination, now: now) && isComplete(destination) && destination.isValid(now: now) {
            return "k0"
        }
        return "ke"
    }

    func maxDayFor(yearString: String, month: Int) -> Int? {
        let cal = Calendar.current
        let year: Int = (yearString.count == 4 ? Int(yearString) : nil) ?? 2024 // 未入力時は閏年で寛容に
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = 1
        if let date = cal.date(from: comp), let range = cal.range(of: .day, in: .month, for: date) {
            return range.count
        }
        return nil
    }
}
