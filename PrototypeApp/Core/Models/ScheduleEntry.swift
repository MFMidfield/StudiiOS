//
//  ScheduleEntry.swift
//  "Thai School Schedule": normal class periods plus Thai-specific slots —
//  หน้าเสาธง, ชุมนุม, ลูกเสือ, แนะแนว, กิจกรรมโรงเรียน.
//

import Foundation
import SwiftData

enum ScheduleKind: String, Codable, CaseIterable {
    case classPeriod, flagCeremony, club, scout, guidance, schoolActivity

    var label: String {
        switch self {
        case .classPeriod: return "คาบเรียน"
        case .flagCeremony: return "หน้าเสาธง"
        case .club: return "ชุมนุม"
        case .scout: return "ลูกเสือ"
        case .guidance: return "แนะแนว"
        case .schoolActivity: return "กิจกรรมโรงเรียน"
        }
    }

    var icon: String {
        switch self {
        case .classPeriod: return "book.closed.fill"
        case .flagCeremony: return "flag.fill"
        case .club: return "person.3.fill"
        case .scout: return "figure.hiking"
        case .guidance: return "person.fill.questionmark"
        case .schoolActivity: return "star.fill"
        }
    }
}

@Model
final class ScheduleEntry {
    /// 1 = Monday ... 7 = Sunday
    var dayOfWeek: Int
    var startTime: Date
    var endTime: Date
    var kindRaw: String
    var location: String
    var subjectName: String

    var kind: ScheduleKind {
        get { ScheduleKind(rawValue: kindRaw) ?? .classPeriod }
        set { kindRaw = newValue.rawValue }
    }

    init(
        dayOfWeek: Int,
        startTime: Date,
        endTime: Date,
        kind: ScheduleKind = .classPeriod,
        location: String = "",
        subjectName: String = ""
    ) {
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.kindRaw = kind.rawValue
        self.location = location
        self.subjectName = subjectName
    }
}
