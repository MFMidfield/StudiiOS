//
//  CalendarWeekRow.swift
//  หนึ่งแถวสัปดาห์ — 7 ช่องวันชั้นล่าง + แถบพาดข้ามช่องชั้นบน
//
//  ห้ามให้แต่ละช่องวันวาดชิปของตัวเอง (08_Calendar §4.1) — แถบหลายวันจะพาด
//  ข้ามช่องไม่ได้ · `colWidth` อ่านจาก GeometryReader **ครั้งเดียวต่อแถว**
//

import SwiftUI

// ══════════════════════════════════════════════════════════════
// MARK: - ขนาดของแถว (08_Calendar §3.1)
// ══════════════════════════════════════════════════════════════

enum CalendarGeometry {
    static let maxLanes = 4
    static let laneHeight: CGFloat = 17
    static let laneSpacing: CGFloat = 3
    /// ช่องว่างท้ายแถบ กันแถบคนละวันติดกันจนดูเป็นก้อนเดียว
    static let barGap: CGFloat = 2
    /// §3.1 — เล็กกว่า `Theme.Radius.control` (12) เพราะแถบสูงแค่ 17
    /// ยังไม่มี token ขนาดนี้ใน `Theme.Radius` → เก็บไว้ที่โมดูลนี้ก่อน
    static let barRadius: CGFloat = 5

    static let topPadding: CGFloat = 4
    static let dayNumberHeight: CGFloat = 26
    static let numberToLaneGap: CGFloat = 4
    static let overflowHeight: CGFloat = 14
    static let bottomPadding: CGFloat = 4

    /// ระยะจากขอบบนของแถวถึงเลนที่ 0
    static var laneTop: CGFloat { topPadding + dayNumberHeight + numberToLaneGap }
    static var lanesHeight: CGFloat {
        CGFloat(maxLanes) * laneHeight + CGFloat(maxLanes - 1) * laneSpacing
    }
    static var overflowTop: CGFloat { laneTop + lanesHeight + laneSpacing }
    static var rowHeight: CGFloat { overflowTop + overflowHeight + bottomPadding }

    static func laneOffset(_ lane: Int) -> CGFloat {
        laneTop + CGFloat(lane) * (laneHeight + laneSpacing)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - แถวสัปดาห์
// ══════════════════════════════════════════════════════════════

struct CalendarWeekRow: View {
    let days: [CalendarDay]
    let selectedDate: Date
    let calendar: Calendar
    let layout: WeekLayout
    let itemsByID: [String: CalendarItem]
    let isBeingDragged: (CalendarItem) -> Bool
    let onSelectDay: (Date) -> Void

    var body: some View {
        GeometryReader { geo in
            let colWidth = geo.size.width / 7
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        CalendarDayCell(
                            day: day,
                            selectedDate: selectedDate,
                            calendar: calendar,
                            onSelectDay: onSelectDay
                        )
                    }
                }

                // ชั้นแถบ — ยังไม่รับการแตะในขั้นนี้ (แตะชิป = ขั้นที่ 5)
                // ปล่อยให้ทะลุลงช่องวันข้างล่างเหมือนพฤติกรรมเดิม
                barsLayer(colWidth: colWidth)
                    .allowsHitTesting(false)
                overflowLayer(colWidth: colWidth)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: CalendarGeometry.rowHeight)
    }

    private func barsLayer(colWidth: CGFloat) -> some View {
        ForEach(layout.bars, id: \.itemID) { bar in
            if let item = itemsByID[bar.itemID] {
                CalendarEventBar(
                    item: item,
                    isContinuation: bar.isContinuation,
                    isDragging: isBeingDragged(item)
                )
                .frame(
                    width: max(colWidth * CGFloat(bar.columnSpan) - CalendarGeometry.barGap, 0),
                    height: CalendarGeometry.laneHeight
                )
                .offset(
                    x: colWidth * CGFloat(bar.startColumn) + CalendarGeometry.barGap / 2,
                    y: CalendarGeometry.laneOffset(bar.lane)
                )
            }
        }
    }

    private func overflowLayer(colWidth: CGFloat) -> some View {
        ForEach(layout.overflowByColumn.keys.sorted(), id: \.self) { column in
            Text("+\(layout.overflowByColumn[column] ?? 0)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: colWidth, height: CalendarGeometry.overflowHeight, alignment: .leading)
                .padding(.leading, Theme.Spacing.xs)
                .offset(x: colWidth * CGFloat(column), y: CalendarGeometry.overflowTop)
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - หนึ่งช่องวัน (เลขวัน + พื้นที่แตะ — ไม่มีชิปแล้ว)
// ══════════════════════════════════════════════════════════════

struct CalendarDayCell: View {
    let day: CalendarDay
    let selectedDate: Date
    let calendar: Calendar
    let onSelectDay: (Date) -> Void

    var body: some View {
        let todayFlag = calendar.isDateInToday(day.date)
        let selectedFlag = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let weekendFlag = calendar.component(.weekday, from: day.date) == 1
            || calendar.component(.weekday, from: day.date) == 7

        VStack(spacing: 0) {
            ZStack {
                if todayFlag {
                    Circle().fill(Theme.Colors.primaryDeep).frame(width: 26, height: 26)
                } else if selectedFlag {
                    Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 26, height: 26)
                }
                Text("\(calendar.component(.day, from: day.date))")
                    .font(Theme.Font.label)
                    .fontWeight(todayFlag ? .semibold : .regular)
                    .foregroundStyle(numberColor(today: todayFlag, selected: selectedFlag, weekend: weekendFlag))
            }
            .frame(height: CalendarGeometry.dayNumberHeight)
            Spacer(minLength: 0)
        }
        .padding(.top, CalendarGeometry.topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onSelectDay(day.date)
            }
        }
    }

    /// เสาร์/อาทิตย์ **จางลง** ไม่ใช่แดง — แดงคือ `danger` ที่มีความหมายอื่นในระบบ (§3.2)
    private func numberColor(today: Bool, selected: Bool, weekend: Bool) -> Color {
        if today { return Theme.Colors.onPrimary }
        if !day.inMonth { return Theme.Colors.textSecondary.opacity(0.5) }
        if selected { return Theme.Colors.primaryDeep }
        return weekend ? Theme.Colors.textSecondary : Theme.Colors.textPrimary
    }
}
