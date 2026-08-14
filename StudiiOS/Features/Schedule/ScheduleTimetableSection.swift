//
//  ScheduleTimetableSection.swift
//  The card holding one day's periods: SchedulePeriodRow / ScheduleBreakRow per
//  entry, with thin separators between regular periods (break rows run edge to
//  edge with no separator around them).
//
//  The old header row ("คาบ | เวลา | วันจันทร์ | ห้องเรียน") is gone — the day
//  picker directly above already names the day, and the column labels stopped
//  matching the columns long ago.
//

import SwiftUI
import SwiftData

struct ScheduleTimetableSection: View {
    let day: Int
    let periods: [ResolvedPeriod]
    let onTapEntry: (ScheduleEntry) -> Void

    private var isToday: Bool { day == ScheduleConstants.todayWeekday }

    var body: some View {
        // One clock for the whole card. A TimelineView per row would be eight
        // timers waking up every minute to answer the same question.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            CardContainer(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(periods.enumerated()), id: \.offset) { pair in
                        rowView(for: pair.element, now: context.date)
                        if showsDivider(after: pair.offset) {
                            Rectangle()
                                .fill(Theme.Colors.separator)
                                .frame(height: 1)
                                .padding(.horizontal, Theme.Spacing.lg)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(for period: ResolvedPeriod, now: Date) -> some View {
        if period.entry.subject?.isBreak == true {
            ScheduleBreakRow(period: period, onTap: { onTapEntry(period.entry) })
        } else {
            SchedulePeriodRow(
                period: period,
                isToday: isToday,
                now: now,
                onTap: { onTapEntry(period.entry) }
            )
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
    let math = Subject(name: "คณิตศาสตร์เพิ่มเติม ม.5", colorHex: "C96F4A", iconName: "function")
    let physics = Subject(name: "ฟิสิกส์", code: "ว31201", colorHex: "4CAF50", iconName: "atom")
    let lunch = Subject(name: "พักกลางวัน", colorHex: "FFB347", iconName: "fork.knife", isBreak: true, isBuiltIn: true)
    [math, physics, lunch].forEach { container.mainContext.insert($0) }

    let day = ScheduleConstants.todayWeekday
    let entries = [
        ScheduleEntry(dayOfWeek: day, startMinute: 480, endMinute: 530, periodNumber: 1, teacherName: "ครูณัฐวุฒิ อินทร์แก้ว", location: "5201", subjectName: math.name, subject: math),
        ScheduleEntry(dayOfWeek: day, startMinute: 540, endMinute: 590, periodNumber: 2, teacherName: "ครูพีรพล โชคชัย", location: "5304", subjectName: physics.name, subject: physics),
        ScheduleEntry(dayOfWeek: day, startMinute: 720, endMinute: 780, periodNumber: 0, subjectName: lunch.name, subject: lunch),
    ]
    entries.forEach { container.mainContext.insert($0) }
    let periods = PeriodShiftCalculator.apply(override: nil, to: entries)

    return ScrollView {
        ScheduleTimetableSection(day: day, periods: periods, onTapEntry: { _ in })
            .padding()
    }
    .background(Theme.Colors.background)
    .modelContainer(container)
}
