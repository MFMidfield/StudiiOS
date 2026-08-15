//
//  FocusModeView.swift
//  หน้า "โฟกัส" — ตัวสลับระหว่างหน้าเริ่มต้นกับหน้ากำลังโฟกัส
//
//  ยกเครื่อง 15 ส.ค. 2569: หน้าเดียวจบ ไม่มีการ์ดซ้อนกันแล้ว
//  · หน้าเริ่มต้น (`FocusHomeView`) = เวลา + ไม้บรรทัดเลื่อน + แท็ก + ปุ่มเริ่ม
//  · หน้ากำลังโฟกัส (`FocusRunningView`) = เวลาอย่างเดียว หยุดโดยกดค้าง 5 วิ
//  · หมดเวลา → `FocusBreakPrompt` ถามว่าจะพัก 5 นาทีไหม
//
//  หมายเหตุ: เคยมีหน้าจอล็อกเต็มจอ (`FocusLockOverlay`) — **ถอดออกแล้ว** ตั้งใจ
//  เหลือการบล็อกแอปอื่นผ่าน Screen Time API อย่างเดียว ห้ามใส่กลับโดยไม่ถามก่อน
//
//  เวลาและสถานะทั้งหมดอยู่ที่ `PomodoroEngine.shared` ไฟล์กลุ่มนี้แค่วาด
//  ห้ามเก็บ secondsRemaining เป็น @State ที่ไหนเด็ดขาด (ของเดิมพังเพราะเรื่องนี้)
//

import SwiftUI
import SwiftData

struct FocusModeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var engine = PomodoroEngine.shared
    @State private var blocker = AppBlockManager.shared

    var body: some View {
        ZStack {
            if engine.isRunning {
                FocusRunningView(onBack: { dismiss() })
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
            } else {
                FocusHomeView(onBack: { dismiss() })
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.smooth(duration: 0.45), value: engine.isRunning)
        .overlay {
            if engine.isAskingForBreak {
                FocusBreakPrompt(
                    onBreak: { engine.startBreak() },
                    onSkip: { engine.declineBreak() }
                )
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: engine.isAskingForBreak)
        .toolbar(.hidden, for: .navigationBar)
        .interactiveSwipeBack()
        .task {
            engine.attach(context: context)
            engine.syncToNow()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            engine.syncToNow()
            blocker.reconcile()
        }
    }
}

#Preview {
    NavigationStack { FocusModeView() }
        .modelContainer(for: [FocusSession.self, FocusTag.self], inMemory: true)
}
