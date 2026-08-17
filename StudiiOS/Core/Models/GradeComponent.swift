//
//  GradeComponent.swift
//  One scored item in the Thai-style grading breakdown
//  (เก็บคะแนน / กลางภาค / ปลายภาค / ...).
//  Kept only for SwiftData store compatibility — the UI that used this model
//  (คะแนนรวม / ตัวคำนวณเป้า) was removed, see PLAN_2026-08-10_Fixes.md Task 4.
//

import Foundation
import SwiftData

@Model
final class GradeComponent {
    var name: String
    var maxScore: Double
    /// nil means not graded yet — used by the "what score do I need" calculator.
    var scoreObtained: Double?
    var order: Int
    var term: Term?

    init(
        name: String,
        maxScore: Double,
        scoreObtained: Double? = nil,
        order: Int = 0,
        term: Term? = nil
    ) {
        self.name = name
        self.maxScore = maxScore
        self.scoreObtained = scoreObtained
        self.order = order
        self.term = term
    }
}
