//
//  TCASEntryCard.swift
//  การ์ดคณะ 1 ใบในลิสต์ของ TCASPlannerView — ทั้งโมดูลมีอยู่เพื่อ "เทียบหลายคณะ"
//  ลิสต์จึงต้องบอกคะแนนตั้งแต่หน้าแรก ไม่ใช่ให้กดเข้าไปดูทีละคณะ (06_TCAS §4.1)
//  อ่านอย่างเดียว — ทุกตัวเลขมาจาก TCASScoreEngine ไม่มีการเขียนกลับ
//

import SwiftUI

/// แถบคะแนน 3 ชั้นในแท่งเดียว สเกล 0–100 — ใช้ทั้งในลิสต์คณะและในหน้ารายละเอียด
/// ชั้นเข้ม = ที่ล็อกแล้ว · ชั้นอ่อน = ส่วนที่ยังไม่สอบ (ถึงเพดาน) · ขีดตั้ง = เป้า
struct TCASScoreBar: View {
    let current: Double
    let ceiling: Double
    /// 0 = ไม่ได้ตั้งเป้า → ไม่วาดขีด
    let target: Double
    let reachedTarget: Bool

    private func fraction(_ value: Double) -> CGFloat {
        CGFloat(min(max(value / 100, 0), 1))
    }

    // สีตามสถานะ: ถึงเป้าแล้วเป็น success ยังไม่ถึงเป็น primary
    // §4.1 ห้ามใช้แดงกับคณะที่คะแนนยังน้อย — ยังไม่สอบไม่ใช่ความล้มเหลว
    private var strongFill: Color {
        reachedTarget ? Theme.Colors.success : Theme.Colors.primary
    }

    // สเปคเขียนว่าใช้ `primarySoft` แต่โทเคนนั้นแทบแยกไม่ออกจากรางแถบ
    // (`separator`) ทั้งสองโหมด — §7 ข้อ 12 บังคับว่าสองชั้นต้องแยกออกจากกัน
    // จึงใช้สีเดียวกับชั้นเข้มที่ opacity ต่ำแทน สว่าง/มืดได้เหมือนกัน
    private var softFill: Color {
        strongFill.opacity(0.3)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.separator)
                Capsule()
                    .fill(softFill)
                    .frame(width: geo.size.width * fraction(ceiling))
                Capsule()
                    .fill(strongFill)
                    .frame(width: geo.size.width * fraction(current))
                if target > 0 {
                    // สูงกว่าแถบเพื่อให้อ่านเป็น "หมุดบนสเกล" ไม่ใช่ช่วงหนึ่งของแถบ
                    Capsule()
                        .fill(Theme.Colors.textPrimary)
                        .frame(width: 2, height: 14)
                        .offset(x: geo.size.width * fraction(target) - 1)
                }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

struct TCASEntryCard: View {
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

    private var current: Double { TCASScoreEngine.currentScore(weights: weightInputs, scores: scoreInputs) }
    private var ceiling: Double { TCASScoreEngine.ceilingScore(weights: weightInputs, scores: scoreInputs) }
    private var totalPercent: Double { TCASScoreEngine.totalPercent(weights: weightInputs) }
    private var gap: Double? {
        TCASScoreEngine.gap(target: entry.targetScore, weights: weightInputs, scores: scoreInputs)
    }
    private var isWeightIncomplete: Bool { abs(totalPercent - 100) > 0.01 }

    var body: some View {
        if entry.weights.isEmpty {
            unweightedCard
        } else {
            CardContainer(padding: Theme.Spacing.md) {
                titleRow
                subtitleRow
                TCASScoreBar(
                    current: current,
                    ceiling: ceiling,
                    target: entry.targetScore,
                    reachedTarget: (gap ?? 1) <= 0
                )
                footerRow
            }
        }
    }

    // MARK: - แถวย่อย

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.facultyName)
                .font(Theme.Font.plex(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.sm)
            Text(current, format: .number.precision(.fractionLength(1)))
                .font(Theme.Font.number(19))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
        }
    }

    private var subtitleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(entry.universityName) · \(entry.roundRaw)")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.sm)
            Text("เพดาน \(ceiling.formatted(.number.precision(.fractionLength(1))))")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    @ViewBuilder
    private var footerRow: some View {
        if gap != nil || isWeightIncomplete {
            HStack {
                if let gap {
                    Text(targetText(gap))
                        .font(Theme.Font.caption)
                        .foregroundStyle(gap > 0 ? Theme.Colors.textSecondary : Theme.Colors.success)
                }
                Spacer(minLength: Theme.Spacing.sm)
                if isWeightIncomplete {
                    PillLabel(
                        "น้ำหนัก \(totalPercent.formatted(.number.precision(.fractionLength(0))))%",
                        tone: .warning
                    )
                }
            }
        }
    }

    private func targetText(_ gap: Double) -> String {
        let target = entry.targetScore.formatted(.number.precision(.fractionLength(0)))
        guard gap > 0 else { return "เป้า \(target) · ถึงเป้าแล้ว" }
        return "เป้า \(target) · อีก \(gap.formatted(.number.precision(.fractionLength(1))))"
    }

    // MARK: - คณะที่ยังไม่ตั้งน้ำหนัก
    //
    // เส้นประบอกว่า "ยังไม่พร้อมคำนวณ" โดยไม่ต้องใช้สีเตือน — คณะที่เพิ่งเพิ่ม
    // เข้ามายังไม่ผิดอะไร แค่ยังไม่ได้กรอกน้ำหนัก

    private var unweightedCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.facultyName)
                    .font(Theme.Font.plex(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.sm)
                PillLabel("ยังไม่ตั้งน้ำหนัก", tone: .neutral)
            }
            Text("\(entry.universityName) · \(entry.roundRaw)")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(
                    Theme.Colors.separator,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
    }
}
