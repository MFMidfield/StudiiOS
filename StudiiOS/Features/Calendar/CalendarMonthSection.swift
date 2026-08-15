//
//  CalendarMonthSection.swift
//  หนึ่งเดือน — แถวชื่อวัน + ตารางสัปดาห์
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิมออกจาก CalendarView.swift โดยไม่เปลี่ยนพฤติกรรม
//  (ขั้นที่ 4 จะเปลี่ยนเป็นเดือนใน ScrollView 12 เดือน)
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
// MARK: - หนึ่งช่องวันในตาราง
// ══════════════════════════════════════════════════════════════

struct CalendarDay: Identifiable {
    let date: Date
    let inMonth: Bool
    var id: Date { date }
}

enum CalendarMonthBuilder {
    /// 42 (หรือ 35) ช่องของเดือนนั้น รวมวันหัว/ท้ายที่ล้นมาจากเดือนข้างเคียง
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
// MARK: - แถวชื่อวัน
// ══════════════════════════════════════════════════════════════

struct CalendarDayHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarStrings.thaiDays, id: \.self) { d in
                Text(d)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - ตารางของหนึ่งเดือน
// ══════════════════════════════════════════════════════════════

/// ตัวนี้เป็น **เนื้อตารางล้วน** ไม่ผูก gesture/geometry ไว้เอง —
/// `CalendarView` เป็นคนแปะ `.coordinateSpace` / `.onGeometryChange` /
/// ghost gesture ทับอีกชั้น เพื่อให้ลำดับ modifier เหมือนของเดิมเป๊ะ
struct CalendarMonthSection: View {
    let days: [CalendarDay]
    let selectedDate: Date
    let calendar: Calendar
    let itemsByID: [String: CalendarItem]
    /// เลขแถว → ผลจัดเลนของสัปดาห์นั้น (คำนวณที่ `CalendarView` เพื่อให้ ghost drag
    /// ใช้ผลชุดเดียวกันตอน hit-test)
    let weekLayout: (Int) -> WeekLayout
    let isBeingDragged: (CalendarItem) -> Bool
    let onSelectDay: (Date) -> Void

    var body: some View {
        let rowCount = days.count / 7
        VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { row in
                CalendarWeekRow(
                    days: Array(days[(row * 7)..<(row * 7 + 7)]),
                    selectedDate: selectedDate,
                    calendar: calendar,
                    layout: weekLayout(row),
                    itemsByID: itemsByID,
                    isBeingDragged: isBeingDragged,
                    onSelectDay: onSelectDay
                )
            }
        }
    }
}
