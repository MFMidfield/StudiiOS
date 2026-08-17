//
//  TermSubject.swift
//  "This subject was taken in this term." Created automatically whenever a
//  ScheduleEntry for a subject is saved into a term (see TermStore.syncTermSubjects).
//  creditHours and gradePoint are filled in later by the GPA feature — this
//  round only creates the rows and leaves the numbers at their defaults.
//

import Foundation
import SwiftData

@Model
final class TermSubject {
    var term: Term?
    var subject: Subject?

    /// หน่วยกิต. 0 means "not entered yet".
    var creditHours: Double = 0
    /// Thai 0–4 scale. nil means "no grade yet".
    var gradePoint: Double?
    var createdAt: Date = Date.now

    init(term: Term?, subject: Subject?, creditHours: Double = 0, gradePoint: Double? = nil) {
        self.term = term
        self.subject = subject
        self.creditHours = creditHours
        self.gradePoint = gradePoint
    }
}
