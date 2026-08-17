//
//  PeriodShiftBanner.swift
//  Shown above ScheduleTimetableSection whenever the selected day has a
//  DayScheduleOverride active. "คืนค่าเดิม" deletes the override — the
//  underlying ScheduleEntry rows are never touched, so this fully restores
//  the original schedule.
//

import SwiftUI
import SwiftData

struct PeriodShiftBanner: View {
    @Environment(\.modelContext) private var context

    let override: DayScheduleOverride

    @State private var showConfirm = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Only the icon carries the warning colour. Amber text on an amber
            // wash was the lowest-contrast text in the app.
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .foregroundStyle(Theme.Colors.warning)

            Text("วันนี้ร่นคาบ · เริ่มคาบ \(override.startPeriodNumber) \(override.startMinute.asClockString) · คาบละ \(override.periodLengthMinutes) นาที")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer(minLength: Theme.Spacing.xs)

            // Kept accent-coloured: it is the one tappable thing in the banner.
            Button("คืนค่าเดิม") {
                showConfirm = true
            }
            .font(Theme.Font.plex(11, .semibold))
            .foregroundStyle(Theme.Colors.primaryDeep)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.warning.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .confirmationDialog(
            "คืนค่าตารางเดิม?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("คืนค่าเดิม", role: .destructive, action: restore)
            Button("ยกเลิก", role: .cancel) {}
        }
    }

    private func restore() {
        let dateLabel = override.date.thaiDayMonthYearString
        context.delete(override)
        do {
            try context.save()
            AppLog.action("Shift", "ยกเลิกร่นคาบ \(dateLabel)")
        } catch {
            AppLog.error("Shift", "save ล้มเหลว: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: DayScheduleOverride.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let override = DayScheduleOverride(date: .now, startPeriodNumber: 1, startMinute: 510, periodLengthMinutes: 50)
    container.mainContext.insert(override)

    return PeriodShiftBanner(override: override)
        .padding()
        .background(Theme.Colors.background)
        .modelContainer(container)
}
