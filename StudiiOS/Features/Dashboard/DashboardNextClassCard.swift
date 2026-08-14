//
//  DashboardNextClassCard.swift
//  Dashboard hero card: today's current/next class period, live. Reuses
//  PeriodShiftCalculator so a shortened day (DayScheduleOverride) reflects
//  here exactly like it does in ScheduleView — never a second time formula.
//  Own file per the same "keep DashboardView.body small" rule as
//  GPAXDashboardCard (see that file's header comment).
//
//  Unlike every other card this one is filled with `heroFill` rather than
//  `cardBackground` — it's the one element on the Dashboard that should read
//  first, so it uses the `onHero*` text tokens instead of `text*`.
//

import SwiftUI
import SwiftData

struct DashboardNextClassCard: View {
    @Query private var allEntries: [ScheduleEntry]
    @Query private var overrides: [DayScheduleOverride]
    @Query(sort: \Assignment.dueDate) private var assignments: [Assignment]

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

    /// The single task shown at the foot of the card. Sorted by `dueDate`
    /// already, but tasks with no due date carry a meaningless one — filter
    /// them out rather than letting one win the "soonest" slot.
    private var nextTask: Assignment? {
        assignments
            .inTerm(activeTerm)
            .first { !$0.isDone && $0.resolvedDueDate != nil }
    }

    var body: some View {
        HeroCardShell {
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
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HeroStatusRow(
                systemName: "cup.and.saucer.fill",
                title: "วันหยุดสุดสัปดาห์",
                subtitle: "พักผ่อนได้เต็มที่ ไม่มีคาบเรียนวันนี้"
            )
            HeroNextTaskRow(task: nextTask)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HeroStatusRow(
                systemName: "calendar.badge.checkmark",
                title: "วันนี้ยังไม่มีตารางเรียน",
                subtitle: "ไปที่แท็บ \"ตารางสอน\" เพื่อเพิ่มคาบเรียน"
            )
            HeroNextTaskRow(task: nextTask)
        }
    }

    private var doneForTodayState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HeroStatusRow(
                systemName: "checkmark.seal.fill",
                title: "หมดคาบเรียนวันนี้แล้ว",
                subtitle: "เก่งมาก ไปพักผ่อนหรือทบทวนบทเรียนได้เลย"
            )
            HeroNextTaskRow(task: nextTask)
        }
    }

    @ViewBuilder
    private func classContent(now: Date) -> some View {
        let nowMinute = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
        let current = resolvedPeriods.first { $0.startMinute <= nowMinute && nowMinute < $0.endMinute }
        let next = resolvedPeriods.first { $0.startMinute > nowMinute }

        if let current {
            currentClassView(period: current, next: next, nowMinute: nowMinute)
        } else if let next {
            nextClassView(period: next, nowMinute: nowMinute)
        } else {
            doneForTodayState
        }
    }

    // MARK: - Current class

    private func currentClassView(period: ResolvedPeriod, next: ResolvedPeriod?, nowMinute: Int) -> some View {
        let span = period.endMinute - period.startMinute
        let progress = span > 0 ? Double(nowMinute - period.startMinute) / Double(span) : 0
        let minutesLeft = max(0, period.endMinute - nowMinute)

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                PillLabel(
                    "กำลังเรียน",
                    systemImage: "circle.fill",
                    tone: .custom(foreground: Theme.Colors.heroFill, background: Theme.Colors.onHero)
                )
                Spacer()
                Text("อีก \(minutesLeft) นาที")
                    .font(Theme.Font.number(13))
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.Colors.onHeroMuted)
            }

            HeroSubjectRow(
                systemName: period.entry.subject?.iconName ?? "book.closed.fill",
                title: period.entry.subject?.name ?? period.entry.subjectName,
                subtitle: "\(period.startMinute.asClockString)–\(period.endMinute.asClockString)"
                    + (period.entry.location.isEmpty ? "" : " · \(period.entry.location)")
            )

            HeroProgressBar(progress: progress)

            if let next {
                HeroFootnoteRow(
                    systemName: "arrow.turn.down.right",
                    text: "ถัดไป · \(next.entry.subject?.name ?? next.entry.subjectName)",
                    trailing: next.startMinute.asClockString
                )
            } else {
                HeroFootnoteRow(
                    systemName: "checkmark.seal.fill",
                    text: "คาบสุดท้ายของวันแล้ว",
                    trailing: nil
                )
            }
        }
    }

    // MARK: - Next class

    private func nextClassView(period: ResolvedPeriod, nowMinute: Int) -> some View {
        let minutesUntil = max(0, period.startMinute - nowMinute)

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                PillLabel(
                    "คาบถัดไป",
                    systemImage: "clock.fill",
                    tone: .custom(foreground: Theme.Colors.heroFill, background: Theme.Colors.onHero)
                )
                Spacer()
                Text("อีก \(minutesUntil) นาที")
                    .font(Theme.Font.number(13))
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.Colors.onHeroMuted)
            }

            HeroSubjectRow(
                systemName: period.entry.subject?.iconName ?? "book.closed.fill",
                title: period.entry.subject?.name ?? period.entry.subjectName,
                subtitle: period.startMinute.asClockString
                    + (period.entry.location.isEmpty ? "" : " · \(period.entry.location)")
            )

            HeroNextTaskRow(task: nextTask)
        }
    }
}

