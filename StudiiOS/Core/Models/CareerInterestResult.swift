//
//  CareerInterestResult.swift
//  Stores a completed Career Discovery quiz result: interest tags picked
//  and the resulting recommendation, so the user can revisit past results.
//

import Foundation
import SwiftData

@Model
final class CareerInterestResult {
    var takenAt: Date
    var interestTags: [String]
    var recommendedCareer: String
    var recommendedFaculty: String
    var recommendedSkills: [String]

    // MARK: - RIASEC v2 (additive — see PLAN_RIASEC.md §4)
    var scoreR: Int = 50
    var scoreI: Int = 50
    var scoreA: Int = 50
    var scoreS: Int = 50
    var scoreE: Int = 50
    var scoreC: Int = 50
    var hollandCode: String = ""
    var isInconclusive: Bool = false
    /// 18 Likert answers in item-id order, so a future scoring change can
    /// re-score historical results without asking the student to retake.
    var answers: [Int] = []

    init(
        takenAt: Date = .now,
        interestTags: [String],
        recommendedCareer: String,
        recommendedFaculty: String,
        recommendedSkills: [String],
        scoreR: Int = 50,
        scoreI: Int = 50,
        scoreA: Int = 50,
        scoreS: Int = 50,
        scoreE: Int = 50,
        scoreC: Int = 50,
        hollandCode: String = "",
        isInconclusive: Bool = false,
        answers: [Int] = []
    ) {
        self.takenAt = takenAt
        self.interestTags = interestTags
        self.recommendedCareer = recommendedCareer
        self.recommendedFaculty = recommendedFaculty
        self.recommendedSkills = recommendedSkills
        self.scoreR = scoreR
        self.scoreI = scoreI
        self.scoreA = scoreA
        self.scoreS = scoreS
        self.scoreE = scoreE
        self.scoreC = scoreC
        self.hollandCode = hollandCode
        self.isInconclusive = isInconclusive
        self.answers = answers
    }

    /// Reconstructs the `RIASECProfile` shape needed by `RIASECResultView`
    /// from the stored per-dimension scores, without re-running the scorer.
    var riasecScores: [RIASECDimension: Int] {
        [.R: scoreR, .I: scoreI, .A: scoreA, .S: scoreS, .E: scoreE, .C: scoreC]
    }
}
