//
//  TCASEntry.swift
//  TCAS Planner (Pro feature): faculties/universities of interest, a
//  readiness checklist per entry, and an overall roadmap timeframe (ม.4–ม.6).
//

import Foundation
import SwiftData

@Model
final class TCASChecklistItem {
    var title: String
    var isDone: Bool
    var entry: TCASEntry?

    init(title: String, isDone: Bool = false, entry: TCASEntry? = nil) {
        self.title = title
        self.isDone = isDone
        self.entry = entry
    }
}

@Model
final class TCASEntry {
    var facultyName: String
    var universityName: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TCASChecklistItem.entry)
    var checklist: [TCASChecklistItem] = []

    var readinessPercent: Double {
        guard !checklist.isEmpty else { return 0 }
        let done = checklist.filter(\.isDone).count
        return Double(done) / Double(checklist.count)
    }

    init(
        facultyName: String,
        universityName: String,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.facultyName = facultyName
        self.universityName = universityName
        self.notes = notes
        self.createdAt = createdAt
    }
}
