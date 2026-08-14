//
//  ScheduleDayPickerBar.swift
//  Monday–Friday day selector strip for the Schedule tab. The selected day is a
//  filled capsule that slides between days; today is marked by colouring its
//  label rather than by a separate dot — one signal per day, not two.
//

import SwiftUI

struct ScheduleDayPickerBar: View {
    @Binding var selectedDay: Int
    @Namespace private var capsuleNamespace

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ScheduleConstants.visibleDays, id: \.self) { day in
                dayButton(day)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        // The strip is not a card — giving it its own surface made it read as
        // a second header stacked under the navigation bar.
        .background(Theme.Colors.background)
        .animation(.snappy, value: selectedDay)
    }

    private func dayButton(_ day: Int) -> some View {
        let isSelected = day == selectedDay
        let isToday = day == ScheduleConstants.todayWeekday

        return Button {
            selectedDay = day
            AppLog.action("Schedule", "เลือกวัน: \(ScheduleConstants.dayLabels[day] ?? "")")
        } label: {
            Text(ScheduleConstants.dayLabels[day] ?? "")
                .font(Theme.Font.plex(14, isSelected ? .semibold : .regular))
                .foregroundStyle(foreground(isSelected: isSelected, isToday: isToday))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Theme.Colors.primary)
                            .matchedGeometryEffect(id: "selectedDay", in: capsuleNamespace)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Today keeps an accent tint while unselected so the student can find it
    /// after browsing another day.
    private func foreground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return Theme.Colors.onPrimary }
        return isToday ? Theme.Colors.primaryDeep : Theme.Colors.textSecondary
    }
}

#Preview {
    @Previewable @State var selectedDay = 1
    return ScheduleDayPickerBar(selectedDay: $selectedDay)
        .background(Theme.Colors.background)
}
