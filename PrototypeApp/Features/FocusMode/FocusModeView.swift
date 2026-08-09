//
//  FocusModeView.swift
//  หน้า "โฟกัส" — ตั้งเวลา Pomodoro, เลือกแอปที่จะบล็อก, ดูสถิติ
//
//  หมายเหตุ: เคยมีหน้าจอล็อกเต็มจอ (`FocusLockOverlay`) ตอนโฟกัส — **ถอดออกแล้ว**
//  ตั้งใจ เหลือการบล็อกแอปอื่นผ่าน Screen Time API อย่างเดียว ห้ามใส่กลับ
//  โดยไม่ถามก่อน
//
//  เวลาและสถานะทั้งหมดอยู่ที่ `PomodoroEngine.shared` ไฟล์นี้แค่วาด
//  ห้ามเก็บ secondsRemaining เป็น @State ที่นี่เด็ดขาด (ของเดิมพังเพราะเรื่องนี้)
//

import SwiftUI
import SwiftData
import FamilyControls

struct FocusModeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var sessions: [FocusSession]

    @State private var engine = PomodoroEngine.shared
    @State private var blocker = AppBlockManager.shared

    @AppStorage(PomodoroSettings.Key.focusMinutes) private var focusMinutes = PomodoroSettings.defaultFocusMinutes
    @AppStorage(PomodoroSettings.Key.shortBreakMinutes) private var shortBreakMinutes = PomodoroSettings.defaultShortBreakMinutes
    @AppStorage(PomodoroSettings.Key.longBreakMinutes) private var longBreakMinutes = PomodoroSettings.defaultLongBreakMinutes
    @AppStorage(PomodoroSettings.Key.roundsBeforeLong) private var roundsBeforeLong = PomodoroSettings.defaultRoundsBeforeLongBreak
    @AppStorage(PomodoroSettings.Key.autoContinue) private var autoContinue = true
    @AppStorage(PomodoroSettings.Key.blockAppsEnabled) private var blockAppsEnabled = false

    @State private var showCustomPicker = false
    @State private var customMinutes = 25
    @State private var showAppPicker = false
    @State private var showSettings = false
    @State private var showAuthAlert = false

    // body ถูกแบ่งเป็น 2 ชั้น (`mainContent` + presentation) จงใจ —
    // ต่อ modifier ยาวเป็นสายเดียวคือสาเหตุคลาสสิกของ
    // "unable to type-check this expression in reasonable time"
    var body: some View {
        mainContent
            .sheet(isPresented: $showCustomPicker) { customPickerSheet }
            .sheet(isPresented: $showSettings) { settingsSheet }
            .familyActivityPicker(isPresented: $showAppPicker, selection: $blocker.selection)
            .alert("เปิดระบบบล็อกแอปไม่สำเร็จ", isPresented: $showAuthAlert) {
                Button("เข้าใจแล้ว", role: .cancel) {}
            } message: {
                Text(blocker.authorizationError ?? "ลองใหม่อีกครั้ง")
            }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                timerCard
                if engine.isIdle { presetCard }
                blockCard
                statsCard
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle("โฟกัส")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
            }
        }
        .task {
            engine.attach(context: context)
            engine.syncToNow()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    private func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            engine.syncToNow()
            blocker.reconcile()
        default:
            break
        }
    }

    // MARK: - การ์ดนาฬิกา

    private var timerCard: some View {
        CardContainer {
            HStack {
                Label(engine.phase.label, systemImage: engine.phase.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(phaseColor)
                Spacer()
                if !engine.isIdle {
                    Text("รอบที่ \(engine.completedFocusRounds + (engine.phase == .focus ? 1 : 0))")
                        .font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            ZStack {
                Circle()
                    .stroke(Theme.Colors.separator, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: engine.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: engine.tickToken)

                VStack(spacing: Theme.Spacing.xs) {
                    Text(engine.timeString)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(engine.isPaused ? "หยุดชั่วคราว" : (engine.isIdle ? "\(focusMinutes) นาที" : "เหลืออีก"))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .frame(height: 220)
            .padding(.vertical, Theme.Spacing.sm)

            roundDots

            controlButtons
        }
    }

    /// จำนวนจุดที่ระบายสี = รอบโฟกัสที่ทำจบแล้วในชุดปัจจุบัน
    private var filledDots: Int {
        engine.completedFocusRounds % roundsBeforeLong
    }

    private var roundDots: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<roundsBeforeLong, id: \.self) { index in
                Circle()
                    .fill(index < filledDots ? Theme.Colors.primary : Theme.Colors.separator)
                    .frame(width: 8, height: 8)
            }
            Text("ครบ \(roundsBeforeLong) รอบ = พักยาว \(longBreakMinutes) นาที")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: Theme.Spacing.md) {
            if engine.isIdle {
                Button {
                    startFocus(minutes: focusMinutes)
                } label: {
                    Label("เริ่มโฟกัส", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    engine.isPaused ? engine.resume() : engine.pause()
                } label: {
                    Label(engine.isPaused ? "เริ่มต่อ" : "หยุดชั่วคราว",
                          systemImage: engine.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if engine.phase.isBreak {
                    Button {
                        engine.skipBreak()
                    } label: {
                        Label("ข้ามพัก", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button(role: .destructive) {
                    engine.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - การ์ดเลือกเวลา

    private var presetCard: some View {
        CardContainer {
            Text("เลือกเวลาโฟกัส")
                .font(.subheadline).fontWeight(.semibold)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(PomodoroSettings.focusPresets, id: \.self) { minutes in
                    Button {
                        focusMinutes = minutes
                    } label: {
                        Text("\(minutes)")
                            .font(.subheadline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.md)
                            .background(focusMinutes == minutes ? Theme.Colors.primary : Theme.Colors.background)
                            .foregroundStyle(focusMinutes == minutes ? .white : Theme.Colors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    customMinutes = focusMinutes
                    showCustomPicker = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline).fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(PomodoroSettings.focusPresets.contains(focusMinutes) ? Theme.Colors.background : Theme.Colors.primary)
                        .foregroundStyle(PomodoroSettings.focusPresets.contains(focusMinutes) ? Theme.Colors.textPrimary : .white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.plain)
            }

            Text("หน่วยเป็นนาที · แตะ ⋯ เพื่อกำหนดเอง")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var customPickerSheet: some View {
        NavigationStack {
            VStack {
                Picker("นาที", selection: $customMinutes) {
                    ForEach(PomodoroSettings.minuteRange, id: \.self) { minute in
                        Text("\(minute) นาที").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("กำหนดเวลาเอง")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { showCustomPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ใช้เวลานี้") {
                        focusMinutes = customMinutes
                        showCustomPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - การ์ดบล็อกแอป

    private var blockCard: some View {
        CardContainer {
            Text("บล็อกแอปอื่น")
                .font(.subheadline).fontWeight(.semibold)

            Toggle(isOn: $blockAppsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("เปิดใช้งาน")
                        if blocker.isBlocking {
                            Text("กำลังบล็อก")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Colors.danger.opacity(0.15))
                                .foregroundStyle(Theme.Colors.danger)
                                .clipShape(Capsule())
                        }
                    }
                    Text("ใช้ Screen Time ของ iOS — เข้าแอปที่เลือกไม่ได้เลยจนหมดเวลา")
                        .font(.caption2).foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .disabled(!engine.isIdle)
            .onChange(of: blockAppsEnabled) { _, isOn in
                guard isOn else {
                    blocker.stopBlocking(reason: "ปิดสวิตช์")
                    return
                }
                Task {
                    let ok = await blocker.requestAuthorization()
                    if !ok {
                        blockAppsEnabled = false
                        showAuthAlert = true
                    }
                }
            }

            if blockAppsEnabled {
                Button {
                    showAppPicker = true
                } label: {
                    HStack {
                        Label("เลือกแอปที่จะบล็อก", systemImage: "hand.raised.fill")
                        Spacer()
                        Text(blocker.selectionSummary)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .disabled(!engine.isIdle)

                if !blocker.hasSelection {
                    Label("ยังไม่ได้เลือกแอป — เริ่มโฟกัสไปก็ยังไม่บล็อกอะไร", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.warning)
                }
            }

            if let error = blocker.authorizationError, blockAppsEnabled {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.danger)
            }
        }
    }

    // MARK: - สถิติ

    private var statsCard: some View {
        CardContainer {
            Text("สถิติการโฟกัส")
                .font(.subheadline).fontWeight(.semibold)
            HStack(spacing: Theme.Spacing.lg) {
                FocusStatBlock(value: "\(todaysMinutes)", label: "นาทีวันนี้")
                FocusStatBlock(value: "\(weekMinutes)", label: "นาทีสัปดาห์นี้")
                FocusStatBlock(value: "\(completedFocusCount)", label: "รอบสำเร็จ")
            }
        }
    }

    private var focusSessions: [FocusSession] {
        sessions.filter { $0.phase == .focus }
    }

    private var todaysMinutes: Int {
        focusSessions
            .filter { Calendar.current.isDateInToday($0.startedAt) && $0.completed }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var weekMinutes: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return focusSessions
            .filter { $0.startedAt >= weekAgo && $0.completed }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var completedFocusCount: Int {
        focusSessions.filter(\.completed).count
    }

    // MARK: - การตั้งค่า

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("ความยาวแต่ละช่วง (นาที)") {
                    Stepper("โฟกัส: \(focusMinutes)", value: $focusMinutes, in: PomodoroSettings.minuteRange)
                    Stepper("พักสั้น: \(shortBreakMinutes)", value: $shortBreakMinutes, in: 1...60)
                    Stepper("พักยาว: \(longBreakMinutes)", value: $longBreakMinutes, in: 1...90)
                }
                Section("รอบ") {
                    Stepper("พักยาวทุก \(roundsBeforeLong) รอบ", value: $roundsBeforeLong, in: 2...8)
                    Toggle("ไปช่วงถัดไปอัตโนมัติ", isOn: $autoContinue)
                }
                Section {
                    Button(role: .destructive) {
                        blocker.stopBlocking(reason: "ปลดล็อกฉุกเฉิน")
                    } label: {
                        Label("ปลดบล็อกแอปทั้งหมดเดี๋ยวนี้", systemImage: "lock.open.fill")
                    }
                } footer: {
                    Text("ใช้เมื่อแอปอื่นถูกบล็อกค้างอยู่")
                }
            }
            .navigationTitle("ตั้งค่า Pomodoro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { showSettings = false }
                }
            }
        }
    }

    // MARK: -

    private var phaseColor: Color {
        engine.phase.isBreak ? Theme.Colors.success : Theme.Colors.primary
    }

    private func startFocus(minutes: Int) {
        engine.attach(context: context)
        engine.startFocus(minutes: minutes)
    }
}

struct FocusStatBlock: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(Theme.Colors.primary)
            Text(label).font(.caption2).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { FocusModeView() }
        .modelContainer(for: FocusSession.self, inMemory: true)
}
