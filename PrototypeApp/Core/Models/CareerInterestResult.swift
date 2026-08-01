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

    init(
        takenAt: Date = .now,
        interestTags: [String],
        recommendedCareer: String,
        recommendedFaculty: String,
        recommendedSkills: [String]
    ) {
        self.takenAt = takenAt
        self.interestTags = interestTags
        self.recommendedCareer = recommendedCareer
        self.recommendedFaculty = recommendedFaculty
        self.recommendedSkills = recommendedSkills
    }
}
