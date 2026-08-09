//
//  TCASScoreCard.swift
//  การ์ดสรุปคะแนนของ 1 คณะ — บนสุดของ TCASEntryDetailView, แตะเพื่อไปตั้งน้ำหนัก
//  (TCASWeightSetupView). อ่านอย่างเดียว — ไม่แก้ entry/records ตรงนี้
//

import SwiftUI

struct TCASScoreCard: View {
    let entry: TCASEntry
    let records: [TCASScoreRecord]

    private var weightInputs: [TCASWeightInput] {
        entry.weights.map {
            TCASWeightInput(examCode: $0.examCode, percent: $0.percent, groupName: $0.groupName, groupPercent: $0.groupPercent)
        }
    }

    private var scoreInputs: [TCASScoreInput] {
        records.map { TCASScoreInput(examCode: $0.examCode, score: $0.score, hasTaken: $0.hasTaken) }
    }

    private var totalPercent: Double { TCASScoreEngine.totalPercent(weights: weightInputs) }
    private var current: Double { TCASScoreEngine.currentScore(weights: weightInputs, scores: scoreInputs) }
    private var ceiling: Double { TCASScoreEngine.ceilingScore(weights: weightInputs, scores: scoreInputs) }
    private var gap: Double? { TCASScoreEngine.gap(target: entry.targetScore, weights: weightInputs, scores: scoreInputs) }
    private var topLeverage: [TCASSubjectBreakdown] {
        Array(TCASScoreEngine.leverage(weights: weightInputs, scores: scoreInputs).prefix(3))
    }
    private var lockResult: TCASRequiredAverageResult? {
        TCASScoreEngine.requiredAverage(target: entry.targetScore, weights: weightInputs, scores: scoreInputs)
    }
    private var hasAnyLocked: Bool { scoreInputs.contains { $0.hasTaken } }

    var body: some View {
        CardContainer {
            if entry.weights.isEmpty {
                emptyState
            } else {
                scoreRangeRow
                if abs(totalPercent - 100) > 0.01 {
                    warningRow
                }
                if let gap {
                    gapRow(gap)
                }
                if !topLeverage.isEmpty {
                    leverageSection
                }
                if hasAnyLocked, let lockResult {
                    lockSection(lockResult)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("ยังไม่ได้ตั้งน้ำหนักคะแนน")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("แตะที่นี่เพื่อกรอกน้ำหนัก % ของแต่ละวิชา")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private var scoreRangeRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("คะแนนรวม")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            if abs(current - ceiling) < 0.01 {
                Text(current, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            } else {
                Text("\(current.formatted(.number.precision(.fractionLength(2)))) – \(ceiling.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
    }

    private var warningRow: some View {
        Label(
            "น้ำหนักรวม \(totalPercent.formatted(.number.precision(.fractionLength(1))))% ยังไม่ครบ 100%",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(Theme.Colors.warning)
    }

    private func gapRow(_ gap: Double) -> some View {
        HStack {
            Text("ห่างจากเป้า \(entry.targetScore.formatted(.number.precision(.fractionLength(2))))")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(gap > 0 ? "อีก \(gap.formatted(.number.precision(.fractionLength(2))))" : "ถึงเป้าแล้ว")
                .font(.caption.bold())
                .foregroundStyle(gap > 0 ? Theme.Colors.info : Theme.Colors.success)
        }
    }

    private var leverageSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("คุ้มสุด 3 อันดับ")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            ForEach(topLeverage) { subject in
                HStack {
                    Text(subject.displayName)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(subject.leverage, format: .number.precision(.fractionLength(2)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func lockSection(_ result: TCASRequiredAverageResult) -> some View {
        Group {
            if result.requiredAveragePercent > 100 {
                Text("ถึงได้เต็มทุกวิชาก็ยังไม่ถึงเป้าที่ตั้งไว้ ลองปรับเป้าหมาย หรือดูคณะอันดับรองที่บันทึกไว้")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.warning)
            } else {
                Text("วิชาที่เหลือต้องได้เฉลี่ย \(result.requiredAveragePercent.formatted(.number.precision(.fractionLength(1))))%")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
    }
}
