//
//  GradeCenterView.swift
//  Grade Center: GPAX summary + per-term grade list.
//  GradeComponent model is kept for SwiftData store compatibility but has no
//  UI here anymore — see PLAN_2026-08-10_Fixes.md Task 4.
//

import SwiftUI
import SwiftData

struct GradeCenterView: View {
    // D7: `terms` feeds gpaxTermInputs only. TermStore.activeTermKey is
    // deliberately absent — the title used to name the term being browsed in
    // the timetable while every number below came from the real term, so the
    // heading contradicted the page.
    @Query private var terms: [Term]

    // MARK: - Level 1 GPAX
    // D7: reads GPAXSettings.currentSortKey (the student's real term), never
    // activeTermID above (that one is only the term being browsed).
    //
    /// ตัวจริงที่ทำให้หน้านี้วาดใหม่เมื่อค่า GPAX เปลี่ยน — **ต้องอ่าน `revision` ใน body**
    /// (ดู `GPAXStore`) · @AppStorage ข้างล่างเป็นของเดิม เก็บไว้เป็นตาข่ายกันพลาด
    @State private var gpaxStore = GPAXStore.shared

    // These @AppStorage vars are never read directly below — GPAXSettings'
    // getters re-apply validation/fallbacks. เดิมพึ่งตัวพวกนี้อย่างเดียวแล้ว
    // **ไม่พอ**: ตั้งเป้า GPAX แล้วหน้าไม่อัปเดตจนกว่าจะออกแล้วเข้าใหม่ (16 ส.ค. 2569)
    @AppStorage(GPAXSettings.Key.currentGradeLevel) private var gpaxGradeLevelPing = 0
    @AppStorage(GPAXSettings.Key.currentTermNumber) private var gpaxTermNumberPing = 0
    @AppStorage(GPAXSettings.Key.target) private var gpaxTargetPing = 0.0
    @AppStorage(GPAXSettings.Key.entryMode) private var gpaxEntryModePing = ""
    @AppStorage(GPAXSettings.Key.priorGPAX) private var gpaxPriorGPAXPing = 0.0
    @AppStorage(GPAXSettings.Key.priorCredits) private var gpaxPriorCreditsPing = 0.0
    @AppStorage(GPAXSettings.Key.priorTermCount) private var gpaxPriorTermCountPing = 0

    private var gpaxTermInputs: [GPAXCalculator.TermInput] {
        GPAXCalculator.upperBandSortKeys.map { sortKey in
            let match = terms.first { $0.gradeLevel * 10 + $0.termNumber == sortKey }
            return GPAXCalculator.TermInput(sortKey: sortKey, gpa: match?.gpa, totalCredits: match?.totalCredits)
        }
    }

    private var gpaxResult: GPAXCalculator.Result? {
        guard let currentSortKey = GPAXSettings.currentSortKey else { return nil }
        return GPAXCalculator.calculate(
            terms: gpaxTermInputs,
            currentSortKey: currentSortKey,
            target: GPAXSettings.hasTarget ? GPAXSettings.target : nil,
            cumulative: GPAXSettings.cumulativeOverride
        )
    }

    private var title: String {
        guard let sortKey = GPAXSettings.currentSortKey else { return "เกรดและ GPAX" }
        return "เกรดและ GPAX · ม.\(sortKey / 10) เทอม \(sortKey % 10)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // อ่าน revision เพื่อผูก dependency — ตั้งเป้า/เปลี่ยนเทอมแล้วหน้านี้จะวาดใหม่ทันที
                let _ = gpaxStore.revision

                GPAXSummaryCard(result: gpaxResult)
                // โชว์กราฟ + รายการเทอมตั้งแต่ตั้งเป้าแล้ว แม้ยังไม่มีเกรดสักเทอม —
                // นี่คือทางเดียวที่ผู้ใช้จะรู้ว่าต้องไปกดเทอมไหนเพื่อกรอก (16 ส.ค. 2569)
                if GPAXSettings.currentSortKey != nil {
                    TermGradeListSection(result: gpaxResult, terms: terms)
                }
            }
            .padding()
        }
        .background(Theme.Colors.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { GradeCenterView() }
        .modelContainer(for: [GradeComponent.self, Term.self, TermSubject.self, TermGradeSubject.self, ScheduleEntry.self, Subject.self], inMemory: true)
}
