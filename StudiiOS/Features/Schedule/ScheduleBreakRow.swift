//
//  ScheduleBreakRow.swift
//  A lunch-break (or other isBreak subject) row inside ScheduleTimetableSection —
//  a full-bleed cream band with no period number, room, teacher, or chevron.
//
//  The band itself already says "this is not a class", so the row carries no
//  icon and no bold text: a break that shouts louder than the periods around it
//  is reading the timetable backwards.
//

import SwiftUI
import SwiftData

struct ScheduleBreakRow: View {
    let period: ResolvedPeriod
    let onTap: () -> Void

    private var entry: ScheduleEntry { period.entry }
    private var subjectName: String { entry.subject?.name ?? entry.subjectName }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                // Same column width as SchedulePeriodRow so the times line up
                // straight down the card.
                VStack(alignment: .leading, spacing: 2) {
                    Text(period.startMinute.asClockString)
                    Text(period.endMinute.asClockString)
                }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 34, alignment: .leading)

                Text(subjectName)
                    .font(Theme.Font.plex(13, .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.breakBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Subject.self, ScheduleEntry.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let subject = Subject(name: "พักกลางวัน", colorHex: "FFB347", iconName: "fork.knife", isBreak: true, isBuiltIn: true)
    container.mainContext.insert(subject)
    let entry = ScheduleEntry(
        dayOfWeek: 1, startMinute: 720, endMinute: 780, periodNumber: 0,
        subjectName: subject.name, subject: subject
    )
    container.mainContext.insert(entry)

    let period = ResolvedPeriod(entry: entry, startMinute: entry.startMinute, endMinute: entry.endMinute, isShifted: false)
    return ScheduleBreakRow(period: period, onTap: {})
        .modelContainer(container)
}
