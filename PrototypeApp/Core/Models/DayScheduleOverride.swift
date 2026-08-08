//
//  DayScheduleOverride.swift
//  A per-day "shortened periods" override for the timetable. When present
//  for a given date, ScheduleView recomputes that day's period times as
//  back-to-back slots starting at `startMinute`, each `periodLengthMinutes`
//  long — without touching the underlying ScheduleEntry rows. Deleting the
//  override fully restores the original schedule.
//
//  The shift starts at `startPeriodNumber`: rows printed before that period
//  are hidden for the day (on a shortened day the assembly/homeroom before
//  the first real period does not happen at all), and every row from there on
//  is shifted — breaks included, shrunk to `periodLengthMinutes` like any
//  other row.
//

import Foundation
import SwiftData

@Model
final class DayScheduleOverride {
    var date: Date
    /// The period number the shift is anchored to. Default value present so
    /// SwiftData can migrate stores written before this property existed.
    var startPeriodNumber: Int = 1
    var startMinute: Int
    var periodLengthMinutes: Int
    var createdAt: Date

    init(
        date: Date,
        startPeriodNumber: Int = 1,
        startMinute: Int,
        periodLengthMinutes: Int,
        createdAt: Date = .now
    ) {
        self.date = DayScheduleOverride.normalizedDate(date)
        self.startPeriodNumber = startPeriodNumber
        self.startMinute = startMinute
        self.periodLengthMinutes = periodLengthMinutes
        self.createdAt = createdAt
    }

    static func normalizedDate(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }
}
