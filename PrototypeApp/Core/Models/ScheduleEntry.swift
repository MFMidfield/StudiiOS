//
//  ScheduleEntry.swift
//  A single weekly class period. Times are stored as minutes-from-midnight
//  (not Date) so they compare cleanly within a day and are easy to
//  recompute when a day's periods are shortened (see DayScheduleOverride).
//

import Foundation
import SwiftData

@Model
final class ScheduleEntry {
    /// 1 = Monday ... 7 = Sunday
    var dayOfWeek: Int
    var startMinute: Int
    var endMinute: Int
    var periodNumber: Int
    var teacherName: String
    var location: String
    var subjectName: String

    var subject: Subject?

    init(
        dayOfWeek: Int,
        startMinute: Int,
        endMinute: Int,
        periodNumber: Int = 0,
        teacherName: String = "",
        location: String = "",
        subjectName: String = "",
        subject: Subject? = nil
    ) {
        self.dayOfWeek = dayOfWeek
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.periodNumber = periodNumber
        self.teacherName = teacherName
        self.location = location
        self.subjectName = subjectName
        self.subject = subject
    }
}

extension Int {
    /// Formats minutes-from-midnight as "08:00".
    var asClockString: String {
        let h = self / 60
        let m = self % 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Parses a "08:00" string into minutes-from-midnight, or nil if malformed.
    static func minutesFromClockString(_ text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
