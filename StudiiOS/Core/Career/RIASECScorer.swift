//
//  RIASECScorer.swift
//  Pure scoring for the 18-item RIASEC inventory. See PLAN_RIASEC.md §3 for
//  the full derivation — this corrects four bugs found in the original
//  research report (unequal dimension weights, wrong inconclusive
//  threshold, wrong percentage formula, non-deterministic tie-break).
//
//  No SwiftUI/SwiftData import on purpose: this stays a plain function so
//  RIASECScorerTests can run without a ModelContainer.
//

import Foundation

struct RIASECProfile {
    let percentages: [RIASECDimension: Int]   // 10...95, for display only
    let centered: [RIASECDimension: Double]   // ranking source of truth
    let rawScores: [RIASECDimension: Double]  // tie-break source
    let ranked: [RIASECDimension]             // 6 entries, best first, deterministic
    let hollandCode: String                   // e.g. "RIS" — first 3 of `ranked`
    let isInconclusive: Bool
    let isBorderline: Bool
    let spread: Double                        // the SD, exposed for debugging/tests
}

enum RIASECScorer {
    /// `answers` is `[itemID: likertValue]`. Missing keys are treated as 3
    /// (neutral) but also force `isInconclusive = true` — the caller
    /// guarantees all 18 are present in normal use (the quiz has no skip
    /// button), this is only a safety net against a malformed call.
    static func score(answers: [Int: Int]) -> RIASECProfile {
        let items = RIASECItem.all
        let dimensions = RIASECDimension.allCases

        var raw = Dictionary(uniqueKeysWithValues: dimensions.map { ($0, 0.0) })
        var totalWeight = Dictionary(uniqueKeysWithValues: dimensions.map { ($0, 0.0) })
        var answeredCount = 0
        var valueCounts: [Int: Int] = [:]

        for item in items {
            let value: Int
            if let provided = answers[item.id] {
                value = provided
                answeredCount += 1
            } else {
                value = 3
            }
            valueCounts[value, default: 0] += 1

            raw[item.primary, default: 0] += Double(value) * item.primaryWeight
            raw[item.secondary, default: 0] += Double(value) * item.secondaryWeight
            totalWeight[item.primary, default: 0] += item.primaryWeight
            totalWeight[item.secondary, default: 0] += item.secondaryWeight
        }

        var norm: [RIASECDimension: Double] = [:]
        for dim in dimensions {
            norm[dim] = raw[dim]! / totalWeight[dim]!
        }

        let mean = dimensions.reduce(0.0) { $0 + norm[$1]! } / Double(dimensions.count)

        var centered: [RIASECDimension: Double] = [:]
        for dim in dimensions {
            centered[dim] = norm[dim]! - mean
        }

        let meanSquare = dimensions.reduce(0.0) { $0 + centered[$1]! * centered[$1]! } / Double(dimensions.count)
        let sd = meanSquare.squareRoot()

        let modeCount = valueCounts.values.max() ?? 0
        let isInconclusive = sd < 0.30 || answeredCount < items.count || modeCount >= 15

        var percentages: [RIASECDimension: Int] = [:]
        for dim in dimensions {
            let displayValue = 50 + 20 * centered[dim]!
            percentages[dim] = min(95, max(10, Int(displayValue.rounded())))
        }

        let ranked = dimensions.sorted { a, b in
            let centeredA = centered[a]!, centeredB = centered[b]!
            if centeredA != centeredB { return centeredA > centeredB }
            let rawA = raw[a]!, rawB = raw[b]!
            if rawA != rawB { return rawA > rawB }
            return dimensions.firstIndex(of: a)! < dimensions.firstIndex(of: b)!
        }

        let isBorderline = !isInconclusive && (percentages[ranked[0]]! - percentages[ranked[2]]! < 8)
        let hollandCode = ranked.prefix(3).map(\.rawValue).joined()

        return RIASECProfile(
            percentages: percentages,
            centered: centered,
            rawScores: raw,
            ranked: ranked,
            hollandCode: hollandCode,
            isInconclusive: isInconclusive,
            isBorderline: isBorderline,
            spread: sd
        )
    }
}
