//
//  RIASECQuizView.swift
//  One RIASEC item per screen, Likert 1-5. All 18 mandatory — no skip.
//  On completion, replaces itself with RIASECResultView via a @State flag
//  (not a second push) so "back" from the result returns to the hub.
//  See PLAN_RIASEC.md §6.2, §6.3, §7.2.
//

import SwiftUI
import SwiftData

struct RIASECQuizView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var answers: [Int: Int] = [:]
    @State private var completedProfile: RIASECProfile?

    private let items = RIASECItem.all

    var body: some View {
        Group {
            if let completedProfile {
                RIASECResultView(profile: completedProfile)
            } else {
                quizContent
            }
        }
        .navigationBarBackButtonHidden(completedProfile == nil)
        .toolbar {
            if completedProfile == nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button { goBack() } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }

    private var currentItem: RIASECItem { items[currentIndex] }

    private var quizContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            progressHeader
            questionText
            likertOptions
            Spacer()
        }
        .padding(Theme.Spacing.lg)
    }

    private var progressHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ProgressView(value: Double(currentIndex + 1), total: Double(items.count))
                .tint(Theme.Colors.primary)
            Text("ข้อ \(currentIndex + 1) จาก \(items.count)")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var questionText: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("คุณชอบทำสิ่งนี้แค่ไหน")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(currentItem.text)
                .font(.title3)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private var likertOptions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach((1...5).reversed(), id: \.self) { value in
                LikertButton(
                    label: RIASECItem.likertLabels[value] ?? "",
                    isSelected: answers[currentItem.id] == value
                ) {
                    select(value)
                }
            }
        }
    }

    private func select(_ value: Int) {
        answers[currentItem.id] = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            advance()
        }
    }

    private func advance() {
        if currentIndex == items.count - 1 {
            finish()
        } else {
            currentIndex += 1
        }
    }

    private func goBack() {
        if currentIndex == 0 {
            dismiss()
        } else {
            currentIndex -= 1
        }
    }

    private func finish() {
        let profile = RIASECScorer.score(answers: answers)
        let orderedAnswers = items.map { answers[$0.id] ?? 3 }
        let topFaculty = FacultyMappingTable.all[profile.ranked[0]]

        let result = CareerInterestResult(
            interestTags: profile.ranked.prefix(3).map(\.rawValue),
            recommendedCareer: profile.ranked[0].groupName,
            recommendedFaculty: (topFaculty?.faculties ?? []).joined(separator: " · "),
            recommendedSkills: topFaculty?.focusSubjects ?? [],
            scoreR: profile.percentages[.R] ?? 50,
            scoreI: profile.percentages[.I] ?? 50,
            scoreA: profile.percentages[.A] ?? 50,
            scoreS: profile.percentages[.S] ?? 50,
            scoreE: profile.percentages[.E] ?? 50,
            scoreC: profile.percentages[.C] ?? 50,
            hollandCode: profile.hollandCode,
            isInconclusive: profile.isInconclusive,
            answers: orderedAnswers
        )
        context.insert(result)
        AppLog.action("Career", "ทำแบบสำรวจ RIASEC เสร็จ — \(profile.hollandCode)")
        completedProfile = profile
    }
}

private struct LikertButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(isSelected ? Theme.Colors.primary.opacity(0.15) : Theme.Colors.surfaceRaised)
                .foregroundStyle(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}
