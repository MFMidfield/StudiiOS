//
//  GPAXCalculator.swift
//  Pure GPAX math — no SwiftUI, no SwiftData. Views format; only this file computes.
//  Derivation and the §3.3 worked example live in "claude plan/PLAN_GPA.md" §3.
//
//  D7 (read at the call site too): this takes `currentSortKey` from
//  GPAXSettings, the student's REAL term — never TermStore.activeTermKey,
//  which is only the term the user happens to be browsing.
//

import Foundation

enum GPAXCalculator {

    /// One term's grade data. A lightweight copy of what `Term.gpa` /
    /// `Term.totalCredits` hold, so this file never needs SwiftData to be tested.
    struct TermInput {
        let sortKey: Int
        let gpa: Double?
        let totalCredits: Double?

        init(sortKey: Int, gpa: Double?, totalCredits: Double?) {
            self.sortKey = sortKey
            self.gpa = gpa
            self.totalCredits = totalCredits
        }
    }

    /// Cumulative-mode override (D3): replaces every completed term's
    /// contribution with one remembered GPAX + credit total.
    struct CumulativeOverride {
        let gpax: Double
        let credits: Double

        init(gpax: Double, credits: Double) {
            self.gpax = gpax
            self.credits = credits
        }
    }

    enum Provenance: Equatable {
        case perTerm(entered: Int, completed: Int)
        case cumulative
    }

    enum State: Equatable {
        case noData
        case achieved
        case onTrack(required: Double)
        case tight(required: Double)
        case outOfReach(ceiling: Double)
        case finished(gpax: Double)
    }

    struct Result {
        let gpax: Double?
        let completedCredits: Double
        let earnedPoints: Double
        let remainingCredits: Double
        let totalCredits: Double
        let floor: Double?
        let ceiling: Double?
        /// nil when `target` is nil — a target-independent GPAX/term-list
        /// still renders, the required-average line just stays hidden.
        let requiredAverage: Double?
        /// nil only when there is data and a remaining term, but no target
        /// has been set yet — none of the six named states apply.
        let state: State?
        let provenance: Provenance
    }

    /// D2: substituted whenever a term's own `totalCredits` is nil.
    static let defaultTermCredits = 20.0

    /// ม.4 เทอม1 ... ม.6 เทอม2, chronological — matches `Term.sortKey`.
    static let upperBandSortKeys = [41, 42, 51, 52, 61, 62]

    static func calculate(
        terms: [TermInput],
        currentSortKey: Int,
        target: Double?,
        cumulative: CumulativeOverride? = nil
    ) -> Result {
        let upperTerms = terms.filter { upperBandSortKeys.contains($0.sortKey) }
        let completedTerms = upperTerms.filter { $0.sortKey < currentSortKey }
        let remainingSlots = upperBandSortKeys.filter { $0 >= currentSortKey }

        let completedCredits: Double
        let earnedPoints: Double
        let provenance: Provenance

        if let cumulative {
            completedCredits = cumulative.credits
            earnedPoints = cumulative.gpax * cumulative.credits
            provenance = .cumulative
        } else {
            // Only terms with a gpa entered count — a completed slot with no
            // data is skipped, not assumed 0. Provenance still reports how
            // many completed slots exist so the UI can say "จาก 2 จาก 4 เทอม".
            let entered = completedTerms.filter { $0.gpa != nil }
            completedCredits = entered.reduce(0) { $0 + ($1.totalCredits ?? defaultTermCredits) }
            earnedPoints = entered.reduce(0) { $0 + ($1.gpa! * ($1.totalCredits ?? defaultTermCredits)) }
            provenance = .perTerm(entered: entered.count, completed: completedTerms.count)
        }

        let remainingCredits = remainingSlots.reduce(0.0) { total, sortKey in
            let override = upperTerms.first { $0.sortKey == sortKey }?.totalCredits
            return total + (override ?? defaultTermCredits)
        }

        let totalCredits = completedCredits + remainingCredits
        let gpax = completedCredits > 0 ? earnedPoints / completedCredits : nil
        let floor = totalCredits > 0 ? earnedPoints / totalCredits : nil
        let ceiling = totalCredits > 0 ? (earnedPoints + 4.0 * remainingCredits) / totalCredits : nil

        let requiredAverage: Double?
        if let target, remainingCredits > 0 {
            requiredAverage = (target * totalCredits - earnedPoints) / remainingCredits
        } else {
            requiredAverage = nil
        }

        let state: State?
        if completedCredits == 0 {
            state = .noData
        } else if remainingCredits <= 0 {
            state = .finished(gpax: gpax ?? 0)
        } else if let requiredAverage {
            if requiredAverage <= 0 {
                state = .achieved
            } else if requiredAverage <= 3.5 {
                state = .onTrack(required: requiredAverage)
            } else if requiredAverage <= 4.0 {
                state = .tight(required: requiredAverage)
            } else {
                state = .outOfReach(ceiling: ceiling ?? 0)
            }
        } else {
            state = nil
        }

        return Result(
            gpax: gpax,
            completedCredits: completedCredits,
            earnedPoints: earnedPoints,
            remainingCredits: remainingCredits,
            totalCredits: totalCredits,
            floor: floor,
            ceiling: ceiling,
            requiredAverage: requiredAverage,
            state: state,
            provenance: provenance
        )
    }

    /// Display-time rounding only (§3.5). Never round intermediate values —
    /// call this on the final number, not on anything fed back into `calculate`.
    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded(.toNearestOrAwayFromZero) / 100
    }

    /// "3.29" — the only place views should turn a GPAX number into a string.
    static func formatted(_ value: Double) -> String {
        String(format: "%.2f", rounded(value))
    }
}
