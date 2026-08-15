//
//  CalendarWeekRow.swift
//  หนึ่งแถวสัปดาห์ — 7 ช่องวัน
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิม (`dayCell` / `dayPills`) มาทั้งก้อน ไม่เปลี่ยนพฤติกรรม
//  (ขั้นที่ 3 จะเปลี่ยนเป็น ZStack + แถบพาดข้ามช่องตาม WeekLayout)
//

import SwiftUI

struct CalendarWeekRow: View {
    let days: [CalendarDay]
    let selectedDate: Date
    let calendar: Calendar
    let itemsFor: (Date) -> [CalendarItem]
    let isBeingDragged: (CalendarItem) -> Bool
    let onSelectDay: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                CalendarDayCell(
                    day: day,
                    selectedDate: selectedDate,
                    calendar: calendar,
                    items: day.inMonth ? itemsFor(day.date) : [],
                    isBeingDragged: isBeingDragged,
                    onSelectDay: onSelectDay
                )
            }
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - หนึ่งช่องวัน
// ══════════════════════════════════════════════════════════════

struct CalendarDayCell: View {
    let day: CalendarDay
    let selectedDate: Date
    let calendar: Calendar
    let items: [CalendarItem]
    let isBeingDragged: (CalendarItem) -> Bool
    let onSelectDay: (Date) -> Void

    var body: some View {
        let todayFlag = calendar.isDateInToday(day.date)
        let selectedFlag = calendar.isDate(day.date, inSameDayAs: selectedDate)

        VStack(spacing: 3) {
            ZStack {
                if todayFlag {
                    Circle().fill(Theme.Colors.primaryDeep).frame(width: 32, height: 32)
                } else if selectedFlag {
                    Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 32, height: 32)
                }
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.system(size: 14, weight: todayFlag ? .bold : .regular))
                    .foregroundStyle(
                        todayFlag    ? Theme.Colors.onPrimary :
                        !day.inMonth ? Theme.Colors.textSecondary.opacity(0.5) :
                        selectedFlag ? Theme.Colors.primaryDeep :
                        Theme.Colors.textPrimary
                    )
            }
            .frame(height: 24)

            dayPills
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onSelectDay(day.date)
            }
        }
    }

    @ViewBuilder
    private var dayPills: some View {
        let visible = items.prefix(2)
        let overflow = items.count - visible.count
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(visible)) { item in
                CalendarEventBar(item: item, isDragging: isBeingDragged(item))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.leading, 3)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 3)
    }
}
