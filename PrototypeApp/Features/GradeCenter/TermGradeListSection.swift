//
//  TermGradeListSection.swift
//  Level 1 GPAX — always exactly 6 rows for ม.ปลาย (ม.4–ม.6), in sortKey order.
//  Read-only in this round: rows are not tappable yet. Editing lands in
//  TermGradeEditSheet (build order step 4).
//

import SwiftUI

struct TermGradeListSection: View {
    /// Same result GPAXSummaryCard shows — passed down so this section never
    /// re-derives requiredAverage itself.
    let result: GPAXCalculator.Result?
    let terms: [Term]

    private var rows: [(sortKey: Int, term: Term?)] {
        GPAXCalculator.upperBandSortKeys.map { sortKey in
            (sortKey, terms.first { $0.gradeLevel * 10 + $0.termNumber == sortKey })
        }
    }

    var body: some View {
        CardContainer {
            Text("ผลการเรียนรายเทอม · ม.ปลาย")
                .font(.subheadline).fontWeight(.semibold)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    TermGradeRow(
                        sortKey: row.sortKey,
                        term: row.term,
                        currentSortKey: GPAXSettings.currentSortKey,
                        requiredAverage: result?.requiredAverage
                    )
                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct TermGradeRow: View {
    let sortKey: Int
    let term: Term?
    let currentSortKey: Int?
    let requiredAverage: Double?

    @State private var showingEditSheet = false

    private var displayName: String { "ม.\(sortKey / 10) เทอม \(sortKey % 10)" }
    private var gradeLevel: Int { sortKey / 10 }
    private var termNumber: Int { sortKey % 10 }

    /// Only past/current rows open the edit sheet (§6.2) — future rows are
    /// informational only, so there is nothing to enter there yet.
    private var isEditable: Bool {
        guard let current = currentSortKey else { return false }
        return sortKey <= current
    }

    var body: some View {
        Button {
            showingEditSheet = true
        } label: {
            HStack {
                Text(displayName)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                trailing
            }
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
        .sheet(isPresented: $showingEditSheet) {
            TermGradeEditSheet(gradeLevel: gradeLevel, termNumber: termNumber, existingTerm: term)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let gpa = term?.gpa {
            HStack(spacing: 4) {
                Text(GPAXCalculator.formatted(gpa))
                if let credits = term?.totalCredits {
                    Text("· \(String(format: "%.1f", credits)) นก.")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.Colors.textSecondary)
        } else if let current = currentSortKey, sortKey == current {
            Text("กำลังเรียน")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.primary)
        } else if let current = currentSortKey, sortKey < current {
            Text("เพิ่ม")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Colors.primary)
        } else if let current = currentSortKey, sortKey > current, let required = requiredAverage {
            Text("ต้องได้ \(GPAXCalculator.formatted(required))")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
        } else {
            Text("ยังไม่มีข้อมูล")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
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
