//
//  TermGradeListSection.swift
//  Level 1 GPAX — the six ม.ปลาย terms as a chart plus a list, in sortKey order.
//
//  Two changes carry most of the weight here: a chevron appears only on rows
//  that actually open something (the old list looked uniformly tappable and
//  wasn't), and the closing line explains WHY the term in progress can't be
//  filled in — that rule is correct, it was just never stated.
//

import SwiftUI
import SwiftData

struct TermGradeListSection: View {
    /// Same result GPAXSummaryCard shows — passed down so this section never
    /// re-derives requiredAverage itself.
    let result: GPAXCalculator.Result?
    let terms: [Term]

    private var currentSortKey: Int? { GPAXSettings.currentSortKey }

    private var rows: [(sortKey: Int, term: Term?)] {
        GPAXCalculator.upperBandSortKeys.map { sortKey in
            (sortKey, terms.first { $0.gradeLevel * 10 + $0.termNumber == sortKey })
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            CardContainer {
                Text("ผลการเรียนรายเทอม · ม.ปลาย")
                    .font(Theme.Font.plex(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TermGradeChart(result: result, terms: terms, currentSortKey: currentSortKey)
            }

            // 16 ส.ค. 2569: แต่ละเทอมเป็นการ์ดของตัวเอง (เดิมเป็น 6 แถวคั่น Divider
            // ในการ์ดใบเดียวกับกราฟ ซึ่งอ่านเป็นตารางมากกว่าเป็นของที่กดได้)
            ForEach(rows, id: \.sortKey) { row in
                TermGradeRow(
                    sortKey: row.sortKey,
                    term: row.term,
                    currentSortKey: currentSortKey,
                    requiredAverage: result?.requiredAverage
                )
            }

            Text("กดลูกศรที่ตั้งค่าเพื่อกรอกเกรดเทอมนี้")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TermGradeRow: View {
    let sortKey: Int
    let term: Term?
    let currentSortKey: Int?
    let requiredAverage: Double?

    private var displayName: String { "ม.\(sortKey / 10) เทอม \(sortKey % 10)" }
    private var gradeLevel: Int { sortKey / 10 }
    private var termNumber: Int { sortKey % 10 }

    private var isCurrent: Bool { sortKey == currentSortKey }
    private var isFuture: Bool { currentSortKey.map { sortKey > $0 } ?? false }

    /// Only terms that are already over can be edited. The term in progress is
    /// deliberately excluded: GPAXCalculator counts `sortKey < currentSortKey`
    /// as completed, so a grade entered for the current term is silently
    /// dropped from every GPAX number. It becomes editable once Few advances
    /// the real term with the up-arrow button in Settings.
    private var isEditable: Bool {
        guard let current = currentSortKey else { return false }
        return sortKey < current
    }

    var body: some View {
        if isEditable {
            NavigationLink {
                TermGradeEditView(gradeLevel: gradeLevel, termNumber: termNumber, existingTerm: term)
            } label: {
                rowLabel
            }
            .buttonStyle(.plain)
        } else {
            rowLabel
        }
    }

    private var rowLabel: some View {
        CardContainer(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(displayName)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 76, alignment: .leading)

                meter

                Spacer(minLength: Theme.Spacing.xs)

                trailing

                // The one honest signal of "this opens something".
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .opacity(isEditable ? 1 : 0)
            }
        }
        // เทอมปัจจุบันเน้นด้วยขอบสีหลัก (พื้นเทาแบบเดิมใช้ไม่ได้แล้ว — การ์ดมีพื้นของตัวเอง)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.Colors.primary, lineWidth: isCurrent ? 1.5 : 0)
        )
        .opacity(isFuture ? 0.55 : 1)
        .contentShape(Rectangle())
    }

    /// Same scale as the chart above — filled with the real grade, or washed in
    /// with the average this term still has to hit.
    private var meter: some View {
        // เทอมที่ยังไม่กรอก = 0 (แถบว่าง) — ของเดิมเติมแถบด้วยค่าที่ "ต้องได้"
        // ทำให้ดูเหมือนกรอกไปแล้ว (16 ส.ค. 2569)
        let fraction = CGFloat(min(1, max(0, (term?.gpa ?? 0) / 4.0)))

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.separator.opacity(0.6))
                Capsule()
                    .fill(term?.gpa != nil ? Theme.Colors.primary : Theme.Colors.primarySoft)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .frame(maxWidth: 90)
    }

    @ViewBuilder
    private var trailing: some View {
        if let gpa = term?.gpa {
            // เกรดอย่างเดียว — หน่วยกิตถูกเอาออก 16 ส.ค. 2569 (ยังกรอก/ใช้คิด GPAX
            // เหมือนเดิม แค่ไม่โชว์ในแถวนี้)
            Text(GPAXCalculator.formatted(gpa))
                .font(Theme.Font.plex(13, .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
        } else if isCurrent {
            // Neutral, not orange: orange means "tappable" everywhere else and
            // this row is the one row that isn't.
            PillLabel("เรียนอยู่")
        } else if isEditable {
            Text("เพิ่ม")
                .font(Theme.Font.plex(13, .medium))
                .foregroundStyle(Theme.Colors.primaryDeep)
        } else if isFuture, let required = requiredAverage {
            Text("ต้องได้ \(GPAXCalculator.formatted(required))")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
        } else {
            Text("ยังไม่มีข้อมูล")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            TermGradeListSection(
                result: GPAXCalculator.calculate(
                    terms: [
                        .init(sortKey: 41, gpa: 3.15, totalCredits: 21.0),
                        .init(sortKey: 42, gpa: 3.32, totalCredits: 20.5),
                    ],
                    currentSortKey: 51,
                    target: 3.5
                ),
                terms: []
            )
            .padding()
        }
        .background(Theme.Colors.background)
    }
    .modelContainer(for: [Term.self, TermSubject.self, TermGradeSubject.self, ScheduleEntry.self, Subject.self], inMemory: true)
}
