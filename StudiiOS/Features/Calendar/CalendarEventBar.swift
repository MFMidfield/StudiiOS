//
//  CalendarEventBar.swift
//  ชิปหนึ่งใบในแถวสัปดาห์ — 3 แบบตาม 08_Calendar §3.3
//
//    กิจกรรมปฏิทิน  พื้นทึบสีของกิจกรรมจางลง ไม่มีขอบ
//    งาน/การบ้าน    พื้นการ์ด + ขอบ 1pt สีวิชา + วงกลมกลวงนำหน้า
//    งานที่เสร็จแล้ว เหมือนงานปกติแต่จางลงและมีขีดฆ่า
//
//  ชื่ออย่างเดียว ไม่มีเวลา — กว้างประมาณ 5-6 ตัวอักษรไทยเท่านั้น
//

import SwiftUI

struct CalendarEventBar: View {
    let item: CalendarItem
    /// ท่อนต่อจากสัปดาห์ก่อน → เติม " (ต่อ)" ท้ายชื่อ
    let isContinuation: Bool
    let isDragging: Bool

    private var isEvent: Bool { item.kind == .event }
    private var label: String { isContinuation ? "\(item.title) (ต่อ)" : item.title }

    var body: some View {
        HStack(spacing: 3) {
            if !isEvent {
                Circle()
                    .strokeBorder(item.color, lineWidth: 1.2)
                    .frame(width: 7, height: 7)
            }
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(isEvent ? item.color : Theme.Colors.textPrimary)
                .strikethrough(item.isDone)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isEvent ? item.color.opacity(0.18) : Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CalendarGeometry.barRadius))
        .overlay {
            if !isEvent {
                RoundedRectangle(cornerRadius: CalendarGeometry.barRadius)
                    .strokeBorder(item.color, lineWidth: 1)
            }
        }
        .opacity(opacity)
    }

    private var opacity: Double {
        if isDragging { return 0.3 }
        return item.isDone ? 0.45 : 1
    }
}
