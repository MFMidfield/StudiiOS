//
//  PortfolioItem.swift
//  Portfolio Hub (Pro feature): certificates, activities, volunteering,
//  competitions, projects.
//

import Foundation
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
}

@Model
final class PortfolioItem {
    var title: String
    var detail: String
    var categoryRaw: String
    var date: Date

    var category: PortfolioCategory {
        get { PortfolioCategory(rawValue: categoryRaw) ?? .activity }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        title: String,
        detail: String = "",
        category: PortfolioCategory,
        date: Date = .now
    ) {
        self.title = title
        self.detail = detail
        self.categoryRaw = category.rawValue
        self.date = date
    }
}
