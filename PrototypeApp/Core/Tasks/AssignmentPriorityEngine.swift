//
//  AssignmentPriorityEngine.swift
//  Pure logic (no View) for deriving an Assignment's automatic priority and
//  its Thai due-date label. Kept in one place so the formula can be changed
//  without touching any screen.
//

import Foundation

enum AssignmentPriorityEngine {

    /// Calendar days from `now` to `dueDate` (not 24-hour spans).
    /// Negative means the due date has already passed.
    static func daysUntil(_ dueDate: Date, from now: Date = .now) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.startOfDay(for: dueDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// เลยกำหนด 4 · วันนี้ 3 · พรุ่งนี้ 2 · อีก 2–3 วัน 1 · อีก ≥4 วัน หรือไม่กำหนด 0
    private static func timeScore(for dueDate: Date?, now: Date) -> Int {
        guard let dueDate else { return 0 }
        let days = daysUntil(dueDate, from: now)
        switch days {
        case ..<0: return 4
        case 0: return 3
        case 1: return 2
        case 2...3: return 1
        default: return 0
        }
    }

    static func priority(
        kind: AssignmentKind,
        dueDate: Date?,
        now: Date = .now
    ) -> AssignmentPriority {
        let score = timeScore(for: dueDate, now: now) + (kind == .homework ? 1 : 0)
        switch score {
        case 3...: return .high
        case 1...2: return .medium
        default: return .low
        }
    }

    /// ป้ายวันที่แสดงบนการ์ดงาน: "เลยกำหนด" · "วันนี้" · "พรุ่งนี้" · "อีก N วัน" · "ไม่กำหนด"
    static func dueLabel(for dueDate: Date?, now: Date = .now) -> String {
        guard let dueDate else { return "ไม่กำหนด" }
        let days = daysUntil(dueDate, from: now)
        switch days {
        case ..<0: return "เลยกำหนด"
        case 0: return "วันนี้"
        case 1: return "พรุ่งนี้"
        default: return "อีก \(days) วัน"
        }
    }
}
