//
//  Assignment.swift
//  Homework/tasks created manually or via Smart Capture. Drives the
//  Dashboard's "งานค้าง" / "งานที่ต้องส่งวันนี้".
//

import Foundation
import SwiftData

enum AssignmentPriority: String, Codable, CaseIterable {
    case low, medium, high

    var label: String {
        switch self {
        case .low: return "ต่ำ"
        case .medium: return "ปานกลาง"
        case .high: return "สูง"
        }
    }
}

/// Distinguishes school homework from personal to-dos. Both live in the same
/// model so the Todo screen can show one merged list.
enum AssignmentKind: String, Codable, CaseIterable {
    case homework, personal

    var label: String {
        switch self {
        case .homework: return "การบ้าน"
        case .personal: return "งานทั่วไป"
        }
    }

    var iconName: String {
        switch self {
        case .homework: return "book.closed.fill"
        case .personal: return "checkmark.circle.fill"
        }
    }
}

@Model
final class Assignment {
    var title: String
    var detail: String
    var dueDate: Date
    var isDone: Bool
    var priorityRaw: String
    var createdAt: Date
    var subjectName: String

    // MARK: - Fields added for the Todo redesign.
    // Every one needs a default value so SwiftData can backfill existing rows
    // without a migration (changing/removing an existing property would crash
    // on launch instead).
    var kindRaw: String = "homework"
    /// `false` means "ไม่กำหนดส่ง". Defaults to `true` because every row created
    /// before this field existed came from SmartCaptureView, which always set a
    /// due date — so backfilled rows keep showing their date.
    var hasDueDate: Bool = true
    /// `true` once the user picks a priority themselves; otherwise the priority
    /// is derived from due date + kind on every read.
    var isPriorityManual: Bool = false
    var remindersEnabled: Bool = false
    /// Stable id used to build notification identifiers. Filled lazily via
    /// `ensureUID()` rather than `UUID()` as a default value, because a default
    /// may be evaluated once during backfill and give every old row the same id.
    var uid: String = ""

    var priority: AssignmentPriority {
        get { AssignmentPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var kind: AssignmentKind {
        get { AssignmentKind(rawValue: kindRaw) ?? .homework }
        set { kindRaw = newValue.rawValue }
    }

    /// The real due date — `nil` when the task has none.
    /// Read this everywhere instead of `dueDate`.
    var resolvedDueDate: Date? { hasDueDate ? dueDate : nil }

    /// Priority to display and sort by. Never cache this into `priorityRaw`:
    /// the automatic value depends on today's date and would go stale.
    var effectivePriority: AssignmentPriority {
        isPriorityManual
            ? priority
            : AssignmentPriorityEngine.priority(kind: kind, dueDate: resolvedDueDate)
    }

    var isOverdue: Bool {
        guard !isDone, let due = resolvedDueDate else { return false }
        return due < .now
    }

    @discardableResult
    func ensureUID() -> String {
        if uid.isEmpty { uid = UUID().uuidString }
        return uid
    }

    init(
        title: String,
        detail: String = "",
        dueDate: Date = .now,
        isDone: Bool = false,
        priority: AssignmentPriority = .medium,
        createdAt: Date = .now,
        subjectName: String = "",
        kind: AssignmentKind = .homework,
        hasDueDate: Bool = true,
        isPriorityManual: Bool = false,
        remindersEnabled: Bool = false,
        uid: String = ""
    ) {
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.isDone = isDone
        self.priorityRaw = priority.rawValue
        self.createdAt = createdAt
        self.subjectName = subjectName
        self.kindRaw = kind.rawValue
        self.hasDueDate = hasDueDate
        self.isPriorityManual = isPriorityManual
        self.remindersEnabled = remindersEnabled
        self.uid = uid
    }
}
