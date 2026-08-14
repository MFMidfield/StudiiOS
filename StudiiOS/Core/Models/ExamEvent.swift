//
//  ExamEvent.swift
//  Exam schedule record.
//

import Foundation
import SwiftData

@Model
final class ExamEvent {
    var title: String
    var date: Date
    var location: String
    var notes: String

    init(
        title: String,
        date: Date,
        location: String = "",
        notes: String = ""
    ) {
        self.title = title
        self.date = date
        self.location = location
        self.notes = notes
    }
}
