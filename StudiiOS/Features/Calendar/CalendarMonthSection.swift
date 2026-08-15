//
//  CalendarMonthSection.swift
//  หนึ่งเดือนในสายเลื่อน — ป้ายชื่อเดือน + 4-6 แถวสัปดาห์
//

import SwiftUI

// ══════════════════════════════════════════════════════════════
// MARK: - ข้อความไทยที่ใช้ร่วมกันทั้งโมดูล
// ══════════════════════════════════════════════════════════════

enum CalendarStrings {
    static let thaiMonths = [
        "มกราคม","กุมภาพันธ์","มีนาคม","เมษายน",
        "พฤษภาคม","มิถุนายน","กรกฎาคม","สิงหาคม",
        "กันยายน","ตุลาคม","พฤศจิกายน","ธันวาคม"
    ]
    static let thaiDays = ["อา.","จ.","อ.","พ.","พฤ.","ศ.","ส."]
}

// ══════════════════════════════════════════════════════════════
// MARK: - หนึ่งช่องวัน / หนึ่งเดือน
// ══════════════════════════════════════════════════════════════

struct CalendarDay: Identifiable, Equatable {
    let date: Date
    let inMonth: Bool
    var id: Date { date }
}

struct CalendarMonthInfo: Identifiable, Equatable {
    /// "2026-08" — ใช้เป็น id ของ `scrollPosition` และคีย์ของตาราง frame
    let id: String
    let month: Date
    let title: String
    let days: [CalendarDay]
}

enum CalendarMonthBuilder {

    static func key(for date: Date, calendar cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// 12 เดือนของปีนั้น (ปี ค.ศ.) — สายเลื่อนไม่ข้ามปี ตาม 08_Calendar §3.2
    static func months(inYear year: Int, calendar cal: Calendar) -> [CalendarMonthInfo] {
        (1...12).compactMap { month in
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let first = cal.date(from: comps) else { return nil }
            return CalendarMonthInfo(
                id: key(for: first, calendar: cal),
                month: first,
                title: CalendarStrings.thaiMonths[month - 1],
                days: days(of: first, calendar: cal)
            )
        }
    }

    /// 35 หรือ 42 ช่องของเดือนนั้น รวมวันหัว/ท้ายที่ล้นมาจากเดือนข้างเคียง
    static func days(of month: Date, calendar cal: Calendar) -> [CalendarDay] {
        let comps = cal.dateComponents([.year, .month], from: month)
        let first = cal.date(from: comps)!
        let firstWeekday = cal.component(.weekday, from: first) - 1 // 0 = Sun

        var days: [CalendarDay] = []
        for i in stride(from: firstWeekday - 1, through: 0, by: -1) {
            let d = cal.date(byAdding: .day, value: -(i + 1), to: first)!
            days.append(CalendarDay(date: d, inMonth: false))
        }
        let count = cal.range(of: .day, in: .month, for: month)!.count
        for i in 0..<count {
            let d = cal.date(byAdding: .day, value: i, to: first)!
            days.append(CalendarDay(date: d, inMonth: true))
        }
        let trailing = (7 - days.count % 7) % 7
        for i in 0..<trailing {
            let d = cal.date(byAdding: .day, value: i + 1, to: days.last!.date)!
            days.append(CalendarDay(date: d, inMonth: false))
        }
        return days
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - แถวชื่อวัน (ปักหมุด อยู่นอก ScrollView)
// ══════════════════════════════════════════════════════════════

struct CalendarDayHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarStrings.thaiDays, id: \.self) { d in
                Text(d)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Colors.background)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - ตารางของหนึ่งเดือน
// ══════════════════════════════════════════════════════════════

struct CalendarMonthSection: View {
    let month: CalendarMonthInfo
    let selectedDate: Date
    let calendar: Calendar
    let itemsByID: [String: CalendarItem]
    /// วันแรกของสัปดาห์ → ผลจัดเลน (คำนวณที่ `CalendarView` จุดเดียว
    /// เพื่อให้ ghost drag ใช้ผลชุดเดียวกันตอน hit-test)
    let weekLayout: (Date) -> WeekLayout
    let isBeingDragged: (CalendarItem) -> Bool
    let onSelectDay: (Date) -> Void
    let onSelectItem: (CalendarItem) -> Void
    /// frame ของเดือนนี้ในระบบพิกัดของสายเลื่อน — ghost drag ใช้หาว่านิ้วอยู่เดือนไหน
    let onFrameChange: (CGRect) -> Void

    var body: some View {
        let rowCount = month.days.count / 7
        VStack(alignment: .leading, spacing: 0) {
            Text(month.title)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(height: CalendarGeometry.monthLabelHeight, alignment: .bottomLeading)

            ForEach(0..<rowCount, id: \.self) { row in
                let days = Array(month.days[(row * 7)..<(row * 7 + 7)])
                CalendarWeekRow(
                    days: days,
                    selectedDate: selectedDate,
                    calendar: calendar,
                    layout: weekLayout(days[0].date),
                    itemsByID: itemsByID,
                    isBeingDragged: isBeingDragged,
                    onSelectDay: onSelectDay,
                    onSelectItem: onSelectItem
                )
            }
        }
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .named(CalendarView.gridSpaceName))
        } action: {
            onFrameChange($0)
        }
    }
}
