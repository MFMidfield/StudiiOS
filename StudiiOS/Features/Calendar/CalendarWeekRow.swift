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

    /// ความสูงของแถบเส้นแบ่งเดือน (มีตัวย่อเดือนนั่งอยู่บนเส้น) — ต้องคงที่
    /// เพราะ ghost drag ใช้ลบออกจากพิกัดก่อนหารเป็นแถว
    static let monthLabelHeight: CGFloat = 28

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
    /// แตะชิป → เปิดฟอร์มของรายการนั้นเลย (§3.4)
    let onSelectItem: (CalendarItem) -> Void

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

                barsLayer(colWidth: colWidth)
                overflowLayer(colWidth: colWidth)
            }
        }
        .frame(height: CalendarGeometry.rowHeight)
    }

    /// ช่วงคอลัมน์ที่เป็นวันของเดือนนี้จริงๆ — แถบต้องไม่ล้นไปทับช่องว่าง
    /// ของเดือนข้างเคียง (ท่อนที่ล้นไปโผล่ในเดือนนั้นแทน พร้อมคำว่า "(ต่อ)")
    private var inMonthColumns: ClosedRange<Int>? {
        let columns = days.indices.filter { days[$0].inMonth }
        guard let first = columns.first, let last = columns.last else { return nil }
        return first...last
    }

    /// ตัดแถบให้เหลือเฉพาะช่วงที่อยู่ในเดือนนี้ · nil = ไม่โผล่ในแถวนี้เลย
    private func clip(_ bar: LaidOutBar) -> (start: Int, span: Int, continued: Bool)? {
        guard let range = inMonthColumns else { return nil }
        let start = max(bar.startColumn, range.lowerBound)
        let end = min(bar.startColumn + bar.columnSpan - 1, range.upperBound)
        guard end >= start else { return nil }
        return (start, end - start + 1, bar.isContinuation || start > bar.startColumn)
    }

    private func barsLayer(colWidth: CGFloat) -> some View {
        ForEach(layout.bars, id: \.itemID) { bar in
            if let item = itemsByID[bar.itemID], let piece = clip(bar) {
                Button {
                    onSelectItem(item)
                } label: {
                    CalendarEventBar(
                        item: item,
                        isContinuation: piece.continued,
                        isDragging: isBeingDragged(item)
                    )
                }
                .buttonStyle(.plain)
                .frame(
                    width: max(colWidth * CGFloat(piece.span) - CalendarGeometry.barGap, 0),
                    height: CalendarGeometry.laneHeight
                )
                .offset(
                    x: colWidth * CGFloat(piece.start) + CalendarGeometry.barGap / 2,
                    y: CalendarGeometry.laneOffset(bar.lane)
                )
            }
        }
    }

    /// แตะ `+N` = เปิด sheet รายวันของวันนั้น (§3.4)
    private func overflowLayer(colWidth: CGFloat) -> some View {
        ForEach(layout.overflowByColumn.keys.sorted().filter { inMonthColumns?.contains($0) == true }, id: \.self) { column in
            Button {
                if column < days.count { onSelectDay(days[column].date) }
            } label: {
                Text("+\(layout.overflowByColumn[column] ?? 0)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.leading, Theme.Spacing.xs)
                    .frame(width: colWidth, height: CalendarGeometry.overflowHeight, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        if day.inMonth {
            cell
        } else {
            // วันของเดือนข้างเคียง — เว้นว่างเปล่า ไม่มีเลข ไม่มีชิป แตะไม่ติด
            // (แต่ยังกินที่ 1 คอลัมน์ ตารางจึงยังเป็น 7 ช่องเท่าเดิม)
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var cell: some View {
        let todayFlag = calendar.isDateInToday(day.date)
        let selectedFlag = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let weekendFlag = calendar.component(.weekday, from: day.date) == 1
            || calendar.component(.weekday, from: day.date) == 7

        return VStack(spacing: 0) {
            ZStack {
                // วงกลมมีเฉพาะ "วันนี้" — วันที่เลือกใช้แค่สีตัวเลข
                // (วงกลมของวันที่เลือกเด้งตามนิ้วทุกครั้งที่แตะ Few ว่ารก)
                if todayFlag {
                    Circle().fill(Theme.Colors.primaryDeep).frame(width: 26, height: 26)
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
