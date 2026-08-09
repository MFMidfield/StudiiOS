//
//  GPAXSummaryCard.swift
//  Level 1 GPAX — the big card: GPAX, floor/ceiling range bar, required average.
//  Read-only in this round; input lands in TermGradeEditView/GradeLevelSheet.
//  Math lives entirely in GPAXCalculator — this file only formats.
//

import SwiftUI

struct GPAXSummaryCard: View {
    /// nil when the student has not set a current term yet (GPAXSettings.currentSortKey).
    let result: GPAXCalculator.Result?

    @State private var showingGradeLevelSheet = false

    var body: some View {
        CardContainer {
            if let result, let gpax = result.gpax {
                content(result: result, gpax: gpax)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showingGradeLevelSheet) {
            GradeLevelSheet()
        }
    }

    @ViewBuilder
    private func content(result: GPAXCalculator.Result, gpax: Double) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("GPAX สะสม · \(provenanceLabel(result.provenance))")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Text(GPAXCalculator.formatted(gpax))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.Colors.primary)

            if let floor = result.floor, let ceiling = result.ceiling {
                GPAXRangeBar(
                    floor: floor,
                    ceiling: ceiling,
                    gpax: gpax,
                    target: GPAXSettings.hasTarget ? GPAXSettings.target : nil
                )
                Text(rangeLabel(floor: floor, ceiling: ceiling))
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if let state = result.state {
                Text(copy(for: state, gpax: gpax))
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(color(for: state, gpax: gpax))
                    .padding(.top, Theme.Spacing.xs)
            } else {
                // Data exists but no target yet (§7 edge case) — offer one inline.
                // The full target editor belongs in Settings (build order step 6);
                // this is just enough to unblock verifying the §3.3 fixture now.
                TargetQuickSetter()
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("GPAX สะสม")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("ยังไม่มีข้อมูล — เพิ่มผลการเรียนเทอมแรก")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)

            if GPAXSettings.currentSortKey == nil {
                Button("ตั้งระดับชั้นปัจจุบัน") { showingGradeLevelSheet = true }
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.primary)
            }
        }
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

    private func rangeLabel(floor: Double, ceiling: Double) -> String {
        var text = "พื้น \(GPAXCalculator.formatted(floor)) · เพดาน \(GPAXCalculator.formatted(ceiling))"
        if GPAXSettings.hasTarget {
            text += " · เป้า \(GPAXCalculator.formatted(GPAXSettings.target))"
        }
        return text
    }

    private func copy(for state: GPAXCalculator.State, gpax: Double) -> String {
        switch state {
        case .noData:
            return "ยังไม่มีข้อมูล — เพิ่มผลการเรียนเทอมแรก"
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
}

/// Minimal target entry — Settings (step 6) gets the real editor with source
/// programme text (§4.2 targetSource); this just writes GPAXSettings.target.
private struct TargetQuickSetter: View {
    @State private var text = ""

    private var parsed: Double? { Double(text) }
    private var isValid: Bool { parsed.map { (0.0...4.0).contains($0) } ?? false }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("ตั้งเป้า GPAX เช่น 3.50", text: $text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
            Button("ตั้งเป้า") {
                guard let value = parsed else { return }
                GPAXSettings.setTarget(value, source: "")
                text = ""
            }
            .disabled(!isValid)
            .font(.subheadline).fontWeight(.semibold)
        }
    }
}

/// x = (value − floor) / (ceiling − floor), clamped 0...1. Shows where the
/// current GPAX sits between the mathematical floor and ceiling, with the
/// target as a tick mark on the same scale.
private struct GPAXRangeBar: View {
    let floor: Double
    let ceiling: Double
    let gpax: Double
    let target: Double?

    private func fraction(_ value: Double) -> CGFloat {
        guard ceiling > floor else { return 0 }
        return CGFloat(min(max((value - floor) / (ceiling - floor), 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.separator)
                Capsule()
                    .fill(Theme.Colors.primary)
                    .frame(width: geo.size.width * fraction(gpax))
                if let target {
                    Rectangle()
                        .fill(Theme.Colors.textPrimary)
                        .frame(width: 2)
                        .offset(x: geo.size.width * fraction(target) - 1)
                }
            }
        }
        .frame(height: 8)
    }
}

#Preview {
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
}
