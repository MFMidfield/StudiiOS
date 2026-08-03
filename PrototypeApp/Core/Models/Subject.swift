//
//  Subject.swift
//  A class subject (or break slot) that ScheduleEntry rows attach to.
//  Replaces the old flat `subjectName` string with a reusable, colorable
//  entity shared across the timetable.
//

import SwiftUI
import SwiftData

@Model
final class Subject {
    var name: String
    var code: String
    var colorHex: String
    var iconName: String
    var isBreak: Bool
    var isBuiltIn: Bool
    var createdAt: Date

    var color: Color { Color(hex: colorHex) }

    init(
        name: String,
        code: String = "",
        colorHex: String = "4A7DFF",
        iconName: String = "book.closed.fill",
        isBreak: Bool = false,
        isBuiltIn: Bool = false,
        createdAt: Date = .now
    ) {
        self.name = name
        self.code = code
        self.colorHex = colorHex
        self.iconName = iconName
        self.isBreak = isBreak
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }
}
