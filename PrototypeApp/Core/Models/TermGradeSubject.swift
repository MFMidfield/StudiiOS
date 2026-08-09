//
//  TermGradeSubject.swift
//  One subject's grade inside a term's "detailed" grade entry mode
//  (Term.usesDetailedGrades). Seeded from that term's ScheduleEntry rows the
//  first time detailed mode is turned on, then owns its own data from then on.
//
//  Deliberately separate from TermSubject: TermStore.syncTermSubjects can add
//  TermSubject rows automatically whenever the timetable changes, which is the
//  wrong trigger for something the student typed a grade into.
//

import Foundation
import SwiftData

@Model
final class TermGradeSubject {
    var id: UUID = UUID()
    var term: Term?
    var name: String = ""
    var code: String = ""
    var creditHours: Double = 1.0
    /// Thai 8-step scale: 0, 1, 1.5, 2, 2.5, 3, 3.5, 4.
    var gradePoint: Double = 2.5
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    init(
        term: Term?,
        name: String,
        code: String = "",
        creditHours: Double = 1.0,
        gradePoint: Double = 2.5,
        sortOrder: Int = 0,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.term = term
        self.name = name
        self.code = code
        self.creditHours = creditHours
        self.gradePoint = gradePoint
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
