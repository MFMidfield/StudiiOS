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

    // Same reactivity-ping pattern as GradeCenterView — see the comment there
    // for why plain GPAXSettings getters alone don't trigger a SwiftUI redraw.
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
        if let result, let gpax = result.gpax {
            NavigationLink(value: DashboardDestination.gradeCenter) {
                CardContainer {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GPAX สะสม")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(GPAXCalculator.formatted(gpax))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Theme.Colors.primaryDeep)
                        }
                        Spacer()
                        if let required = result.requiredAverage {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("ต้องได้เทอมละ")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                Text(GPAXCalculator.formatted(required))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(requiredColor(for: result.state))
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func requiredColor(for state: GPAXCalculator.State?) -> Color {
        switch state {
        case .outOfReach: return Theme.Colors.danger
        case .tight: return Theme.Colors.warning
        case .achieved, .finished: return Theme.Colors.success
        default: return Theme.Colors.textPrimary
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
