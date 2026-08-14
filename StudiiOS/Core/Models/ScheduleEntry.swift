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
    var term: Term?

    init(
        dayOfWeek: Int,
        startMinute: Int,
        endMinute: Int,
        periodNumber: Int = 0,
        teacherName: String = "",
        location: String = "",
        subjectName: String = "",
        subject: Subject? = nil,
        term: Term? = nil
    ) {
        self.dayOfWeek = dayOfWeek
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.periodNumber = periodNumber
        self.teacherName = teacherName
        self.location = location
        self.subjectName = subjectName
        self.subject = subject
        self.term = term
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

    /// The same clock time as a `Date` on today, which is the only shape
    /// `DatePicker(displayedComponents: .hourAndMinute)` accepts. The date part
    /// is meaningless and is thrown away again by `minutesFromMidnight`.
    var asClockDate: Date {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: self, to: midnight) ?? midnight
    }
}

extension Date {
    /// Clock time of this date as minutes from midnight — the inverse of
    /// `Int.asClockDate`. Declared here so every schedule form converts the
    /// same way instead of each rolling its own `dateComponents` call.
    var minutesFromMidnight: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
