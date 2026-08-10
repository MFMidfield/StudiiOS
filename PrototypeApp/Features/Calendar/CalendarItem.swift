//
//  CalendarItem.swift
//  Unifies CalendarEvent + Assignment (homework/personal/exam) into one
//  displayable row so the month grid and the day list below it only ever
//  deal with one shape, not three.
//

import Foundation
import SwiftUI

enum CalendarItemKind {
    case event, homework, personal, exam
}

struct CalendarItem: Identifiable {
    let id: String
    let kind: CalendarItemKind
    let title: String
    /// Text shown inside the month-grid pill — subject name when available
    /// (shorter than the full title), otherwise falls back to `title`.
    let shortLabel: String
    let date: Date
    let isAllDay: Bool
    let color: Color
    let isDone: Bool
    let sourceEvent: CalendarEvent?
    let sourceTask: Assignment?

    /// สอบ → การบ้าน/งานทั่วไป → กิจกรรม — ลำดับที่ pill ในช่องวันใช้จัดเรียง
    var sortRank: Int {
        switch kind {
        case .exam: return 0
        case .homework: return 1
        case .personal: return 2
        case .event: return 3
        }
    }
}
