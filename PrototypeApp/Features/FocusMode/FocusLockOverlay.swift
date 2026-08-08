//
//  FocusLockOverlay.swift
//  หน้าจอล็อกเต็มจอระหว่างโฟกัส
//
//  ทำไมถึงไม่มีปุ่มปิดธรรมดา: ทั้งจอมีทางออกทางเดียวคือกดค้าง 3 วินาที
//  ที่ปุ่ม "ยอมแพ้" — กดพลาดไม่หลุด และมีวงแหวนบอกว่าเหลืออีกกี่วินาที
//
//  ข้อจำกัดที่ต้องรู้: iOS ไม่ยอมให้แอปกันผู้ใช้กดปุ่ม Home / ปัดขึ้น
//  หน้านี้จึงกันได้แค่ "ในแอป" ส่วนการกันไปเปิดแอปอื่นจริงๆ เป็นงานของ
//  `AppBlockManager` (Screen Time API) ที่ทำงานคู่กัน
//

import SwiftUI
import UIKit

struct FocusLockOverlay: View {
    @Bindable var engine: PomodoroEngine

    @State private var holdProgress: Double = 0
    @State private var holdTimer: Timer?

    private let holdDuration: Double = 3.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Colors.textPrimary, Theme.Colors.indigo.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xxl) {
                Spacer()

                Label("กำลังโฟกัส", systemImage: "lock.fill")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.75))

                countdown

                if engine.escapeCount > 0 {
                    Label("ออกจากแอปไป \(engine.escapeCount) ครั้ง", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.warning)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(.white.opacity(0.1), in: Capsule())
                }

                Spacer()

                giveUpButton

                Text("กลับไปทำงานต่อ อีก \(minutesLeftText) เท่านั้น")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.xl)
        }
        .interactiveDismissDisabled(true)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            engine.clearEscapeCount()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            cancelHold()
        }
    }

    // MARK: - นาฬิกา

    private var countdown: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: engine.tickToken)

            VStack(spacing: Theme.Spacing.xs) {
                Text(engine.timeString)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("รอบที่ \(engine.completedFocusRounds + 1)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 260, height: 260)
    }

    private var minutesLeftText: String {
        let minutes = Int(ceil(Double(engine.secondsRemaining) / 60))
        return minutes <= 1 ? "ไม่ถึงนาที" : "\(minutes) นาที"
    }

    // MARK: - ปุ่มยอมแพ้ (กดค้าง 3 วิ)

    private var giveUpButton: some View {
        ZStack {
            Capsule()
                .fill(.white.opacity(0.12))

            GeometryReader { geo in
                Capsule()
                    .fill(Theme.Colors.danger.opacity(0.75))
                    .frame(width: geo.size.width * holdProgress)
            }
            .clipShape(Capsule())

            Text(holdProgress > 0
                 ? "ปล่อยเพื่อยกเลิก · อีก \(Int(ceil(holdDuration * (1 - holdProgress)))) วิ"
                 : "กดค้าง 3 วินาทีเพื่อยอมแพ้")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .frame(height: 56)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHold() }
                .onEnded { _ in cancelHold() }
        )
    }

    private func startHold() {
        guard holdTimer == nil else { return }
        let step = 0.05
        let timer = Timer(timeInterval: step, repeats: true) { _ in
            Task { @MainActor in
                holdProgress = min(1, holdProgress + step / holdDuration)
                if holdProgress >= 1 {
                    cancelHold()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    engine.stop()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
    }
}
