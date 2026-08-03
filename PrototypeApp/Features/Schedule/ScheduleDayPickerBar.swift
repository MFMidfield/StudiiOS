//
//  ScheduleDayPickerBar.swift
//  Monday–Friday day selector strip for the Schedule tab, with a sliding
//  underline on the selected day and a dot marking today's real weekday.
//

import SwiftUI

struct ScheduleDayPickerBar: View {
    @Binding var selectedDay: Int
    @Namespace private var underlineNamespace

    private var todayWeekday: Int {
        // Calendar.weekday: 1=Sunday...7=Saturday → remap to 1=Monday...7=Sunday
        let raw = Calendar.current.component(.weekday, from: .now)
        return raw == 1 ? 7 : raw - 1
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleConstants.visibleDays, id: \.self) { day in
                dayButton(day)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
        .background(Color.white)
        .animation(.snappy, value: selectedDay)
    }

    private func dayButton(_ day: Int) -> some View {
        let isSelected = day == selectedDay
        let isToday = day == todayWeekday

        return Button {
            selectedDay = day
            AppLog.action("Schedule", "เลือกวัน: \(ScheduleConstants.dayLabels[day] ?? "")")
        } label: {
            VStack(spacing: 6) {
                Text(ScheduleConstants.dayLabels[day] ?? "")
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Theme.Colors.primary : Theme.Colors.textSecondary)

                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.primary)
                            .frame(height: 3)
                            .matchedGeometryEffect(id: "underline", in: underlineNamespace)
                    } else {
                        Color.clear.frame(height: 3)
                    }
                }

                Circle()
                    .fill(isToday ? Theme.Colors.primary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedDay = 1
    return ScheduleDayPickerBar(selectedDay: $selectedDay)
        .background(Theme.Colors.background)
}
