//
//  TaskScope.swift
//  The single definition of every "which tasks count" rule on the Todo screen.
//  Both the filter chips and the stats cards read from here — never re-derive
//  these conditions anywhere else, or the two will drift apart.
//

import Foundation

enum TaskScope: String, CaseIterable, Identifiable {
    case all, notDone, dueSoon, overdue, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "ทั้งหมด"
        case .notDone: return "ยังไม่เสร็จ"
        case .dueSoon: return "ใกล้ถึงกำหนด"
        case .overdue: return "เลยกำหนด"
        case .done: return "เสร็จแล้ว"
        }
    }

    /// "ใกล้ถึงกำหนด" = ยังไม่เสร็จ · มีวันกำหนดส่ง · ภายใน 3 วันนับจากวันนี้
    static let dueSoonWindowDays = 3

    func matches(_ assignment: Assignment, now: Date = .now) -> Bool {
        switch self {
        case .all:
            return true
        case .notDone:
            return !assignment.isDone
        case .dueSoon:
            guard !assignment.isDone, let due = assignment.resolvedDueDate else { return false }
            let days = AssignmentPriorityEngine.daysUntil(due, from: now)
            return days >= 0 && days <= Self.dueSoonWindowDays
        case .overdue:
            return assignment.isOverdue
        case .done:
            return assignment.isDone
        }
    }

    /// The 4 chips across the top of the screen.
    static let chips: [TaskScope] = [.all, .notDone, .dueSoon, .done]

    /// The 4 stat cards. Tapping one jumps to `chipTarget`.
    static let stats: [TaskScope] = [.all, .dueSoon, .overdue, .done]

    /// "เลยกำหนด" has no chip of its own — it lands on ยังไม่เสร็จ plus the
    /// overdue-only filter (see `AssignmentListView.select(stat:)`).
    var chipTarget: TaskScope {
        self == .overdue ? .notDone : self
    }
}

/// Type filter inside TaskFilterSheet.
enum TaskKindFilter: String, CaseIterable, Identifiable {
    case all, homework, personal, exam

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "ทั้งหมด"
        case .homework: return AssignmentKind.homework.label
        case .personal: return AssignmentKind.personal.label
        case .exam: return AssignmentKind.exam.label
        }
    }

    func matches(_ assignment: Assignment) -> Bool {
        switch self {
        case .all: return true
        case .homework: return assignment.kind == .homework
        case .personal: return assignment.kind == .personal
        case .exam: return assignment.kind == .exam
        }
    }
}

/// Sort options inside TaskFilterSheet. Tasks with no due date always sort
/// last regardless of which one is picked.
enum TaskSortOrder: String, CaseIterable, Identifiable {
    case dueDate, priority, recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dueDate: return "กำหนดส่ง"
        case .priority: return "ความสำคัญ"
        case .recent: return "เพิ่งเพิ่ม"
        }
    }
}
