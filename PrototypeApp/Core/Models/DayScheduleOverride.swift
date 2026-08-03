//
//  DayScheduleOverride.swift
//  A per-day "shortened periods" override for the timetable. When present
//  for a given date, ScheduleView recomputes that day's period times as
//  back-to-back slots starting at `startMinute`, each `periodLengthMinutes`
//  long — without touching the underlying ScheduleEntry rows. Deleting the
//  override fully restores the original schedule.
//

import Foundation
import SwiftData

@Model
final class DayScheduleOverride {
    var date: Date
    var startMinute: Int
    var periodLengthMinutes: Int
    var createdAt: Date

    init(
        date: Date,
        startMinute: Int,
        periodLengthMinutes: Int,
        createdAt: Date = .now
    ) {
        self.date = DayScheduleOverride.normalizedDate(date)
        self.startMinute = startMinute
        self.periodLengthMinutes = periodLengthMinutes
        self.createdAt = createdAt
    }

    static func normalizedDate(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }
}
