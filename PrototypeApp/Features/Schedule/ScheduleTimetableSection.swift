//
//  ScheduleTimetableSection.swift
//  The CardContainer-wrapped table of a single day's periods: header row +
//  one SchedulePeriodRow/ScheduleBreakRow per entry, thin separators between
//  regular periods (break rows render full-bleed with no separator around them).
//

import SwiftUI
import SwiftData

struct ScheduleTimetableSection: View {
    let day: Int
    let periods: [ResolvedPeriod]
    let onTapEntry: (ScheduleEntry) -> Void

    var body: some View {
        CardContainer {
            VStack(spacing: 0) {
                headerRow
                ForEach(Array(periods.enumerated()), id: \.offset) { pair in
                    rowView(for: pair.element)
                    if showsDivider(after: pair.offset) {
                        Rectangle()
                            .fill(Theme.Colors.separator)
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("คาบ").frame(width: 28, alignment: .leading)
            Text("เวลา").frame(width: 40, alignment: .leading)
            Spacer()
            Text(ScheduleConstants.dayLabelsFull[day] ?? "")
                .fontWeight(.bold)
                .foregroundStyle(Theme.Colors.primary)
            Spacer()
            Text("ห้องเรียน")
        }
        .font(.caption)
        .foregroundStyle(Theme.Colors.textSecondary)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    @ViewBuilder
    private func rowView(for period: ResolvedPeriod) -> some View {
        if period.entry.subject?.isBreak == true {
            ScheduleBreakRow(period: period, onTap: { onTapEntry(period.entry) })
                .padding(.horizontal, -Theme.Spacing.lg)
        } else {
            SchedulePeriodRow(period: period, onTap: { onTapEntry(period.entry) })
        }
    }

    private func showsDivider(after index: Int) -> Bool {
        guard index < periods.count - 1 else { return false }
        let current = periods[index]
        let next = periods[index + 1]
        return current.entry.subject?.isBreak != true && next.entry.subject?.isBreak != true
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Subject.self, ScheduleEntry.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let math = Subject(name: "คณิตศาสตร์เพิ่มเติม ม.5", colorHex: "4A7DFF", iconName: "function")
    let physics = Subject(name: "ฟิสิกส์", code: "ว31201", colorHex: "4CAF50", iconName: "atom")
    let lunch = Subject(name: "พักกลางวัน", colorHex: "FFB347", iconName: "fork.knife", isBreak: true, isBuiltIn: true)
    [math, physics, lunch].forEach { container.mainContext.insert($0) }

    let entries = [
        ScheduleEntry(dayOfWeek: 1, startMinute: 480, endMinute: 530, periodNumber: 1, teacherName: "ครูณัฐวุฒิ อินทร์แก้ว", location: "5201", subjectName: math.name, subject: math),
        ScheduleEntry(dayOfWeek: 1, startMinute: 540, endMinute: 590, periodNumber: 2, teacherName: "ครูพีรพล โชคชัย", location: "5304", subjectName: physics.name, subject: physics),
        ScheduleEntry(dayOfWeek: 1, startMinute: 720, endMinute: 780, periodNumber: 0, subjectName: lunch.name, subject: lunch),
    ]
    entries.forEach { container.mainContext.insert($0) }
    let periods = PeriodShiftCalculator.apply(override: nil, to: entries)

    return ScrollView {
        ScheduleTimetableSection(day: 1, periods: periods, onTapEntry: { _ in })
            .padding()
    }
    .background(Theme.Colors.background)
    .modelContainer(container)
}
