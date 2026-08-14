//
//  TermGradeChart.swift
//  Six bars, one per ม.ปลาย term, so the three years read as a path instead of
//  a spreadsheet: solid = already entered, faint = the average still needed,
//  dashed outline = the term in progress.
//
//  Every number here comes from the GPAXCalculator.Result handed in — this file
//  formats and lays out, it never computes a grade.
//

import SwiftUI
import SwiftData

struct TermGradeChart: View {
    let result: GPAXCalculator.Result?
    let terms: [Term]
    let currentSortKey: Int?

    /// Tallest a 4.00 bar can be. Everything scales off this.
    private let plotHeight: CGFloat = 96

    private var target: Double? {
        GPAXSettings.hasTarget ? GPAXSettings.target : nil
    }

    /// The height a bar with no grade should reach. Falls back to today's GPAX
    /// so an untargeted chart still has a readable shape instead of flat zeros.
    private var projectedValue: Double? {
        result?.requiredAverage ?? result?.gpax
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            plot
            axisRow
            Text("แท่งทึบ = กรอกแล้ว · แท่งจาง = ระดับที่ต้องได้ · แท่งเส้นประ = เทอมที่กำลังเรียน")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Plot

    private var plot: some View {
        ZStack(alignment: .bottom) {
            if let target {
                targetLine(for: target)
            }
            // Gap fixed at 6: any wider and the bars drop under the 44pt
            // minimum touch target on a 402pt-wide screen.
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(GPAXCalculator.upperBandSortKeys, id: \.self) { sortKey in
                    column(for: sortKey)
                }
            }
        }
        .frame(height: plotHeight + 18)
    }

    @ViewBuilder
    private func column(for sortKey: Int) -> some View {
        let term = terms.first { $0.gradeLevel * 10 + $0.termNumber == sortKey }
        let bar = barModel(sortKey: sortKey, gpa: term?.gpa)

        if bar.isEditable {
            NavigationLink {
                TermGradeEditView(
                    gradeLevel: sortKey / 10,
                    termNumber: sortKey % 10,
                    existingTerm: term
                )
            } label: {
                barBody(bar)
            }
            .buttonStyle(PressScaleButtonStyle())
        } else {
            barBody(bar)
        }
    }

    private func barBody(_ bar: BarModel) -> some View {
        VStack(spacing: 2) {
            Text(bar.label)
                .font(Theme.Font.plex(11, bar.isSolid ? .semibold : .regular))
                .foregroundStyle(bar.isSolid ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            shape(for: bar)
                .frame(height: max(4, plotHeight * bar.fraction))
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bar.accessibilityLabel)
    }

    @ViewBuilder
    private func shape(for bar: BarModel) -> some View {
        // Radius.icon is the smallest rounding token there is. A dedicated
        // ~6pt "bar" token would suit better, but DesignSystem is read-only
        // for this module — reported instead of added.
        let rect = RoundedRectangle(cornerRadius: Theme.Radius.icon, style: .continuous)
        switch bar.kind {
        case .entered:
            rect.fill(Theme.Colors.primary)
        case .current:
            // A dashed outline rather than diagonal hatching: hatching needs a
            // custom Shape and reads as noise at 46pt wide.
            rect.fill(Theme.Colors.primary.opacity(0.12))
                .overlay(
                    rect.strokeBorder(
                        Theme.Colors.primary,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                    )
                )
        case .future:
            rect.fill(Theme.Colors.primarySoft)
        }
    }

    private func targetLine(for target: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("เป้า \(GPAXCalculator.formatted(target))")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.primaryDeep)
            Rectangle()
                .fill(Theme.Colors.primaryDeep.opacity(0.45))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .offset(y: -plotHeight * CGFloat(min(1, target / 4.0)))
    }

    private var axisRow: some View {
        HStack(spacing: 6) {
            ForEach(GPAXCalculator.upperBandSortKeys, id: \.self) { sortKey in
                let isCurrent = sortKey == currentSortKey
                Text("\(sortKey / 10)/\(sortKey % 10)")
                    .font(Theme.Font.plex(11, isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Theme.Colors.primaryDeep : Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Bar model

    private enum BarKind { case entered, current, future }

    private struct BarModel {
        let kind: BarKind
        let fraction: CGFloat
        let label: String
        let isEditable: Bool
        let accessibilityLabel: String

        var isSolid: Bool { kind == .entered }
    }

    private func barModel(sortKey: Int, gpa: Double?) -> BarModel {
        let name = "ม.\(sortKey / 10) เทอม \(sortKey % 10)"

        if let gpa {
            return BarModel(
                kind: .entered,
                fraction: CGFloat(min(1, gpa / 4.0)),
                label: GPAXCalculator.formatted(gpa),
                isEditable: true,
                accessibilityLabel: "\(name) เกรด \(GPAXCalculator.formatted(gpa)) แตะเพื่อแก้"
            )
        }

        // No grade yet. A slot already behind the current term is still
        // editable — that is exactly the "ยังไม่ได้กรอก" case.
        let isPast = currentSortKey.map { sortKey < $0 } ?? false
        let isCurrent = sortKey == currentSortKey
        let projected = projectedValue

        return BarModel(
            kind: isCurrent ? .current : .future,
            fraction: CGFloat(min(1, (projected ?? 0) / 4.0)),
            label: labelFor(isCurrent: isCurrent, isPast: isPast, projected: projected),
            isEditable: isPast,
            accessibilityLabel: accessibilityFor(name: name, isCurrent: isCurrent, isPast: isPast, projected: projected)
        )
    }

    private func labelFor(isCurrent: Bool, isPast: Bool, projected: Double?) -> String {
        if isCurrent { return "กำลัง" }
        if isPast { return "เพิ่ม" }
        guard result?.requiredAverage != nil, let projected else { return "—" }
        return GPAXCalculator.formatted(projected)
    }

    private func accessibilityFor(name: String, isCurrent: Bool, isPast: Bool, projected: Double?) -> String {
        if isCurrent { return "\(name) กำลังเรียนอยู่ ยังกรอกเกรดไม่ได้" }
        if isPast { return "\(name) ยังไม่ได้กรอกเกรด แตะเพื่อกรอก" }
        guard result?.requiredAverage != nil, let projected else { return "\(name) ยังไม่ถึง" }
        return "\(name) ต้องได้ \(GPAXCalculator.formatted(projected))"
    }
}

#Preview {
    NavigationStack {
        CardContainer {
            TermGradeChart(
                result: GPAXCalculator.calculate(
                    terms: [
                        .init(sortKey: 41, gpa: 3.15, totalCredits: 21.0),
                        .init(sortKey: 42, gpa: 3.32, totalCredits: 20.5),
                    ],
                    currentSortKey: 51,
                    target: 3.50
                ),
                terms: [],
                currentSortKey: 51
            )
        }
        .padding()
    }
    .background(Theme.Colors.background)
    .modelContainer(for: [Term.self, TermSubject.self, TermGradeSubject.self, ScheduleEntry.self, Subject.self], inMemory: true)
}
