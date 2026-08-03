//
//  ScheduleBreakRow.swift
//  A lunch-break (or other isBreak subject) row inside ScheduleTimetableSection —
//  rendered as a distinct cream banner with no period number, room, teacher, or chevron.
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
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().strokeBorder(Theme.Colors.warning, lineWidth: 1.5))
                        .frame(width: 36, height: 36)
                    Image(systemName: entry.subject?.iconName ?? "fork.knife")
                        .foregroundStyle(Theme.Colors.warning)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(subjectName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(period.startMinute.asClockString) – \(period.endMinute.asClockString)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
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
