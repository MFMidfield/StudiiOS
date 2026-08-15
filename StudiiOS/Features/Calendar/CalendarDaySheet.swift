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

struct CalendarDaySheet: View {
    let date: Date
    let isToday: Bool
    let items: [CalendarItem]
    let onSelect: (CalendarItem) -> Void
    /// ปุ่มท้าย sheet — เปิด `EventFormSheet(initialDate:)` ของวันนั้น
    let onAddEvent: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            CalendarItemRow(item: item) { onSelect(item) }
                        }
                    }
                }
            }

            addButton
        }
        .background(Theme.Colors.background)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text(date.thaiWeekdayFullString)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.textPrimary)

            if isToday {
                PillLabel("วันนี้", tone: .accent)
            }

            Spacer()

            Text("\(items.count) รายการ")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
            Text("ยังไม่มีอะไรในวันนี้")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private var addButton: some View {
        Button {
            onAddEvent(date)
        } label: {
            Label("เพิ่มกิจกรรมวันนี้", systemImage: "plus")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(Theme.Spacing.lg)
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
