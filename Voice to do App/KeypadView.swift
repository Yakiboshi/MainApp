import SwiftUI
import SwiftData

struct KeypadView: View {
    @State private var dest = DestinationTime()
    @State private var showQuick = false
    @State private var navigateToRecording = false
    @State private var fadePulse = false
    @Environment(\.modelContext) private var modelContext
    @Query private var customPresets: [QuickPresetEntity]

    private var isValid: Bool {
        dest.isValid()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.appBlue.ignoresSafeArea()
                VStack(spacing: 28) {
                    presentTime
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.compact.down").foregroundStyle(.white)
                        Image(systemName: "chevron.compact.down").foregroundStyle(.white)
                }.font(.title)
                destinationView
                    .padding(.bottom, 14)
                    .zIndex(1)
                keypad
                    .padding(.top, 6)
                    .zIndex(1)
                callButton
                    .padding(.top, 6)
                    .zIndex(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 0)
                // Extend background under the TabBar so any reserved area shows blue, not white
                .background(alignment: .bottom) {
                    Theme.appBlue
                        .frame(height: 80)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .sheet(isPresented: $showQuick) { quickSheet }
            .navigationDestination(isPresented: $navigateToRecording) {
                if let date = dest.toDate() { RecordingView(scheduledDate: date) }
            }
        }
    }

