//
//  PortfolioSortOrder.swift
//  Sort options for the portfolio grid. Sorting is applied in a computed property
//  on PortfolioView rather than in @Query, because the order is user-switchable
//  and a dynamic query sort is more machinery than this needs.
//

import Foundation

enum PortfolioSortOrder: String, CaseIterable, Identifiable {
    case newestFirst, oldestFirst, title, category

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newestFirst: return "ล่าสุดก่อน"
        case .oldestFirst: return "เก่าสุดก่อน"
        case .title: return "ชื่อ ก–ฮ"
        case .category: return "ตามหมวดหมู่"
        }
    }

    func sorted(_ items: [PortfolioItem]) -> [PortfolioItem] {
        switch self {
        case .newestFirst:
            return items.sorted { $0.startDate > $1.startDate }
        case .oldestFirst:
            return items.sorted { $0.startDate < $1.startDate }
        case .title:
            return items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .category:
            return items.sorted { lhs, rhs in
                let left = Self.index(of: lhs.category)
                let right = Self.index(of: rhs.category)
                if left != right { return left < right }
                return lhs.startDate > rhs.startDate
            }
        }
    }

    private static func index(of category: PortfolioCategory) -> Int {
        PortfolioCategory.allCases.firstIndex(of: category) ?? 0
    }
}
