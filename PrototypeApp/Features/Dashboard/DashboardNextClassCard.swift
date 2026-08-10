//
//  DashboardNextClassCard.swift
//  Dashboard hero card: today's current/next class period, live. Reuses
//  PeriodShiftCalculator so a shortened day (DayScheduleOverride) reflects
//  here exactly like it does in ScheduleView — never a second time formula.
//  Own file per the same "keep DashboardView.body small" rule as
//  GPAXDashboardCard (see that file's header comment).
//

import SwiftUI
import SwiftData

struct DashboardNextClassCard: View {
    @Query private var allEntries: [ScheduleEntry]
    @Query private var overrides: [DayScheduleOverride]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    private var today: Date { .now }

    private var todayWeekday: Int {
        let raw = Calendar.current.component(.weekday, from: today) // 1=Sun...7=Sat
        return raw == 1 ? 7 : raw - 1 // 1=Mon...7=Sun
    }

    private var matchingOverride: DayScheduleOverride? {
        let normalized = DayScheduleOverride.normalizedDate(today)
        return overrides.first { $0.date == normalized }
    }

    private var resolvedPeriods: [ResolvedPeriod] {
        let todaysEntries = allEntries
            .inTerm(activeTerm)
            .filter { $0.dayOfWeek == todayWeekday && !($0.subject?.isBreak ?? false) }
        return PeriodShiftCalculator.apply(override: matchingOverride, to: todaysEntries)
            .sorted { $0.startMinute < $1.startMinute }
    }

    var body: some View {
        CardContainer {
            if !ScheduleConstants.visibleDays.contains(todayWeekday) {
                weekendState
            } else if resolvedPeriods.isEmpty {
                emptyState
            } else {
                TimelineView(.periodic(from: today, by: 60)) { context in
                    classContent(now: context.date)
                }
            }
        }
    }

    // MARK: - States

    private var weekendState: some View {
        HStack(spacing: Theme.Spacing.md) {
            iconBadge(systemName: "cup.and.saucer.fill", color: Theme.Colors.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("วันหยุดสุดสัปดาห์")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("พักผ่อนได้เต็มที่ ไม่มีคาบเรียนวันนี้")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        HStack(spacing: Theme.Spacing.md) {
            iconBadge(systemName: "calendar.badge.checkmark", color: Theme.Colors.info)
            VStack(alignment: .leading, spacing: 2) {
                Text("วันนี้ยังไม่มีตารางเรียน")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("ไปที่แท็บ \"ตารางเรียน\" เพื่อเพิ่มคาบเรียน")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func classContent(now: Date) -> some View {
        let nowMinute = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let current = resolvedPeriods.first { $0.startMinute <= nowMinute && nowMinute < $0.endMinute }
        let next = resolvedPeriods.first { $0.startMinute > nowMinute }

        if let current {
            currentClassView(period: current, nowMinute: nowMinute)
        } else if let next {
            nextClassView(period: next, nowMinute: nowMinute)
        } else {
            doneForTodayState
        }
    }

    private var doneForTodayState: some View {
        HStack(spacing: Theme.Spacing.md) {
            iconBadge(systemName: "checkmark.seal.fill", color: Theme.Colors.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("หมดคาบเรียนวันนี้แล้ว")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("เก่งมาก ไปพักผ่อนหรือทบทวนบทเรียนได้เลย")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Current class

    private func currentClassView(period: ResolvedPeriod, nowMinute: Int) -> some View {
        let subjectColor = period.entry.subject?.color ?? Theme.Colors.primary
        let progress = period.endMinute > period.startMinute
            ? Double(nowMinute - period.startMinute) / Double(period.endMinute - period.startMinute)
            : 0
        let minutesLeft = max(0, period.endMinute - nowMinute)

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("กำลังเรียน", systemImage: "circle.fill")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(subjectColor)
                Spacer()
                Text("อีก \(minutesLeft) นาที")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            HStack(spacing: Theme.Spacing.md) {
                iconBadge(systemName: period.entry.subject?.iconName ?? "book.closed.fill", color: subjectColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(period.entry.subject?.name ?? period.entry.subjectName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text("\(period.startMinute.asClockString)–\(period.endMinute.asClockString)" + (period.entry.location.isEmpty ? "" : " · \(period.entry.location)"))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
            }

            ProgressView(value: min(1, max(0, progress)))
                .tint(subjectColor)
        }
    }

    // MARK: - Next class

    private func nextClassView(period: ResolvedPeriod, nowMinute: Int) -> some View {
        let subjectColor = period.entry.subject?.color ?? Theme.Colors.primary
        let minutesUntil = max(0, period.startMinute - nowMinute)

        return HStack(spacing: Theme.Spacing.md) {
            iconBadge(systemName: period.entry.subject?.iconName ?? "book.closed.fill", color: subjectColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("คาบถัดไป · อีก \(minutesUntil) นาที")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(subjectColor)
                Text(period.entry.subject?.name ?? period.entry.subjectName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(period.startMinute.asClockString + (period.entry.location.isEmpty ? "" : " · \(period.entry.location)"))
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Shared bits

    private func iconBadge(systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(color.opacity(0.14))
                .frame(width: 44, height: 44)
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    NavigationStack {
        DashboardNextClassCard()
            .padding()
    }
    .modelContainer(for: [ScheduleEntry.self, Subject.self, DayScheduleOverride.self, Term.self], inMemory: true)
}
