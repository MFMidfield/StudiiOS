//
//  FocusHomeView.swift
//  หน้าเริ่มต้นของโหมดโฟกัส — เวลา · แท็ก · ปุ่มเริ่ม เท่านั้น
//
//  แตะตัวเลขเวลา → ไม้บรรทัด (`FocusDurationRuler`) กางออกให้เลื่อนซ้ายขวา
//  ซ้ายสุดของไม้บรรทัดคือ ∞ (นับขึ้น) ต่อด้วย 1–180 นาที ทีละ 1
//

import SwiftUI
import SwiftData

struct FocusHomeView: View {
    let onBack: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @State private var engine = PomodoroEngine.shared

    @AppStorage(PomodoroSettings.Key.focusMinutes) private var focusMinutes = PomodoroSettings.defaultFocusMinutes
    @AppStorage(PomodoroSettings.Key.selectedTagID) private var selectedTagID = ""
    /// อ่านผ่าน @AppStorage ไม่ใช่ `PomodoroSettings.blockAppsEnabled` เพราะไอคอน
    /// ต้องเปลี่ยนสีทันทีที่ปิด sheet — ค่า static ไม่กระตุ้นให้ View วาดใหม่
    @AppStorage(PomodoroSettings.Key.blockAppsEnabled) private var blockAppsEnabled = false

    @State private var isPickingTime = false
    @State private var showStats = false
    @State private var showBlockSheet = false
    @State private var showTagEditor = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: Theme.Spacing.lg)

                timeDisplay

                if isPickingTime {
                    FocusDurationRuler(minutes: $focusMinutes)
                        .padding(.top, Theme.Spacing.xl)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer(minLength: Theme.Spacing.lg)

                FocusTagBar(
                    tags: tags,
                    selectedID: $selectedTagID,
                    onManage: { showTagEditor = true }
                )
                .padding(.bottom, Theme.Spacing.xl)

                startButton
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .animation(.smooth(duration: 0.35), value: isPickingTime)
        .task {
            engine.attach(context: context)
            FocusTag.seedDefaultsIfNeeded(in: context, colors: Theme.Colors.subjectPaletteHex)
        }
        .sheet(isPresented: $showStats) { FocusStatsSheet() }
        .sheet(isPresented: $showBlockSheet) { FocusBlockSheet() }
        .sheet(isPresented: $showTagEditor) { FocusTagEditorSheet() }
    }

    // MARK: - หัวหน้า

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            FocusGlassButton(systemName: "chevron.left", action: onBack)
            FocusGlassButton(systemName: "chart.bar.fill") { showStats = true }
            Spacer()
            FocusGlassButton(
                systemName: "hand.raised.fill",
                isActive: blockAppsEnabled
            ) { showBlockSheet = true }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - ตัวเลขเวลา

    private var timeDisplay: some View {
        Button {
            isPickingTime.toggle()
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Text(isInfinity ? "∞" : "\(focusMinutes)")
                    .font(.system(size: isInfinity ? 96 : 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(isInfinity ? "ไม่จำกัดเวลา · นับขึ้น" : "นาที")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Text(isPickingTime ? "เลื่อนซ้ายขวาเพื่อเลือก" : "แตะเพื่อเปลี่ยนเวลา")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                    .padding(.top, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var isInfinity: Bool { focusMinutes <= 0 }

    // MARK: - ปุ่มเริ่ม

    private var startButton: some View {
        Button {
            engine.attach(context: context)
            engine.startFocus(minutes: focusMinutes, tag: selectedTag?.snapshot)
        } label: {
            Text("เริ่ม")
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.primary, in: Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var selectedTag: FocusTag? {
        tags.first { $0.id == selectedTagID }
    }
}

/// ปุ่มกลมแบบ Liquid Glass ที่ใช้ทั้งหน้าเริ่มต้นและหน้ากำลังโฟกัส
struct FocusGlassButton: View {
    let systemName: String
    var isActive: Bool = false
    var tint: Color = Theme.Colors.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? Theme.Colors.primaryDeep : tint)
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FocusHomeView(onBack: {})
        .modelContainer(for: [FocusSession.self, FocusTag.self], inMemory: true)
}
