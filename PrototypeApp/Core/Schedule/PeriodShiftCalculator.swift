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
    /// Break periods (`subject?.isBreak == true`) are never shifted — the cursor
    /// jumps to their real end time so periods after break resume correctly.
    static func apply(override: DayScheduleOverride?, to entries: [ScheduleEntry]) -> [ResolvedPeriod] {
        let sorted = entries.sorted { $0.startMinute < $1.startMinute }

        guard let override else {
            return sorted.map {
                ResolvedPeriod(entry: $0, startMinute: $0.startMinute, endMinute: $0.endMinute, isShifted: false)
            }
        }

        var cursor = override.startMinute
        var result: [ResolvedPeriod] = []

        for (index, entry) in sorted.enumerated() {
            if entry.subject?.isBreak == true {
                result.append(ResolvedPeriod(entry: entry, startMinute: entry.startMinute, endMinute: entry.endMinute, isShifted: false))
                cursor = entry.endMinute
                continue
            }

            let newStart = cursor
            let newEnd = cursor + override.periodLengthMinutes

            if newEnd > 1439 {
                AppLog.warn("Shift", "เวลาล้นเกินเที่ยงคืน หยุดร่นที่คาบ \(entry.periodNumber)")
                for remaining in sorted[index...] {
                    result.append(ResolvedPeriod(entry: remaining, startMinute: remaining.startMinute, endMinute: remaining.endMinute, isShifted: false))
                }
                return result
            }

            result.append(ResolvedPeriod(entry: entry, startMinute: newStart, endMinute: newEnd, isShifted: true))
            cursor = newEnd
        }

        return result
    }
}
