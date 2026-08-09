//
//  GradeCenterView.swift
//  Grade Center: total score, Thai grade computation, and "score needed on
//  remaining exams to hit a target grade" calculator, per Thai school
//  grading conventions (0–4 grade points on a 100-point scale).
//

import SwiftUI
import SwiftData

struct GradeCenterView: View {
    @Query(sort: \GradeComponent.order) private var allComponents: [GradeComponent]
    @State private var targetGrade: Double = 3.0

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    private var components: [GradeComponent] { allComponents.inTerm(activeTerm) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                GradeBreakdownCard(components: components, term: activeTerm)
                TargetScoreCalculatorCard(components: components, targetGrade: $targetGrade)
            }
            .padding()
        }
        .navigationTitle(activeTerm.map { "เกรด & GPA · \($0.displayName)" } ?? "เกรด & GPA")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GradeBreakdownCard: View {
    let components: [GradeComponent]
    let term: Term?
    @Environment(\.modelContext) private var context
    @State private var newComponentName = ""
    @State private var newMaxScore = ""

    private var totalMax: Double { components.reduce(0) { $0 + $1.maxScore } }
    private var totalObtained: Double { components.compactMap(\.scoreObtained).reduce(0, +) }
    private var percent: Double { totalMax > 0 ? (totalObtained / totalMax) * 100 : 0 }

    var body: some View {
        CardContainer {
            Text("คะแนนรวม").font(.subheadline).fontWeight(.semibold)

            ForEach(components) { component in
                GradeComponentRow(component: component)
            }
            .onDelete { offsets in
                for i in offsets { context.delete(components[i]) }
            }

            HStack {
                TextField("รายการ เช่น กลางภาค", text: $newComponentName)
                TextField("คะแนนเต็ม", text: $newMaxScore)
                    .keyboardType(.numberPad)
                    .frame(width: 70)
                Button("เพิ่ม") { addComponent() }
                    .disabled(newComponentName.isEmpty || Double(newMaxScore) == nil)
            }
            .font(.caption)

            Divider()

            HStack {
                Text("รวม: \(totalObtained.formatted()) / \(totalMax.formatted())")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(percent, specifier: "%.1f")%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
            }
            HStack {
                Text("เกรด")
                Spacer()
                Text(ThaiGrading.gradeLabel(forPercent: percent))
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.success)
            }
        }
    }

    private func addComponent() {
        guard let max = Double(newMaxScore) else { return }
        let order = components.count
        context.insert(GradeComponent(name: newComponentName, maxScore: max, order: order, term: term))
        newComponentName = ""; newMaxScore = ""
    }
}

private struct GradeComponentRow: View {
    @Bindable var component: GradeComponent
    @State private var scoreText: String = ""

    var body: some View {
        HStack {
            Text(component.name).font(.system(size: 13))
            Spacer()
            TextField("คะแนน", text: $scoreText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
                .onAppear { scoreText = component.scoreObtained.map { String($0) } ?? "" }
                .onChange(of: scoreText) { component.scoreObtained = Double(scoreText) }
            Text("/ \(component.maxScore.formatted())")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TargetScoreCalculatorCard: View {
    let components: [GradeComponent]
    @Binding var targetGrade: Double

    private var gradedComponents: [GradeComponent] { components.filter { $0.scoreObtained != nil } }
    private var ungradedComponents: [GradeComponent] { components.filter { $0.scoreObtained == nil } }
    private var totalMax: Double { components.reduce(0) { $0 + $1.maxScore } }
    private var obtainedSoFar: Double { gradedComponents.compactMap(\.scoreObtained).reduce(0, +) }
    private var ungradedMaxSum: Double { ungradedComponents.reduce(0) { $0 + $1.maxScore } }

    private var requiredPercentOnRemaining: Double? {
        guard totalMax > 0, ungradedMaxSum > 0 else { return nil }
        let neededPercent = ThaiGrading.minPercent(forGrade: targetGrade)
        let neededTotalPoints = totalMax * neededPercent / 100
        let neededOnRemaining = neededTotalPoints - obtainedSoFar
        return (neededOnRemaining / ungradedMaxSum) * 100
    }

    var body: some View {
        CardContainer {
            Text("คำนวณคะแนนที่ต้องทำเพื่อให้ได้เกรดเป้าหมาย")
                .font(.subheadline).fontWeight(.semibold)

            Picker("เกรดเป้าหมาย", selection: $targetGrade) {
                ForEach(ThaiGrading.grades, id: \.self) { g in
                    Text(String(format: "%.1f", g)).tag(g)
                }
            }
            .pickerStyle(.segmented)

            if ungradedComponents.isEmpty {
                EmptyRow(text: "ไม่มีรายการที่รอผลคะแนน")
            } else if let required = requiredPercentOnRemaining {
                if required > 100 {
                    Text("เป็นไปไม่ได้แล้วสำหรับเกรดนี้ด้วยคะแนนที่เหลือ")
                        .font(.caption).foregroundStyle(Theme.Colors.danger)
                } else if required < 0 {
                    Text("คุณได้เกรดนี้แน่นอนแล้ว 🎉")
                        .font(.caption).foregroundStyle(Theme.Colors.success)
                } else {
                    Text("ต้องทำได้ \(required, specifier: "%.1f")% ในส่วนที่เหลือ (\(ungradedComponents.map(\.name).joined(separator: ", ")))")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
    }
}

/// Thai school grading scale helpers (0–4 grade points on 100-point base).
enum ThaiGrading {
    static let grades: [Double] = [4.0, 3.5, 3.0, 2.5, 2.0, 1.5, 1.0, 0.0]

    static func minPercent(forGrade grade: Double) -> Double {
        switch grade {
        case 4.0: return 80
        case 3.5: return 75
        case 3.0: return 70
        case 2.5: return 65
        case 2.0: return 60
        case 1.5: return 55
        case 1.0: return 50
        default: return 0
        }
    }

    static func gradeLabel(forPercent percent: Double) -> String {
        let grade = grades.first { percent >= minPercent(forGrade: $0) } ?? 0
        return String(format: "%.1f", grade)
    }
}

#Preview {
    NavigationStack { GradeCenterView() }
        .modelContainer(for: [GradeComponent.self, Term.self, TermSubject.self], inMemory: true)
}