    private var presentTime: some View {
        let now = Date()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                segment(title: "YEAR", text: yearString(now), labelOnTop: true, textColor: Theme.segmentPresentText, isPresentRow: true)
                segment(title: "MON", text: two(calendar.component(.month, from: now)), labelOnTop: true, textColor: Theme.segmentPresentText, isPresentRow: true)
                segment(title: "DAY", text: two(calendar.component(.day, from: now)), labelOnTop: true, textColor: Theme.segmentPresentText, isPresentRow: true)
                segment(title: "HOUR", text: two(calendar.component(.hour, from: now)), labelOnTop: true, textColor: Theme.segmentPresentText, isPresentRow: true)
                segment(title: "MIN", text: two(calendar.component(.minute, from: now)), labelOnTop: true, textColor: Theme.segmentPresentText, isPresentRow: true)
            }
            Text("PRESENT TIME").font(.caption).foregroundStyle(.white.opacity(0.9))
        }
    }

    private var destinationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                segment(title: "YEAR", text: padded(dest.year, count: 4), focused: dest.active == .year, labelOnTop: true) { dest.focus(.year) }
                segment(title: "MON", text: padded(dest.month, count: 2), focused: dest.active == .month, labelOnTop: true) { dest.focus(.month) }
                segment(title: "DAY", text: padded(dest.day, count: 2), focused: dest.active == .day, labelOnTop: true) { dest.focus(.day) }
                segment(title: "HOUR", text: padded(dest.hour, count: 2), focused: dest.active == .hour, labelOnTop: true) { dest.focus(.hour) }
                segment(title: "MIN", text: padded(dest.minute, count: 2), focused: dest.active == .minute, labelOnTop: true) { dest.focus(.minute) }
            }
            Text("DESTINATION TIME").font(.caption).foregroundStyle(.white.opacity(0.9))
        }
    }

    private var keypad: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                ForEach([1,2,3], id: \.self) { n in KeyButton(label: String(n)) { tapDigit(n) } }
            }
            HStack(spacing: 14) {
                ForEach([4,5,6], id: \.self) { n in KeyButton(label: String(n)) { tapDigit(n) } }
            }
            HStack(spacing: 14) {
                ForEach([7,8,9], id: \.self) { n in KeyButton(label: String(n)) { tapDigit(n) } }
            }
            HStack(spacing: 14) {
                KeyButton(system: "clock", action: { showQuick = true })
                KeyButton(label: "0") { tapDigit(0) }
                KeyButton(system: "delete.left", action: { tapBackspace() })
            }
        }
    }

    private var callButton: some View {
        Button(action: callPressed) {
            Image(systemName: "phone.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 10).fill(isValid ? Color.green : Color.gray.opacity(0.6)))
        }
        .scaleEffect(fadePulse ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: fadePulse)
    }

    // MARK: - Actions
    private func tapDigit(_ n: Int) {
        fadePulse.toggle()
        Haptics.lightTap()
        SoundManager.shared.play("k\(n)")
        dest.appendDigit(n)
    }
    private func tapBackspace() {
        fadePulse.toggle()
        Haptics.lightTap()
        SoundManager.shared.play("kright")
        dest.backspace()
    }
    private func callPressed() {
        fadePulse.toggle()
        Haptics.lightTap()
        if isValid {
            SoundManager.shared.play("k0")
            navigateToRecording = true
        } else {
            SoundManager.shared.play("ke")
        }
    }

    // MARK: - Quick Sheet
    private var quickSheet: some View {
        NavigationStack {
            List {
                Section("固定プリセット") {
                    ForEach(QuickPreset.defaultPresets(), id: \.id) { preset in
                        Button(preset.title) { apply(preset) }
                    }
                }
                Section("カスタムプリセット") {
                    let sorted = customPresets.sorted { $0.createdAt > $1.createdAt }
                    if sorted.isEmpty {
                        Text("カスタムプリセットは未作成です").foregroundStyle(.secondary)
                    }
                    ForEach(sorted) { p in
                        Button(p.title) { apply(entity: p) }
                    }
                    .onDelete { indexSet in
                        for i in indexSet { modelContext.delete(sorted[i]) }
                        try? modelContext.save()
                    }
                    NavigationLink("新規作成") {
                        QuickPresetEditorView { entity in
                            modelContext.insert(entity)
                            try? modelContext.save()
                        }
                    }
                }
                Section {
                    NavigationLink("DatePickerで選択") {
                        QuickDatePickerView { date in
                            setDestination(date)
                            showQuick = false
                        }
                    }
                }
            }
            .navigationTitle("クイック設定")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showQuick = false } } }
        }
    }

    private func apply(_ preset: QuickPreset) {
        let cal = calendar
        let now = Date()
        switch preset.kind {
        case .offsetDays(let d, hour: let h, minute: let m):
            if let base = cal.date(byAdding: .day, value: d, to: now) {
                var comp = cal.dateComponents([.year,.month,.day], from: base)
                comp.hour = h % 24
                comp.minute = m % 60
                if let date = cal.date(from: comp) { setDestination(date) }
            }
        }
        showQuick = false
    }

    private func pickWithDatePicker() {
        // MVP: 現状は +1時間を適用して閉じる
        apply(.init(title: "+1時間", kind: .offsetDays(0, hour: calendar.component(.hour, from: Date())+1, minute: calendar.component(.minute, from: Date()))))
    }

    private func setDestination(_ date: Date) {
        let c = calendar
        dest.year = String(c.component(.year, from: date))
        dest.month = two(c.component(.month, from: date))
        dest.day = two(c.component(.day, from: date))
        dest.hour = two(c.component(.hour, from: date))
        dest.minute = two(c.component(.minute, from: date))
        dest.active = .minute
    }

    // MARK: - UI helpers
    private func segment(title: String, text: String, focused: Bool = false, labelOnTop: Bool = false, textColor: Color = Theme.segmentText, isPresentRow: Bool = false, tap: (() -> Void)? = nil) -> some View {
        VStack(spacing: 4) {
            if labelOnTop { plate(title) }
            Text(text)
                .font(.system(.title2, design: .monospaced).weight(.heavy))
                .foregroundStyle(textColor)
                .padding(.vertical, 6).padding(.horizontal, 10)
                .frame(minWidth: 62)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black)
                        .shadow(color: .white.opacity(isPresentRow ? 0.18 : 0.10), radius: 2, x: 0, y: 0)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(focused ? Theme.segmentBorderActive : Color.clear, lineWidth: focused ? 3 : 0)
                )
                .onTapGesture { tap?() }
            if !labelOnTop { plate(title) }
        }
    }

    private func plate(_ title: String) -> some View {
        Text(title)
            .font(.caption2.bold())
            .foregroundStyle(Theme.plateText)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.plateFill))
    }

    private func two(_ v: Int) -> String { String(format: "%02d", v) }
    private func yearString(_ date: Date) -> String { String(Calendar.current.component(.year, from: date)) }
    private func padded(_ s: String, count: Int) -> String { s.isEmpty ? String(repeating: "-", count: count) : s }
    private var calendar: Calendar { var c = Calendar.current; c.timeZone = .current; return c }

    // Apply SwiftData entity
    private func apply(entity: QuickPresetEntity) {
        let now = Date()
        if let base = calendar.date(byAdding: .day, value: entity.daysOffset, to: now) {
            var comp = calendar.dateComponents([.year,.month,.day], from: base)
            comp.hour = entity.hour
            comp.minute = entity.minute
            if let date = calendar.date(from: comp) { setDestination(date) }
        }
        showQuick = false
    }
}

private struct KeyButton: View {
    var label: String? = nil
    var system: String? = nil
    var action: () -> Void

    init(label: String, action: @escaping () -> Void) { self.label = label; self.system = nil; self.action = action }
    init(system: String, action: @escaping () -> Void) { self.system = system; self.label = nil; self.action = action }

    @State private var pressed = false

    var body: some View {
        Button(action: {
            pressed.toggle()
            withAnimation(.easeInOut(duration: 0.12)) { pressed.toggle() }
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Theme.keyFillTop, Theme.keyFillBottom], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .white.opacity(0.10), radius: 2, x: 0, y: 0)
                Group {
                    if let label { Text(label).font(.title2) }
                    else if let system { Image(systemName: system) }
                }
                .foregroundStyle(.white)
            }
            .frame(width: 64, height: 56)
            .brightness(pressed ? 0.2 : 0)
        }
    }
}
