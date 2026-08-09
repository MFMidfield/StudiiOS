//
//  RIASECScorerTests.swift
//  Fixture in `workedExample` matches "claude plan/PLAN_RIASEC.md" §3.3
//  exactly — if the plan's worked example ever changes, update both together.
//

import Testing
@testable import PrototypeApp

struct RIASECScorerTests {

    // MARK: - §3.3 worked example

    private func fixtureAnswers() -> [Int: Int] {
        [
            1: 5, 2: 4, 3: 2, 4: 3, 5: 3, 6: 2, 7: 5, 8: 4, 9: 2,
            10: 3, 11: 2, 12: 3, 13: 4, 14: 4, 15: 1, 16: 3, 17: 2, 18: 3,
        ]
    }

    @Test func workedExample() {
        let profile = RIASECScorer.score(answers: fixtureAnswers())

        #expect(profile.percentages[.R] == 74)
        #expect(profile.percentages[.I] == 68)
        #expect(profile.percentages[.S] == 50)
        #expect(profile.percentages[.C] == 46)
        #expect(profile.percentages[.E] == 34)
        #expect(profile.percentages[.A] == 29)

        #expect(profile.ranked == [.R, .I, .S, .C, .E, .A])
        #expect(profile.hollandCode == "RIS")
        #expect(profile.isInconclusive == false)
        #expect(abs(profile.spread - 0.820495) < 0.001)
    }

    // MARK: - §2.2 regression guard — never delete

    @Test func allDimensionsHaveEqualTotalWeight() {
        var totalWeight: [RIASECDimension: Double] = [:]
        for dim in RIASECDimension.allCases { totalWeight[dim] = 0 }
        for item in RIASECItem.all {
            totalWeight[item.primary, default: 0] += item.primaryWeight
            totalWeight[item.secondary, default: 0] += item.secondaryWeight
        }
        for dim in RIASECDimension.allCases {
            #expect(abs(totalWeight[dim]! - 4.0) < 1e-9)
        }
    }

    // MARK: - Flat-answer profiles (acquiescence bias neutralised)

    private func flatAnswers(_ value: Int) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: RIASECItem.all.map { ($0.id, value) })
    }

    @Test func flatThrees() {
        let profile = RIASECScorer.score(answers: flatAnswers(3))
        for dim in RIASECDimension.allCases {
            #expect(abs(profile.centered[dim]!) < 1e-9)
            #expect(profile.percentages[dim] == 50)
        }
        #expect(profile.spread < 1e-9)
        #expect(profile.isInconclusive == true)
    }

    @Test func flatFives() {
        let flat3 = RIASECScorer.score(answers: flatAnswers(3))
        let flat5 = RIASECScorer.score(answers: flatAnswers(5))
        for dim in RIASECDimension.allCases {
            #expect(abs(flat5.centered[dim]!) < 1e-9)
            #expect(flat5.percentages[dim] == 50)
            #expect(flat5.rawScores[dim]! > flat3.rawScores[dim]!)
        }
        #expect(flat5.isInconclusive == true)
    }

    @Test func flatOnes() {
        let flat3 = RIASECScorer.score(answers: flatAnswers(3))
        let flat1 = RIASECScorer.score(answers: flatAnswers(1))
        for dim in RIASECDimension.allCases {
            #expect(abs(flat1.centered[dim]!) < 1e-9)
            #expect(flat1.percentages[dim] == 50)
            #expect(flat1.rawScores[dim]! < flat3.rawScores[dim]!)
        }
        #expect(flat1.isInconclusive == true)
    }

    // MARK: - Invariants

    @Test func centeredSumsToZero() {
        let fixtures: [[Int: Int]] = [
            fixtureAnswers(),
            flatAnswers(2),
            Dictionary(uniqueKeysWithValues: RIASECItem.all.map { ($0.id, ($0.id % 5) + 1) }),
        ]
        for answers in fixtures {
            let profile = RIASECScorer.score(answers: answers)
            let sum = RIASECDimension.allCases.reduce(0.0) { $0 + profile.centered[$1]! }
            #expect(abs(sum) < 1e-9)
        }
    }

    @Test func straightLiningDetected() {
        var answers: [Int: Int] = [:]
        for (index, item) in RIASECItem.all.enumerated() {
            answers[item.id] = index < 15 ? 4 : 5
        }
        let profile = RIASECScorer.score(answers: answers)
        #expect(profile.isInconclusive == true)
    }

    @Test func missingAnswerForcesInconclusive() {
        var answers = fixtureAnswers()
        answers.removeValue(forKey: 1)
        let profile = RIASECScorer.score(answers: answers)
        #expect(profile.isInconclusive == true)
    }

    @Test func deterministicTieBreak() {
        let codes = (0..<50).map { _ in RIASECScorer.score(answers: fixtureAnswers()).hollandCode }
        #expect(Set(codes).count == 1)
        #expect(codes.first == "RIS")
    }
}
