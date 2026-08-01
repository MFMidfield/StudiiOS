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

@Model
final class Assignment {
    var title: String
    var detail: String
    var dueDate: Date
    var isDone: Bool
    var priorityRaw: String
    var createdAt: Date

    var priority: AssignmentPriority {
        get { AssignmentPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    init(
        title: String,
        detail: String = "",
        dueDate: Date = .now,
        isDone: Bool = false,
        priority: AssignmentPriority = .medium,
        createdAt: Date = .now
    ) {
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.isDone = isDone
        self.priorityRaw = priority.rawValue
        self.createdAt = createdAt
    }
}
