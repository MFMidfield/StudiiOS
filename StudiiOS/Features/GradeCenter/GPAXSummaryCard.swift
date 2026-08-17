//
//  GPAXSummaryCard.swift
//  Level 1 GPAX — the big card: GPAX now, how low and how high it can still
//  end up, and what that means for the target.
//
//  "พื้น / เพดาน" is gone: floor and ceiling are the most useful numbers on the
//  screen and they were behind two words no student uses. They are now a label
//  at each end of the bar plus one plain sentence each.
//
//  Math lives entirely in GPAXCalculator — this file only formats.
//

import SwiftUI
import SwiftData

struct GPAXSummaryCard: View {
    /// nil when the student has not set a current term yet (GPAXSettings.currentSortKey).
    let result: GPAXCalculator.Result?

    @State private var showingGradeLevelSheet = false
    @State private var showingTargetSheet = false

    /// อ่าน `revision` ใน body ข้างล่าง — นี่คือตัวที่ทำให้การ์ดสลับจาก CTA เป็นตัวเลขจริง
    /// ทันทีที่ปิด `GPAXTargetSheet` (ping แบบ @AppStorage อย่างเดียวพึ่งไม่ได้)
    @State private var gpaxStore = GPAXStore.shared

    var body: some View {
        CardContainer {
            let _ = gpaxStore.revision

            // ยังไม่ตั้งเป้า = การ์ดทั้งใบกลายเป็นคำชวนตั้งเป้า ไม่โชว์เลข GPAX เลย
            // ตัวเลข GPAX ที่ไม่มีเป้าเทียบ บอกไม่ได้ว่าต้องทำอะไรต่อ
            if !GPAXSettings.hasTarget {
                targetCallToAction
            } else if let result {
                // ตั้งเป้าแล้วแต่ยังไม่กรอกเกรดสักเทอม = โชว์ทุกอย่างตามปกติโดยใช้ 0.00
                // (16 ส.ค. 2569 — เดิมขึ้นการ์ด "ยังไม่มีข้อมูล" ทั้งใบแทน ทำให้ไม่เห็นเป้า
                // ไม่เห็นกราฟ และไม่รู้ว่าต้องไปกรอกที่ไหน)
                content(result: result, gpax: result.gpax ?? 0)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showingGradeLevelSheet) { GradeLevelSheet() }
        .sheet(isPresented: $showingTargetSheet) { GPAXTargetSheet() }
    }

    // MARK: - ยังไม่ตั้งเป้า

    private var targetCallToAction: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: "target")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryDeep)

            Text("ตั้งเป้า GPAX")
                .font(Theme.Font.plex(24, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("มีเป้าแล้วแอปถึงจะบอกได้ว่าเทอมที่เหลือต้องได้เท่าไหร่ และเป้ายังอยู่ในระยะเอื้อมไหม")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showingTargetSheet = true
            } label: {
                Text("ตั้งเป้า")
                    .font(Theme.Font.plex(17, .semibold))
                    .foregroundStyle(Theme.Colors.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.primary, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Filled state

    @ViewBuilder
    private func content(result: GPAXCalculator.Result, gpax: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            headerRow(result: result, gpax: gpax)

            if let floor = result.floor, let ceiling = result.ceiling {
                rangeBlock(floor: floor, ceiling: ceiling, gpax: gpax)
            }

            if let state = result.state {
                statusBox(state: state, gpax: gpax, result: result)
            }
        }
    }

    private func headerRow(result: GPAXCalculator.Result, gpax: Double) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("GPAX สะสม · \(provenanceLabel(result.provenance))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                // A fact, not a link. Orange is reserved for things you can tap.
                Text(GPAXCalculator.formatted(gpax))
                    .font(Theme.Font.plex(34, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: Theme.Spacing.sm)

            targetButton
        }
    }

    /// Always present, target or not — the old inline setter disappeared the
    /// moment a target existed, so there was no way back to change it.
    private var targetButton: some View {
        Button {
            showingTargetSheet = true
        } label: {
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Text("เป้า")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                HStack(spacing: Theme.Spacing.xs) {
                    Text(GPAXSettings.hasTarget
                         ? GPAXCalculator.formatted(GPAXSettings.target)
                         : "ตั้งเป้า")
                    .font(Theme.Font.plex(19, .semibold))
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.primaryDeep)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(GPAXSettings.hasTarget
                            ? "แก้เป้า GPAX ปัจจุบัน \(GPAXCalculator.formatted(GPAXSettings.target))"
                            : "ตั้งเป้า GPAX")
    }

    private func rangeBlock(floor: Double, ceiling: Double, gpax: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            GPAXRangeBar(
                floor: floor,
                ceiling: ceiling,
                gpax: gpax,
                target: GPAXSettings.hasTarget ? GPAXSettings.target : nil
            )

            HStack {
                Text(GPAXCalculator.formatted(floor))
                Spacer()
                Text(GPAXCalculator.formatted(ceiling))
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Colors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("ถ้าเลิกตั้งใจเลยจะจบที่ \(GPAXCalculator.formatted(floor))")
                Text("ถ้าได้ 4.00 ทุกเทอมที่เหลือจะจบที่ \(GPAXCalculator.formatted(ceiling))")
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func statusBox(state: GPAXCalculator.State, gpax: Double, result: GPAXCalculator.Result) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(copy(for: state, gpax: gpax))
                .font(Theme.Font.plex(13, .semibold))
                .foregroundStyle(color(for: state, gpax: gpax))
                .fixedSize(horizontal: false, vertical: true)

            if let remainingTerms = remainingTermCount(result), remainingTerms > 0 {
                Text("เหลืออีก \(remainingTerms) เทอม")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(boxBackground(for: state, gpax: gpax))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("GPAX สะสม")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("ยังไม่มีข้อมูล — เพิ่มผลการเรียนเทอมแรก")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textSecondary)

            if GPAXSettings.currentSortKey == nil {
                Button("ตั้งระดับชั้นปัจจุบัน") { showingGradeLevelSheet = true }
                    .font(Theme.Font.plex(15, .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
            } else if let firstSortKey = firstEditableSortKey {
                NavigationLink {
                    TermGradeEditView(
                        gradeLevel: firstSortKey / 10,
                        termNumber: firstSortKey % 10,
                        existingTerm: nil
                    )
                } label: {
                    Text("เพิ่มผลการเรียนเทอมแรก")
                        .font(Theme.Font.plex(15, .semibold))
                        .foregroundStyle(Theme.Colors.primaryDeep)
                }
            }
        }
    }

    /// The most recent term that is already over — the one a student with no
    /// data at all should be filling in first.
    private var firstEditableSortKey: Int? {
        guard let current = GPAXSettings.currentSortKey else { return nil }
        return GPAXCalculator.upperBandSortKeys.last { $0 < current }
    }

    // MARK: - Copy (§3.4 / §6.6)

    private func provenanceLabel(_ p: GPAXCalculator.Provenance) -> String {
        switch p {
        case .perTerm(let entered, let completed):
            return entered == completed ? "จาก \(entered) เทอม" : "จาก \(entered) จาก \(completed) เทอม"
        case .cumulative:
            return "GPAX สะสมที่กรอกไว้"
        }
    }

    private func remainingTermCount(_ result: GPAXCalculator.Result) -> Int? {
        guard let current = GPAXSettings.currentSortKey else { return nil }
        return GPAXCalculator.upperBandSortKeys.filter { $0 >= current }.count
    }

    private func copy(for state: GPAXCalculator.State, gpax: Double) -> String {
        switch state {
        case .noData:
            return "ยังไม่ได้กรอกเกรดสักเทอม — แตะเทอมที่จบแล้วในรายการด้านล่างเพื่อกรอก"
        case .achieved:
            return "ถึงเป้าแล้ว แม้ได้ 0 ทุกเทอมที่เหลือ"
        case .onTrack(let required):
            return "ต้องได้เทอมละ \(GPAXCalculator.formatted(required)) ขึ้นไป"
        case .tight(let required):
            if gpax >= 3.995 {
                return "ทำได้ดีมากแล้ว รักษาระดับนี้ไว้"
            }
            return "ต้องได้เทอมละ \(GPAXCalculator.formatted(required)) — เกือบเต็มทุกเทอม"
        case .outOfReach(let ceiling):
            return "เป้า \(GPAXCalculator.formatted(GPAXSettings.target)) เกินเอื้อมแล้ว · สูงสุดที่เป็นไปได้คือ \(GPAXCalculator.formatted(ceiling))"
        case .finished(let gpax):
            return "GPAX สุดท้าย \(GPAXCalculator.formatted(gpax))"
        }
    }

    private func color(for state: GPAXCalculator.State, gpax: Double) -> Color {
        switch state {
        case .achieved, .finished: return Theme.Colors.success
        case .onTrack: return Theme.Colors.textPrimary
        case .tight: return gpax >= 3.995 ? Theme.Colors.success : Theme.Colors.warning
        case .outOfReach: return Theme.Colors.danger
        case .noData: return Theme.Colors.textSecondary
        }
    }

    private func boxBackground(for state: GPAXCalculator.State, gpax: Double) -> Color {
        switch state {
        case .achieved, .finished: return Theme.Colors.success.opacity(0.12)
        case .outOfReach: return Theme.Colors.danger.opacity(0.12)
        default: return Theme.Colors.primarySoft
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 20) {
                GPAXSummaryCard(result: nil)
                GPAXSummaryCard(result: GPAXCalculator.calculate(
                    terms: [
                        .init(sortKey: 41, gpa: 3.15, totalCredits: 21.0),
                        .init(sortKey: 42, gpa: 3.32, totalCredits: 20.5),
                        .init(sortKey: 51, gpa: 3.41, totalCredits: 21.5),
                        .init(sortKey: 52, gpa: 3.28, totalCredits: 20.0),
                        .init(sortKey: 61, gpa: nil, totalCredits: 20.5),
                        .init(sortKey: 62, gpa: nil, totalCredits: 20.5),
                    ],
                    currentSortKey: 61,
                    target: 3.50
                ))
            }
            .padding()
        }
        .background(Theme.Colors.background)
    }
    .modelContainer(for: [Term.self, TermSubject.self, TermGradeSubject.self, ScheduleEntry.self, Subject.self], inMemory: true)
}
