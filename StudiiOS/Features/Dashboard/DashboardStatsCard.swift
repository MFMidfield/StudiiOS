//
//  DashboardStatsCard.swift
//  "สรุปวันนี้" — a 2×2 grid of small cards sitting under the hero: focus
//  minutes, pending tasks, due tomorrow, and the next exam countdown.
//  Split out of DashboardView.swift during the dark-mode/redesign pass so
//  the numeric roll animation (`.numericText()`) lives with its own state.
//

import SwiftUI
import SwiftData

struct DashboardStatsCard: View {
    let focusMinutesToday: Int
    let pendingCount: Int

    @Query(sort: \Assignment.dueDate) private var assignments: [Assignment]
    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    @State private var showAddExam = false

    private var scopedPending: [Assignment] {
        assignments.inTerm(activeTerm).filter { !$0.isDone }
    }

    private var dueTomorrowCount: Int {
        scopedPending.filter {
            guard let due = $0.resolvedDueDate else { return false }
            return Calendar.current.isDateInTomorrow(due)
        }.count
    }

    /// Soonest exam that hasn't happened yet. `assignments` is already sorted by
    /// `dueDate`, so the first match is the nearest one.
    private var nextExam: Assignment? {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return scopedPending.first {
            $0.kind == .exam && ($0.resolvedDueDate ?? .distantPast) >= startOfToday
        }
    }

    /// Whole days from today to the exam — 0 means it's today.
    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        let from = cal.startOfDay(for: .now)
        let to = cal.startOfDay(for: date)
        return max(0, cal.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            StatTile(
                icon: "timer",
                color: Theme.Colors.primaryDeep,
                background: Theme.Colors.primarySoft,
                value: "\(focusMinutesToday)",
                suffix: " น.",
                label: "โฟกัสวันนี้"
            )
            StatTile(
                icon: "tray.full.fill",
                color: Theme.Colors.info,
                background: Theme.Colors.info.opacity(0.14),
                value: "\(pendingCount)",
                suffix: "",
                label: "งานค้าง"
            )
            StatTile(
                icon: "sunrise.fill",
                color: Theme.Colors.warning,
                background: Theme.Colors.warning.opacity(0.16),
                value: "\(dueTomorrowCount)",
                suffix: "",
                label: "ส่งพรุ่งนี้"
            )
            examTile
        }
        .sheet(isPresented: $showAddExam) {
            AddTaskSheet(presetKind: .exam)
        }
    }

    /// Fourth slot doubles as an empty state — with no exam on file it becomes a
    /// button that opens the task form already switched to "สอบ".
    @ViewBuilder
    private var examTile: some View {
        if let exam = nextExam, let due = exam.resolvedDueDate {
            let days = daysUntil(due)
            StatTile(
                icon: "pencil.and.list.clipboard",
                color: days <= 3 ? Theme.Colors.danger : Theme.Colors.primaryDeep,
                background: days <= 3 ? Theme.Colors.danger.opacity(0.12) : Theme.Colors.primarySoft,
                value: days == 0 ? "วันนี้" : "\(days)",
                suffix: days == 0 ? "" : " วัน",
                label: exam.examScope.map { "\($0.label) · \(exam.title)" } ?? exam.title
            )
        } else {
            Button {
                showAddExam = true
            } label: {
                StatTile(
                    icon: "plus",
                    color: Theme.Colors.primaryDeep,
                    background: Theme.Colors.primarySoft,
                    value: "เพิ่ม",
                    suffix: "",
                    label: "เพิ่มวันสอบ"
                )
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }
}

private struct StatTile: View {
    let icon: String
    let color: Color
    let background: Color
    /// Pre-formatted so a tile can show "วันนี้" instead of a number.
    let value: String
    let suffix: String
    let label: String

    var body: some View {
        CardContainer(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                IconTile(systemName: icon, size: 34, tint: color, background: background)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(value)
                            .font(Theme.Font.number(20))
                            .contentTransition(.numericText())
                            .animation(.snappy, value: value)
                        Text(suffix)
                            .font(Theme.Font.caption)
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                    Text(label)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    ScrollView {
        DashboardStatsCard(focusMinutesToday: 45, pendingCount: 3)
            .padding()
    }
    .background(Theme.Colors.background)
    .modelContainer(for: [Assignment.self, Term.self], inMemory: true)
}
