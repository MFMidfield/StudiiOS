//
//  CalendarDaySheet.swift
//  รายการของวันที่เลือก + แถวรายการที่ใช้ร่วมกับหน้าค้นหา
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิม (`eventsCard` / `itemRow` / `itemRowContent`
//  / `itemLeadingMark` / `itemSubtitle`) มาทั้งก้อน ไม่เปลี่ยนพฤติกรรม
//  (ขั้นที่ 5 จะเปลี่ยนการ์ดนี้เป็น sheet รายวันตาม 08_Calendar §3.5)
//

import SwiftUI

// ══════════════════════════════════════════════════════════════
// MARK: - การ์ดรายการของวันที่เลือก
// ══════════════════════════════════════════════════════════════

struct CalendarDayItemsCard: View {
    let title: String
    let isToday: Bool
    let items: [CalendarItem]
    let onSelect: (CalendarItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                if isToday {
                    Text("วันนี้")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if items.isEmpty {
                emptyState
            } else {
                ForEach(items) { item in
                    CalendarItemRow(item: item) { onSelect(item) }
                }
            }
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
            Text("ไม่มีกิจกรรมในวันนี้")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("กดค้างที่วันหรือกดปุ่ม + เพื่อเพิ่ม")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - แถวรายการ (ใช้ทั้งการ์ดรายวันและผลค้นหา)
// ══════════════════════════════════════════════════════════════

struct CalendarItemRow: View {
    let item: CalendarItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CalendarItemRowContent(item: item)
        }
        .buttonStyle(.plain)
    }
}

/// Shared row layout — used by `CalendarDayItemsCard` (tap = open editor) and
/// `CalendarSearchView` (tap = jump to that date) so the two never drift.
struct CalendarItemRowContent: View {
    let item: CalendarItem

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                leadingMark
                    .frame(width: 54, alignment: .leading)

                RoundedRectangle(cornerRadius: 2)
                    .fill(item.color)
                    .frame(width: 4, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(item.isDone ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                            .strikethrough(item.isDone)
                            .lineLimit(1)
                        if let event = item.sourceEvent, event.alert != .none {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.leading, 82)
        }
    }

    @ViewBuilder
    private var leadingMark: some View {
        if item.kind == .event {
            Group {
                if item.isAllDay {
                    Text("ทั้งวัน")
                } else {
                    Text(item.date, format: .dateTime.hour().minute())
                }
            }
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.Colors.textSecondary)
        } else {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(item.isDone ? Theme.Colors.success : item.color)
        }
    }

    private var subtitle: String? {
        switch item.kind {
        case .event:
            guard let event = item.sourceEvent else { return nil }
            let parts = [event.subjectName, event.location].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .exam:
            guard let task = item.sourceTask else { return nil }
            let parts = [task.examScope?.label, task.subjectName.isEmpty ? nil : task.subjectName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .homework, .personal:
            guard let task = item.sourceTask, !task.subjectName.isEmpty else { return nil }
            return task.subjectName
        }
    }
}