// MARK: - Hero building blocks

/// The terracotta slab every hero state sits on.
private struct HeroCardShell<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.heroFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0 : 0.10),
                radius: 12, x: 0, y: 4
            )
    }
}

/// Icon + headline + supporting line — used by the three "no class right now" states.
private struct HeroStatusRow: View {
    let systemName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            IconTile(
                systemName: systemName,
                size: 44,
                tint: Theme.Colors.onHero,
                background: .white.opacity(0.18),
                cornerRadius: Theme.Radius.control
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.onHero)
                Text(subtitle)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.onHeroMuted)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Same shape as `HeroStatusRow` but for a real class period.
private struct HeroSubjectRow: View {
    let systemName: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            IconTile(
                systemName: systemName,
                size: 44,
                tint: Theme.Colors.onHero,
                background: .white.opacity(0.18),
                cornerRadius: Theme.Radius.control
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Colors.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.onHeroMuted)
            }
            Spacer(minLength: 0)
        }
    }
}

/// How far through the current period we are. Hand-rolled rather than
/// `ProgressView` because the stock track washes out on a saturated fill.
private struct HeroProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.22))
                Capsule()
                    .fill(Theme.Colors.onHero)
                    .frame(width: geo.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
    }
}

/// Divider + one supporting line at the foot of the card.
private struct HeroFootnoteRow: View {
    let systemName: String
    let text: String
    let trailing: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .medium))
                Text(text)
                    .font(Theme.Font.label)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.sm)
                if let trailing {
                    Text(trailing)
                        .font(Theme.Font.label)
                }
            }
            .foregroundStyle(Theme.Colors.onHeroMuted)
        }
    }
}

/// "งานถัดไป" line — every state except "กำลังเรียน" ends with this.
private struct HeroNextTaskRow: View {
    let task: Assignment?

    var body: some View {
        if let task {
            HeroFootnoteRow(
                systemName: "checklist",
                text: "งานถัดไป · \(task.title)",
                trailing: task.resolvedDueDate?.thaiShortString
            )
        } else {
            HeroFootnoteRow(
                systemName: "checkmark.circle",
                text: "ไม่มีงานค้าง",
                trailing: nil
            )
        }
    }
}

#Preview {
    NavigationStack {
        DashboardNextClassCard()
            .padding()
    }
    .modelContainer(for: [ScheduleEntry.self, Subject.self, DayScheduleOverride.self, Term.self, Assignment.self], inMemory: true)
}
