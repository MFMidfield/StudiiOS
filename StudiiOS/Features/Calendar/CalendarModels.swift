//
//  CalendarModels.swift
//  @Model types for the Calendar feature — split out of CalendarView.swift
//  (10 ส.ค. 2569, ก่อน Round 4 Ghost Event) to keep that file small enough
//  for the type-checker.
//

import SwiftUI
import SwiftData

enum EventAlert: String, Codable, CaseIterable, Identifiable {
    case none, atTime, fiveMin, fifteenMin, thirtyMin, oneHour, oneDay, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:       "ไม่แจ้งเตือน"
        case .atTime:     "ตอนเริ่มกิจกรรม"
        case .fiveMin:    "5 นาทีก่อน"
        case .fifteenMin: "15 นาทีก่อน"
        case .thirtyMin:  "30 นาทีก่อน"
        case .oneHour:    "1 ชั่วโมงก่อน"
        case .oneDay:     "1 วันก่อน"
        case .custom:     "กำหนดเอง"
        }
    }
}

@Model
final class CalendarTag {
    var name: String
    var colorHex: String
    var events: [CalendarEvent] = []

    init(name: String, colorHex: String = "E1802F") {
        self.name = name
        self.colorHex = colorHex
    }
}

@Model
final class CalendarAttachmentItem {
    var filename: String
    var urlString: String
    var fileType: String
    var event: CalendarEvent?

    init(filename: String, urlString: String, fileType: String) {
        self.filename = filename
        self.urlString = urlString
        self.fileType = fileType
    }
}

@Model
final class CalendarEvent {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String
    var alertRaw: String
    var customAlertMinutes: Int
    var notes: String
    var urlString: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date
    var subjectName: String = ""

    @Relationship(deleteRule: .cascade, inverse: \CalendarAttachmentItem.event)
    var attachments: [CalendarAttachmentItem] = []

    @Relationship(inverse: \CalendarTag.events)
    var tags: [CalendarTag] = []

    var alert: EventAlert {
        get { EventAlert(rawValue: alertRaw) ?? .none }
        set { alertRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = true,
        location: String = "",
        alert: EventAlert = .none,
        customAlertMinutes: Int = 10,
        notes: String = "",
        urlString: String = "",
        colorHex: String = "E1802F",
        subjectName: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.alertRaw = alert.rawValue
        self.customAlertMinutes = customAlertMinutes
        self.notes = notes
        self.urlString = urlString
        self.colorHex = colorHex
        self.createdAt = .now
        self.updatedAt = .now
        self.subjectName = subjectName
    }
}
