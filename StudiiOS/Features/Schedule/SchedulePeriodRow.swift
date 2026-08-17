//
//  SchedulePeriodRow.swift
//  A single regular class period row inside ScheduleTimetableSection.
//
//  Four blocks only: time · subject icon · name and details · room. The subject
//  colour appears once (on the icon) instead of four times — the old row spent
//  so much width on repeated colour that long subject names were cut off.
//
//  `now` is handed down from ScheduleTimetableSection's single TimelineView
//  rather than each row keeping its own clock.
//

import SwiftUI
import SwiftData

struct SchedulePeriodRow: View {
    let period: ResolvedPeriod
    /// Only true on the real weekday being viewed — browsing Friday on a
    /// Tuesday must never light a row up as "กำลังเรียน".
    var isToday: Bool = false
    var now: Date = .now
    let onTap: () -> Void

    private var entry: ScheduleEntry { period.entry }
    private var subjectColor: Color { entry.subject?.color ?? Theme.Colors.textSecondary }
    private var subjectIcon: String { entry.subject?.iconName ?? "questionmark.square.dashed" }
    private var subjectDisplayName: String { entry.subject?.name ?? entry.subjectName }

    var body: some View {
        Button(action: handleTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if isLive { liveHeader }
                mainRow
                if isLive { progressBar }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(isLive ? Theme.Colors.primarySoft : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Blocks

    private var mainRow: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(period.startMinute.asClockString)
                Text(period.endMinute.asClockString)
            }
            .font(Theme.Font.caption)
            .foregroundStyle(timeColor)
            .frame(width: 34, alignment: .leading)

            IconTile(systemName: subjectIcon, size: 32, color: subjectColor)

            VStack(alignment: .leading, spacing: 2) {
                // Two lines allowed: a name cut mid-word is worse than a row
                // that grows by 16pt.
                Text(subjectDisplayName)
                    .font(Theme.Font.plex(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !detailLine.isEmpty {
                    Text(detailLine)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Theme.Spacing.xs)

            if !entry.location.isEmpty {
                PillLabel(entry.location)
            }
        }
    }

    private var liveHeader: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(Theme.Colors.primary)
                .frame(width: 5, height: 5)
            Text("กำลังเรียน · เหลือ \(minutesRemaining) นาที")
                .font(Theme.Font.plex(11, .semibold))
                .foregroundStyle(Theme.Colors.primaryDeep)
                .contentTransition(.numericText())
        }
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.Colors.primary.opacity(0.2))
            GeometryReader { geometry in
                Capsule()
                    .fill(Theme.Colors.primary)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 3)
        .animation(.snappy, value: progress)
    }

    // MARK: - Derived

    /// "คาบ 2 · ครูพีรพล · ว31201" — empty parts drop out with their separator.
    private var detailLine: String {
        var parts: [String] = []
        if entry.periodNumber > 0 { parts.append("คาบ \(entry.periodNumber)") }
        if !entry.teacherName.isEmpty { parts.append(entry.teacherName) }
        if let code = entry.subject?.code, !code.isEmpty { parts.append(code) }
        return parts.joined(separator: " · ")
    }

    private var nowMinute: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private var isLive: Bool {
        isToday && nowMinute >= period.startMinute && nowMinute < period.endMinute
    }

    /// Rounded up so the last 30 seconds read "เหลือ 1 นาที", never "เหลือ 0".
    private var minutesRemaining: Int {
        max(1, period.endMinute - nowMinute)
    }

    private var progress: Double {
        let length = period.endMinute - period.startMinute
        guard length > 0 else { return 0 }
        return min(1, max(0, Double(nowMinute - period.startMinute) / Double(length)))
    }

    private var timeColor: Color {
        if isLive { return Theme.Colors.primaryDeep }
        return period.isShifted ? Theme.Colors.warning : Theme.Colors.textSecondary
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
    let midway = Calendar.current.date(bySettingHour: 9, minute: 20, second: 0, of: .now) ?? .now

    return VStack(spacing: 0) {
        SchedulePeriodRow(period: period, onTap: {})
        SchedulePeriodRow(period: period, isToday: true, now: midway, onTap: {})
    }
    .background(Theme.Colors.cardBackground)
    .modelContainer(container)
}
