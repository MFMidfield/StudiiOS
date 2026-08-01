//
//  GradeComponent.swift
//  One scored item in the Thai-style grading breakdown
//  (เก็บคะแนน / กลางภาค / ปลายภาค / ...). Powers Grade Center's total score,
//  grade computation, and "target score needed" calculator.
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

    init(
        name: String,
        maxScore: Double,
        scoreObtained: Double? = nil,
        order: Int = 0
    ) {
        self.name = name
        self.maxScore = maxScore
        self.scoreObtained = scoreObtained
        self.order = order
    }
}
