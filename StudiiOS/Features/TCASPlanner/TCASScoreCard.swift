//
//  TCASScoreCard.swift
//  การ์ดคะแนนรวมของ 1 คณะ — บนสุดของ TCASEntryDetailView
//  อ่านอย่างเดียว ยกเว้นปุ่มดินสอที่เปิด TCASTargetSheet ให้ตั้งเป้า
//
//  เดิมการ์ดใบเดียวอัด 5 ก้อน (ช่วงคะแนน · คำเตือนน้ำหนัก · ห่างจากเป้า · leverage ·
//  โหมดล็อก) — leverage ย้ายไป TCASLeverageCard · "ห่างจากเป้า" ย้ายไปอยู่ในลิสต์คณะ
//

import SwiftUI

struct TCASScoreCard: View {
    let entry: TCASEntry
    let records: [TCASScoreRecord]
    let onEditTarget: () -> Void

    @State private var isLockExpanded = false

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
    private var lockResult: TCASRequiredAverageResult? {
        TCASScoreEngine.requiredAverage(target: entry.targetScore, weights: weightInputs, scores: scoreInputs)
    }
    private var hasAnyLocked: Bool { scoreInputs.contains { $0.hasTaken } }

    var body: some View {
        CardContainer {
            if entry.weights.isEmpty {
                emptyState
            } else {
                headerRow
                TCASScoreBar(
                    current: current,
                    ceiling: ceiling,
                    target: entry.targetScore,
                    reachedTarget: (gap ?? 1) <= 0
                )
                legend
                if abs(totalPercent - 100) > 0.01 {
                    warningRow
                }
                if hasAnyLocked, let lockResult {
                    lockBox(lockResult)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("ยังไม่ได้ตั้งน้ำหนักคะแนน")
                .font(Theme.Font.plex(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("กรอกน้ำหนัก % ของแต่ละวิชาที่แถว \"น้ำหนักวิชา\" ข้างล่าง แล้วคะแนนจะขึ้นที่นี่")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - หัวการ์ด

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("คะแนนรวมตอนนี้")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    // §4.2: เลขคะแนนใช้ textPrimary — สีส้มสงวนไว้ให้ของที่กดได้
                    Text(current, format: .number.precision(.fractionLength(1)))
                        .font(Theme.Font.number(28))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text("เต็มที่ได้ถึง \(ceiling.formatted(.number.precision(.fractionLength(1))))")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            targetButton
        }
    }

    private var targetButton: some View {
        Button(action: onEditTarget) {
            VStack(alignment: .trailing, spacing: 2) {
                Text("เป้า")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                HStack(spacing: Theme.Spacing.xs) {
                    Text(entry.targetScore > 0
                         ? entry.targetScore.formatted(.number.precision(.fractionLength(0)))
                         : "ตั้งเป้า")
                        .font(Theme.Font.plex(15, .semibold))
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.primaryDeep)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var legend: some View {
        Text("แถบเข้ม = ที่ได้แล้ว · แถบอ่อน = ที่ยังไม่สอบ · ขีดตั้ง = เป้า")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    private var warningRow: some View {
        Label(
            "น้ำหนักรวม \(totalPercent.formatted(.number.precision(.fractionLength(1))))% ยังไม่ครบ 100%",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(Theme.Font.label)
        .foregroundStyle(Theme.Colors.warning)
    }

    // MARK: - โหมดล็อก "สอบไปแล้ว" (§4.3)
    //
    // แผนเดิมบังคับว่าต้องแสดง "ที่มาของตัวเลข" ครบทุกบรรทัด ไม่ใช่โยนผลลัพธ์
    // บรรทัดเดียวให้เดาเอง — จึงพับไว้ด้วย DisclosureGroup แทนที่จะตัดทิ้ง
    // ข้อสรุปกับบรรทัดย่ออยู่บนหัว แตะแล้วเห็นครบ 4 บรรทัดเดิม

    private func lockBox(_ result: TCASRequiredAverageResult) -> some View {
        DisclosureGroup(isExpanded: $isLockExpanded) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                lockLine("ล็อกแล้ว (\(result.lockedExamCodes.joined(separator: " + ")))",
                         value: result.lockedContribution.formatted(.number.precision(.fractionLength(2))))
                lockLine("เป้าหมาย",
                         value: entry.targetScore.formatted(.number.precision(.fractionLength(2))))
                lockLine("ที่เหลือต้องช่วยอีก",
                         value: result.neededFromRemaining.formatted(.number.precision(.fractionLength(2))))
                lockLine("น้ำหนักรวมที่ยังไม่สอบ",
                         value: "\(result.remainingPercent.formatted(.number.precision(.fractionLength(0))))%")
            }
            .padding(.top, Theme.Spacing.sm)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                lockConclusion(result)
                Text("ล็อกแล้ว \(result.lockedContribution.formatted(.number.precision(.fractionLength(2)))) · เหลือน้ำหนัก \(result.remainingPercent.formatted(.number.precision(.fractionLength(0))))%")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .tint(Theme.Colors.primaryDeep)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Colors.primarySoft)
        )
    }

    private func lockLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.Font.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    @ViewBuilder
    private func lockConclusion(_ result: TCASRequiredAverageResult) -> some View {
        if result.requiredAveragePercent > 100 {
            // §4.3: ห้ามแสดงเป็นตัวแดงว่า "เป็นไปไม่ได้" — ใช้ warning + ทางออกที่ทำต่อได้
            Text("ถึงได้เต็มทุกวิชาก็ยังไม่ถึงเป้าที่ตั้งไว้ ลองปรับเป้าหมาย หรือดูคณะอันดับรองที่บันทึกไว้")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.warning)
        } else {
            Text("ต้องได้เฉลี่ย \(result.requiredAveragePercent.formatted(.number.precision(.fractionLength(1))))% ในวิชาที่เหลือ")
                .font(Theme.Font.plex(14, .semibold))
                .foregroundStyle(Theme.Colors.primaryDeep)
        }
    }
}
