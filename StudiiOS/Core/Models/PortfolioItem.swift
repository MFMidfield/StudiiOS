//
//  PortfolioItem.swift
//  Portfolio Hub (Pro feature): certificates, activities, volunteering,
//  competitions, projects.
//

import Foundation
import SwiftUI
import SwiftData

enum PortfolioCategory: String, Codable, CaseIterable {
    case certificate, activity, volunteer, competition, project

    var label: String {
        switch self {
        case .certificate: return "เกียรติบัตร"
        case .activity: return "กิจกรรม"
        case .volunteer: return "จิตอาสา"
        case .competition: return "การแข่งขัน"
        case .project: return "โปรเจกต์"
        }
    }

    var icon: String {
        switch self {
        case .certificate: return "rosette"
        case .activity: return "figure.walk"
        case .volunteer: return "heart.fill"
        case .competition: return "trophy.fill"
        case .project: return "hammer.fill"
        }
    }

    var color: Color {
        switch self {
        case .certificate: return Theme.Colors.warning
        case .activity: return Theme.Colors.primary
        case .volunteer: return Theme.Colors.pink
        case .competition: return Theme.Colors.danger
        case .project: return Theme.Colors.indigo
        }
    }
}

@Model
final class PortfolioItem {
    var title: String
    var detail: String
    var categoryRaw: String
    var startDate: Date
    var endDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \PortfolioImage.item)
    var images: [PortfolioImage] = []

    var category: PortfolioCategory {
        get { PortfolioCategory(rawValue: categoryRaw) ?? .activity }
        set { categoryRaw = newValue.rawValue }
    }

    /// First image by sortOrder — used as the grid/detail cover.
    var coverImage: PortfolioImage? {
        images.sorted { $0.sortOrder < $1.sortOrder }.first
    }

    /// "12 ส.ค. 2568" for a single day, "12 – 15 ส.ค. 2568" for a same-month range.
    var dateRangeText: String {
        guard let endDate else { return startDate.thaiDayMonthYearString }
        let sameMonth = Calendar.current.isDate(startDate, equalTo: endDate, toGranularity: .month)
        if sameMonth {
            return "\(startDate.thaiDayOnlyString) – \(endDate.thaiDayMonthYearString)"
        }
        return "\(startDate.thaiDayMonthYearString) – \(endDate.thaiDayMonthYearString)"
    }

    init(
        title: String,
        detail: String = "",
        category: PortfolioCategory,
        startDate: Date = .now,
        endDate: Date? = nil
    ) {
        self.title = title
        self.detail = detail
        self.categoryRaw = category.rawValue
        self.startDate = startDate
        self.endDate = endDate
    }
}
