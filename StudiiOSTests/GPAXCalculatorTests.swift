//
//  GPAXCalculatorTests.swift
//  Fixture in each test matches "claude plan/PLAN_GPA.md" §3.3 exactly —
//  if the plan's worked example ever changes, update both together.
//

import Testing
@testable import StudiiOS

struct GPAXCalculatorTests {

    /// §3.3: student in ม.6 เทอม 1, target 3.50. ม.6 terms carry no gpa yet
    /// but already have their credit load known (20.5 each), which is what
    /// makes remainingCredits come out to 41.0 instead of the 40.0 default.
    private func fixtureTerms() -> [GPAXCalculator.TermInput] {
        [
            .init(sortKey: 41, gpa: 3.15, totalCredits: 21.0),
            .init(sortKey: 42, gpa: 3.32, totalCredits: 20.5),
            .init(sortKey: 51, gpa: 3.41, totalCredits: 21.5),
            .init(sortKey: 52, gpa: 3.28, totalCredits: 20.0),
            .init(sortKey: 61, gpa: nil, totalCredits: 20.5),
            .init(sortKey: 62, gpa: nil, totalCredits: 20.5),
        ]
    }

    // MARK: - §3.3 worked example

    @Test func worksExampleMatchesPlanFixture() {
        let result = GPAXCalculator.calculate(
            terms: fixtureTerms(),
            currentSortKey: 61,
            target: 3.50
        )

        #expect(result.completedCredits == 83.0)
        #expect(GPAXCalculator.rounded(result.earnedPoints) == 273.13) // 273.125 display-rounded
        #expect(GPAXCalculator.rounded(result.gpax!) == 3.29)
        #expect(result.remainingCredits == 41.0)
        #expect(result.totalCredits == 124.0)
        #expect(GPAXCalculator.rounded(result.requiredAverage!) == 3.92)
        #expect(GPAXCalculator.rounded(result.ceiling!) == 3.53)
        #expect(GPAXCalculator.rounded(result.floor!) == 2.20)

        guard case .tight = result.state else {
            Issue.record("expected .tight, got \(String(describing: result.state))")
            return
        }
    }

    @Test func provenanceCountsOnlyEnteredTerms() {
        var terms = fixtureTerms()
        terms[1] = .init(sortKey: 42, gpa: nil, totalCredits: 20.5) // completed but not entered

        let result = GPAXCalculator.calculate(terms: terms, currentSortKey: 61, target: nil)

        guard case .perTerm(let entered, let completed) = result.provenance else {
            Issue.record("expected .perTerm provenance")
            return
        }
        #expect(entered == 3)
        #expect(completed == 4)
    }

    // MARK: - Six GPAXResult states

    @Test func noDataWhenNothingEntered() {
        let result = GPAXCalculator.calculate(terms: [], currentSortKey: 41, target: 3.50)
        #expect(result.state == .noData)
    }

    @Test func achievedWhenRequiredIsZeroOrBelow() {
        let terms = [GPAXCalculator.TermInput(sortKey: 41, gpa: 4.0, totalCredits: 20.0)]
        let result = GPAXCalculator.calculate(terms: terms, currentSortKey: 42, target: 3.0)
        #expect(result.state == .achieved)
    }

    @Test func onTrackWhenRequiredIsModerate() {
        let terms = [GPAXCalculator.TermInput(sortKey: 41, gpa: 3.0, totalCredits: 20.0)]
        let result = GPAXCalculator.calculate(terms: terms, currentSortKey: 42, target: 3.2)
        guard case .onTrack(let required) = result.state else {
            Issue.record("expected .onTrack, got \(String(describing: result.state))")
            return
        }
        #expect(required > 0 && required <= 3.5)
    }

    @Test func tightWhenRequiredIsAboveThreePointFive() {
        // Covered end-to-end by worksExampleMatchesPlanFixture (required 3.92).
        let terms = fixtureTerms()
        let result = GPAXCalculator.calculate(terms: terms, currentSortKey: 61, target: 3.50)
        guard case .tight(let required) = result.state else {
            Issue.record("expected .tight, got \(String(describing: result.state))")
            return
        }
        #expect(required > 3.5 && required <= 4.0)
    }

    @Test func outOfReachWhenRequiredExceedsFour() {
        let terms = [GPAXCalculator.TermInput(sortKey: 41, gpa: 2.0, totalCredits: 20.0)]
        let result = GPAXCalculator.calculate(terms: terms, currentSortKey: 62, target: 3.9)
        guard case .outOfReach = result.state else {
            Issue.record("expected .outOfReach, got \(String(describing: result.state))")
            return
        }
    }

    @Test func finishedWhenNoTermsRemain() {
        let terms = GPAXCalculator.upperBandSortKeys.map {
            GPAXCalculator.TermInput(sortKey: $0, gpa: 3.5, totalCredits: 20.0)
        }
        let result = GPAXCalculator.calculate(terms: terms, currentSortKey: 63, target: 3.5)
        guard case .finished(let gpax) = result.state else {
            Issue.record("expected .finished, got \(String(describing: result.state))")
            return
        }
        #expect(GPAXCalculator.rounded(gpax) == 3.50)
    }

    @Test func stateIsNilWhenDataExistsButNoTargetSet() {
        let terms = [GPAXCalculator.TermInput(sortKey: 41, gpa: 3.0, totalCredits: 20.0)]
        let result = GPAXCalculator.calculate(terms: terms, currentSortKey: 42, target: nil)
        #expect(result.state == nil)
        #expect(result.requiredAverage == nil)
        #expect(result.gpax != nil) // GPAX itself still shows without a target
    }

    // MARK: - Cumulative mode (D3)

    @Test func cumulativeReproducesSameGPAXAsPerTermEntry() {
        let perTerm = GPAXCalculator.calculate(terms: fixtureTerms(), currentSortKey: 61, target: nil)

        let cumulative = GPAXCalculator.calculate(
            terms: [],
            currentSortKey: 61,
            target: nil,
            cumulative: GPAXCalculator.CumulativeOverride(
                gpax: perTerm.gpax!,
                credits: perTerm.completedCredits
            )
        )

        #expect(GPAXCalculator.rounded(cumulative.gpax!) == GPAXCalculator.rounded(perTerm.gpax!))
        #expect(cumulative.provenance == .cumulative)
    }

    // MARK: - Rounding (§3.5)

    @Test func roundingIsHalfUpAtTwoDecimals() {
        #expect(GPAXCalculator.rounded(3.925) == 3.93)
        #expect(GPAXCalculator.rounded(3.924) == 3.92)
    }
}
