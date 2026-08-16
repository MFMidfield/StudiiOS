//
//  GPAXDashboardCard.swift
//  One-line Dashboard summary of Level 1 GPAX, routing to .gradeCenter.
//  Own file per PLAN_GPA §8 risk: DashboardView.swift is 350 lines already —
//  never inline a card's body straight into DashboardView.body.
//
//  Renders nothing (EmptyView) until the student has both set a current term
//  (GradeLevelSheet) and entered at least one term's GPA — same "hides
//  cleanly without data" rule GPAXSummaryCard follows in GradeCenterView.
//

import SwiftUI
import SwiftData

struct GPAXDashboardCard: View {
    @Query private var terms: [Term]

    /// ตัวจริงที่ทำให้การ์ดนี้อัปเดตเมื่อเป้า/เทอมเปลี่ยน — อ่าน `revision` ใน body (ดู `GPAXStore`)
    @State private var gpaxStore = GPAXStore.shared

    // ping แบบ @AppStorage ของเดิม — เก็บไว้เป็นตาข่ายกันพลาด แต่พึ่งอย่างเดียวไม่ได้
    @AppStorage(GPAXSettings.Key.currentGradeLevel) private var gpaxGradeLevelPing = 0
    @AppStorage(GPAXSettings.Key.currentTermNumber) private var gpaxTermNumberPing = 0
    @AppStorage(GPAXSettings.Key.target) private var gpaxTargetPing = 0.0
    @AppStorage(GPAXSettings.Key.entryMode) private var gpaxEntryModePing = ""
    @AppStorage(GPAXSettings.Key.priorGPAX) private var gpaxPriorGPAXPing = 0.0
    @AppStorage(GPAXSettings.Key.priorCredits) private var gpaxPriorCreditsPing = 0.0
    @AppStorage(GPAXSettings.Key.priorTermCount) private var gpaxPriorTermCountPing = 0

    private var result: GPAXCalculator.Result? {
        guard let currentSortKey = GPAXSettings.currentSortKey else { return nil }
        let termInputs = GPAXCalculator.upperBandSortKeys.map { sortKey -> GPAXCalculator.TermInput in
            let match = terms.first { $0.gradeLevel * 10 + $0.termNumber == sortKey }
            return GPAXCalculator.TermInput(sortKey: sortKey, gpa: match?.gpa, totalCredits: match?.totalCredits)
        }
        return GPAXCalculator.calculate(
            terms: termInputs,
            currentSortKey: currentSortKey,
            target: GPAXSettings.hasTarget ? GPAXSettings.target : nil,
            cumulative: GPAXSettings.cumulativeOverride
        )
    }

    var body: some View {
        let _ = gpaxStore.revision
        if let result, let gpax = result.gpax {
            NavigationLink(value: DashboardDestination.gradeCenter) {
                CardContainer(padding: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        IconTile(systemName: "chart.bar", size: 34)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("GPAX สะสม")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(GPAXCalculator.formatted(gpax))
                                .font(Theme.Font.number(20))
                                .contentTransition(.numericText())
                                .animation(.snappy, value: gpax)
                                .foregroundStyle(Theme.Colors.primaryDeep)
                        }

                        Spacer(minLength: Theme.Spacing.sm)

                        if let required = result.requiredAverage {
                            PillLabel(
                                "เทอมละ \(GPAXCalculator.formatted(required))",
                                tone: requiredTone(for: result.state)
                            )
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    if GPAXSettings.hasTarget {
                        GPAXTargetBar(gpax: gpax, target: GPAXSettings.target)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func requiredTone(for state: GPAXCalculator.State?) -> PillLabel.Tone {
        switch state {
        case .outOfReach: return .danger
        case .tight: return .warning
        case .achieved, .finished:
            return .custom(foreground: Theme.Colors.success, background: Theme.Colors.success.opacity(0.14))
        default: return .neutral
        }
    }
}

/// Progress toward the GPAX target, with the target spelled out on the right so
/// the bar isn't the only thing carrying the number.
private struct GPAXTargetBar: View {
    let gpax: Double
    let target: Double

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, max(0, gpax / target))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.surfaceRaised)
                    Capsule()
                        .fill(Theme.Colors.primary)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 5)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

            HStack {
                Spacer()
                Text("เป้า \(GPAXCalculator.formatted(target))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            GPAXDashboardCard()
        }
        .padding()
    }
    .modelContainer(for: [Term.self, TermSubject.self], inMemory: true)
}
