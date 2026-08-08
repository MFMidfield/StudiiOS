//
//  PeriodShiftCalculator.swift
//  Pure calculation layer for the "shorten today's periods" feature — no
//  View code. Never mutates ScheduleEntry; a DayScheduleOverride is a
//  display-time layer computed fresh every time, so deleting the override
//  restores the original schedule exactly.
//

import Foundation
import SwiftData

struct ResolvedPeriod: Identifiable {
    let entry: ScheduleEntry
    let startMinute: Int
    let endMinute: Int
    let isShifted: Bool

    var id: PersistentIdentifier { entry.persistentModelID }
}

enum PeriodShiftCalculator {
    /// The calendar date for `day` (1=Monday...7=Sunday) within the week containing `week`.
    static func date(forDay day: Int, in week: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: week) // 1=Sun...7=Sat
        let mondayBasedToday = weekday == 1 ? 7 : weekday - 1 // 1=Mon...7=Sun
        let delta = day - mondayBasedToday
        return cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: week)) ?? week
    }

    /// Recomputes display times for `entries` given a (possibly nil) shift override.
    ///
    /// With an override in place:
    /// - rows printed *before* `override.startPeriodNumber` are dropped from the
    ///   result — they are not rendered at all that day;
    /// - every row from the anchor onward is laid back-to-back starting at
    ///   `override.startMinute`, each `override.periodLengthMinutes` long;
    /// - breaks are shifted and shrunk like any other row. A shortened day
    ///   shortens lunch too.
    ///
    /// The returned times are display-only. `ScheduleEntry` is never mutated,
    /// so deleting the override restores the day exactly.
    static func apply(override: DayScheduleOverride?, to entries: [ScheduleEntry]) -> [ResolvedPeriod] {
        let sorted = entries.sorted { $0.startMinute < $1.startMinute }

        guard let override else {
            return sorted.map {
                ResolvedPeriod(entry: $0, startMinute: $0.startMinute, endMinute: $0.endMinute, isShifted: false)
            }
        }

        // Where the shift starts. An exact period-number match is what the user
        // picked; the >= fallback keeps the day visible if that row was deleted
        // after the override was saved, instead of silently hiding everything.
        let wanted: Int = override.startPeriodNumber
        let exact: Int? = sorted.firstIndex { $0.periodNumber == wanted }
        let orLater: Int? = sorted.firstIndex { $0.periodNumber >= wanted }
        let anchor: Int = exact ?? orLater ?? 0

        var cursor = override.startMinute
        var result: [ResolvedPeriod] = []

        for (offset, entry) in sorted[anchor...].enumerated() {
            let newEnd = cursor + override.periodLengthMinutes

            if newEnd > 1439 {
                AppLog.warn("Shift", "เวลาล้นเกินเที่ยงคืน หยุดร่นที่คาบ \(entry.periodNumber)")
                // Keep the remaining rows visible at their original times rather
                // than dropping them — losing rows reads as data loss.
                for remaining in sorted[(anchor + offset)...] {
                    result.append(ResolvedPeriod(entry: remaining, startMinute: remaining.startMinute, endMinute: remaining.endMinute, isShifted: false))
                }
                return result
            }

            result.append(ResolvedPeriod(entry: entry, startMinute: cursor, endMinute: newEnd, isShifted: true))
            cursor = newEnd
        }

        return result
    }
}
