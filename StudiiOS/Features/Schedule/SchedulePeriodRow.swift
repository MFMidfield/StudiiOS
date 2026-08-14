//
//  SchedulePeriodRow.swift
//  A single regular class period row inside ScheduleTimetableSection.
//

import SwiftUI
import SwiftData

struct SchedulePeriodRow: View {
    let period: ResolvedPeriod
    let onTap: () -> Void

    private var entry: ScheduleEntry { period.entry }
    private var subjectColor: Color { entry.subject?.color ?? Theme.Colors.textSecondary }
    private var subjectIcon: String { entry.subject?.iconName ?? "questionmark.square.dashed" }
    private var subjectDisplayName: String { entry.subject?.name ?? entry.subjectName }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("\(entry.periodNumber)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(period.startMinute.asClockString)
                    Text(period.endMinute.asClockString)
                }
                .font(.caption)
                .foregroundStyle(period.isShifted ? Theme.Colors.warning : Theme.Colors.textSecondary)

                Circle()
                    .fill(subjectColor)
                    .frame(width: 8, height: 8)

                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(subjectColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: subjectIcon)
                        .foregroundStyle(subjectColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(subjectDisplayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    if !entry.teacherName.isEmpty {
                        HStack(spacing: 4) {
                            Text(entry.teacherName)
                                .font(.caption)
                            if let code = entry.subject?.code, !code.isEmpty {
                                Text(code)
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if !entry.location.isEmpty {
                    Text(entry.location)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(subjectColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(subjectColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func handleTap() {
        AppLog.action("Schedule", "แตะคาบ \(entry.periodNumber) · \(subjectDisplayName) → เปิดฟอร์มแก้")
        onTap()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Subject.self, ScheduleEntry.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let subject = Subject(name: "ฟิสิกส์", code: "ว31201", colorHex: "4CAF50", iconName: "atom")
    container.mainContext.insert(subject)
    let entry = ScheduleEntry(
        dayOfWeek: 1, startMinute: 540, endMinute: 590, periodNumber: 2,
        teacherName: "ครูพีรพล โชคชัย", location: "5304",
        subjectName: subject.name, subject: subject
    )
    container.mainContext.insert(entry)

    let period = ResolvedPeriod(entry: entry, startMinute: entry.startMinute, endMinute: entry.endMinute, isShifted: false)
    return SchedulePeriodRow(period: period, onTap: {})
        .modelContainer(container)
}
