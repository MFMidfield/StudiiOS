//
//  TCASLeverageCard.swift
//  "ดันวิชาไหนคุ้มสุด" — แยกออกจาก TCASScoreCard เพราะการ์ดเดียวเคยอัด 5 ก้อน
//
//  §4.2 ของแผนเดิมบังคับว่าต้องเห็น "ความคุ้ม" (leverage) คู่กับ "ดันได้อีก"
//  (headroom) พร้อมกันเสมอ ไม่งั้นผู้ใช้จะไปทุ่มกับวิชาที่คุ้มแต่สอบไปแล้ว
//  → แถบ = leverage (เทียบกับตัวสูงสุด) · ตัวเลข = headroom · ห้ามตัดอย่างใดอย่างหนึ่งทิ้ง
//  เลข leverage ดิบ (0.375) ถูกถอดออกเพราะนักเรียนแปลไม่ออก แต่ข้อมูลยังอยู่ครบในความยาวแถบ
//

import SwiftUI

struct TCASLeverageCard: View {
    let entry: TCASEntry
    let records: [TCASScoreRecord]

    private var weightInputs: [TCASWeightInput] {
        entry.weights.map {
            TCASWeightInput(
                examCode: $0.examCode,
                percent: $0.percent,
                groupName: $0.groupName,
                groupPercent: $0.groupPercent
            )
        }
    }

    private var scoreInputs: [TCASScoreInput] {
        records.map { TCASScoreInput(examCode: $0.examCode, score: $0.score, hasTaken: $0.hasTaken) }
    }

    private var topSubjects: [TCASSubjectBreakdown] {
        Array(TCASScoreEngine.leverage(weights: weightInputs, scores: scoreInputs).prefix(3))
    }

    /// normalize ความยาวแถบเทียบวิชาที่คุ้มที่สุด — 0 ถ้าไม่มีอะไรให้เทียบ
    private var maxLeverage: Double {
        topSubjects.map(\.leverage).max() ?? 0
    }

    var body: some View {
        if !topSubjects.isEmpty {
            CardContainer {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ดันวิชาไหนคุ้มสุด")
                        .font(Theme.Font.plex(15, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("ถ้าได้เต็มในวิชานั้น คะแนนรวมจะเพิ่มเท่าไร")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                ForEach(topSubjects) { subject in
                    row(subject)
                }
            }
        }
    }

    private func row(_ subject: TCASSubjectBreakdown) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(subject.displayName)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            leverageBar(subject)
                .frame(width: 64)

            Text(trailingText(subject))
                .font(Theme.Font.plex(12, .medium))
                .monospacedDigit()
                .foregroundStyle(subject.hasTaken ? Theme.Colors.textSecondary : Theme.Colors.primaryDeep)
                .frame(width: 58, alignment: .trailing)
        }
        // วิชาที่สอบไปแล้วดันไม่ได้อีก — จางลงแต่ไม่ซ่อน ผู้ใช้ต้องเห็นว่ามันอยู่ในลิสต์
        .opacity(subject.hasTaken ? 0.5 : 1)
    }

    private func leverageBar(_ subject: TCASSubjectBreakdown) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.separator)
                if !subject.hasTaken, maxLeverage > 0 {
                    Capsule()
                        .fill(Theme.Colors.primary)
                        .frame(width: geo.size.width * CGFloat(subject.leverage / maxLeverage))
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private func trailingText(_ subject: TCASSubjectBreakdown) -> String {
        guard !subject.hasTaken else { return "สอบแล้ว" }
        return "+\(subject.headroom.formatted(.number.precision(.fractionLength(1))))"
    }
}
