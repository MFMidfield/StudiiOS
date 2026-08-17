//
//  TaskScope.swift
//  The single definition of every "which tasks count" rule on the Todo screen.
//  The chips and the day grouping both read from here — never re-derive these
//  conditions anywhere else, or the two will drift apart.
//

import Foundation

enum TaskScope: String, CaseIterable, Identifiable {
    case all, notDone, dueSoon, overdue, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "ทั้งหมด"
        case .notDone: return "ค้าง"
        case .dueSoon: return "ใกล้ถึงกำหนด"
        case .overdue: return "เลยกำหนด"
        case .done: return "เสร็จ"
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

    /// The 4 chips across the top of the screen. `.dueSoon` stays in the enum
    /// (other code switches over it) but no longer has a chip of its own.
    static let chips: [TaskScope] = [.notDone, .overdue, .done, .all]

    /// "ทั้งหมด" is the only chip without a number — a total next to three
    /// subsets reads as a fourth subset.
    var showsCount: Bool { self != .all }
}

/// How the list is cut into day sections. The only place the "which day bucket"
/// rule is written — views ask for the group, they never compute days themselves.
enum TaskDayGroup: String, CaseIterable, Identifiable {
    case overdue, today, tomorrow, thisWeek, later, noDue

    var id: String { rawValue }

    static func group(for assignment: Assignment, now: Date = .now) -> TaskDayGroup {
        guard let due = assignment.resolvedDueDate else { return .noDue }
        switch AssignmentPriorityEngine.daysUntil(due, from: now) {
        case ..<0: return .overdue
        case 0: return .today
        case 1: return .tomorrow
        case 2...7: return .thisWeek
        default: return .later
        }
    }

    /// Header text. วันนี้/พรุ่งนี้ carry the date so the user doesn't have to
    /// know today's date to read the list.
    func title(now: Date = .now) -> String {
        switch self {
        case .overdue: return "เลยกำหนด"
        case .today: return "วันนี้ · \(now.thaiWeekdayDayMonthString)"
        case .tomorrow:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            return "พรุ่งนี้ · \(tomorrow.thaiWeekdayDayMonthString)"
        case .thisWeek: return "สัปดาห์นี้"
        case .later: return "ภายหลัง"
        case .noDue: return "ไม่มีกำหนด"
        }
    }

    /// Only the overdue header is tinted — everything else is plain text.
    var isAlarming: Bool { self == .overdue }
}

/// Type filter inside the toolbar's add-menu (long press on "+").
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
