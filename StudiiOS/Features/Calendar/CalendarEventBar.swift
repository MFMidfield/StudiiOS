//
//  CalendarEventBar.swift
//  ชิปหนึ่งใบในช่องวัน
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิม (`dayPill`) มาตรงๆ ไม่เปลี่ยนพฤติกรรม
//  (ขั้นที่ 3 จะเปลี่ยนเป็นชิป 3 แบบตาม 08_Calendar §3.3 + แถบพาดหลายวัน)
//

import SwiftUI

struct CalendarEventBar: View {
    let item: CalendarItem
    let isDragging: Bool

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(item.color).frame(width: 5, height: 5)
            Text(item.shortLabel)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 14)
        .opacity(isDragging ? 0.3 : 1)
    }
}
