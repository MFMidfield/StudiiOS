//
//  FocusRunningView.swift
//  หน้ากำลังโฟกัส — มีแค่เวลา ไม่มีปุ่มควบคุมเลย
//
//  หยุดได้ทางเดียว: **กดค้างที่ไหนก็ได้บนจอ 5 วินาที** จนแถบเต็ม
//  ปุ่มเดียวที่เหลือคือย้อนกลับมุมซ้ายบน — กดแล้วออกจากหน้าเฉยๆ
//  **นาฬิกาไม่หยุด** (ตั้งใจ: PomodoroEngine นับจาก Date กลับเข้ามาเมื่อไหร่ก็ยังตรง)
//
//  โครง ZStack เรียงจากล่างขึ้นบน: พื้นหลัง → เนื้อหา (ปิด hit-test)
//  → ตัวรับการกดค้างเต็มจอ → ปุ่มย้อนกลับ
//  ลำดับนี้จำเป็น: ถ้าเนื้อหาอยู่บนตัวรับ การกดค้างบนตัวเลขจะไม่ทำงาน
//  และถ้าปุ่มย้อนกลับอยู่ใต้ตัวรับ ก็จะกดไม่ได้
//

import SwiftUI

struct FocusRunningView: View {
    let onBack: () -> Void

    @State private var engine = PomodoroEngine.shared
    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?

    /// ต้องกดค้างนานเท่านี้ถึงจะหยุด
    private let holdSeconds: Double = 5

    var body: some View {
        ZStack {
            Theme.Colors.focusBackdrop.ignoresSafeArea()

            content
                .allowsHitTesting(false)

            holdCatcher

            VStack {
                HStack {
                    FocusGlassButton(
                        systemName: "chevron.left",
                        tint: Theme.Colors.onFocusBackdrop,
                        action: onBack
                    )
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
        }
        .statusBarHidden(true)
        .onDisappear { cancelHold() }
    }

    // MARK: - เนื้อหา

    private var content: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            if engine.isBreak {
                Text("พัก")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.onFocusBackdropMuted)
            } else if let tag = engine.activeTag {
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: tag.colorHex))
                        .frame(width: 8, height: 8)
                    Text(tag.name)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.onFocusBackdropMuted)
                }
            }

            Text(engine.timeString)
                .font(.system(size: 68, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.onFocusBackdrop)
                // อ่าน tickToken เพื่อให้ @Observable รู้ว่าต้องวาดใหม่ทุก tick
                // (secondsRemaining คำนวณจาก Date.now ซึ่งไม่ใช่ค่าที่สังเกตได้)
                .animation(.linear(duration: 0.4), value: engine.tickToken)

            Spacer()

            FocusHoldToStopBar(progress: holdProgress, isHolding: isHolding)
                .padding(.bottom, Theme.Spacing.xxxl)
        }
    }

    // MARK: - ตัวรับการกดค้าง

    private var holdCatcher: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginHold() }
                    .onEnded { _ in cancelHold() }
            )
    }

    private func beginHold() {
        guard !isHolding else { return }
        isHolding = true
        withAnimation(.linear(duration: holdSeconds)) { holdProgress = 1 }

        holdTask = Task {
            try? await Task.sleep(for: .seconds(holdSeconds))
            guard !Task.isCancelled else { return }
            await MainActor.run { finishHold() }
        }
    }

    /// ปล่อยนิ้วก่อนครบ — แถบไหลกลับ 0 แล้วเริ่มนับใหม่รอบหน้า
    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        guard isHolding else { return }
        isHolding = false
        withAnimation(.easeOut(duration: 0.25)) { holdProgress = 0 }
    }

    private func finishHold() {
        holdTask = nil
        isHolding = false
        holdProgress = 0
        engine.stop()
    }
}
