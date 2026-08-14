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
    // These @AppStorage vars are never read directly below — GPAXSettings'
    // getters re-apply validation/fallbacks. Declaring them here is what makes
    // SwiftUI redraw gpaxResult when GradeLevelSheet / TermGradeEditView's
    // "จำเกรดเทอมนี้ไม่ได้" / the inline target setter write to UserDefaults.
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

    /// No GPAX yet = nothing for the six-row list to say. Six identical
    /// "ยังไม่มีข้อมูล" rows are a wall, not information.
    private var hasGPAX: Bool { gpaxResult?.gpax != nil }

    private var title: String {
        guard let sortKey = GPAXSettings.currentSortKey else { return "เกรดและ GPAX" }
        return "เกรดและ GPAX · ม.\(sortKey / 10) เทอม \(sortKey % 10)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                GPAXSummaryCard(result: gpaxResult)
                if hasGPAX {
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
