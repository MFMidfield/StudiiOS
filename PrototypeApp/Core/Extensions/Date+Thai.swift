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

    /// Days remaining until this date, from now, floored at 0.
    var daysRemaining: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: self)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, days)
    }
}
