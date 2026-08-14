//
//  Date+Thai.swift
//  Thai (Buddhist calendar) date formatting helpers shared across modules.
//

import Foundation

extension DateFormatter {
    static let thaiFull: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateStyle = .full
        f.calendar = Calendar(identifier: .buddhist)
        return f
    }()

    static let thaiShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateFormat = "d MMM yy"
        f.calendar = Calendar(identifier: .buddhist)
        return f
    }()

    static let thaiShortNoYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateFormat = "d MMM"
        f.calendar = Calendar(identifier: .buddhist)
        return f
    }()

    static let thaiDayMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateFormat = "d MMM yyyy"
        f.calendar = Calendar(identifier: .buddhist)
        return f
    }()

    static let thaiDayOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateFormat = "d"
        f.calendar = Calendar(identifier: .buddhist)
        return f
    }()

    /// Abbreviated Thai weekday — "จ." "อ." "พ." — for due dates inside this week.
    static let thaiWeekdayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateFormat = "EEE"
        f.calendar = Calendar(identifier: .buddhist)
        return f
    }()

    /// Weekday + day + month — "พฤ 13 ส.ค." — for the day-group headers on the
    /// task list. `thaiFull` is too long to sit above a list of rows.
    static let thaiWeekdayDayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.dateFormat = "EEE d MMM"
        f.calendar = Calendar(identifier: .buddhist)
        return f
    }()

    static let time24h: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

extension Date {
    var thaiFullString: String { DateFormatter.thaiFull.string(from: self) }
    var thaiShortString: String { DateFormatter.thaiShort.string(from: self) }
    var thaiShortNoYearString: String { DateFormatter.thaiShortNoYear.string(from: self) }
    var thaiDayMonthYearString: String { DateFormatter.thaiDayMonthYear.string(from: self) }
    var thaiDayOnlyString: String { DateFormatter.thaiDayOnly.string(from: self) }
    var thaiWeekdayDayMonthString: String { DateFormatter.thaiWeekdayDayMonth.string(from: self) }

    /// Short human label for a deadline: "เลย 2 วัน" · "วันนี้" · "พรุ่งนี้" ·
    /// "ศ." for the rest of this week · "12 ก.ย." beyond that.
    /// The caller picks the color — see `PillLabel.Tone`.
    var thaiDueLabel: String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: self)).day ?? 0
        switch days {
        case ..<0: return "เลย \(-days) วัน"
        case 0: return "วันนี้"
        case 1: return "พรุ่งนี้"
        case 2...6: return DateFormatter.thaiWeekdayShort.string(from: self)
        default: return thaiShortNoYearString
        }
    }

    /// Days remaining until this date, from now, floored at 0.
    var daysRemaining: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: self)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, days)
    }
}
