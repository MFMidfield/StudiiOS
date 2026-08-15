//
//  CalendarSearchView.swift
//  ผลค้นหากิจกรรม/งาน จัดกลุ่มตามเดือน
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิม (`searchResultsList` / `searchResultRow`
//  / `groupedSearchResults`) มาตรงๆ ไม่เปลี่ยนพฤติกรรม
//

import SwiftUI

struct CalendarSearchView: View {
    let searchText: String
    let results: [CalendarItem]
    let calendar: Calendar
    let onSelect: (CalendarItem) -> Void

    private var groupedResults: [(month: String, items: [CalendarItem])] {
        let groups = Dictionary(grouping: results) { item -> Int in
            let c = calendar.dateComponents([.year, .month], from: item.date)
            return (c.year ?? 0) * 12 + (c.month ?? 0)
        }
        return groups.keys.sorted().compactMap { key in
            guard let items = groups[key], let first = items.first else { return nil }
            let c = calendar.dateComponents([.month, .year], from: first.date)
            let label = "\(CalendarStrings.thaiMonths[(c.month ?? 1) - 1]) \(c.year! + 543)"
            return (month: label, items: items)
        }
    }

    var body: some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedResults, id: \.month) { group in
                        Text(group.month)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 0) {
                            ForEach(group.items) { item in
                                CalendarItemRow(item: item) { onSelect(item) }
                            }
                        }
                        .background(Theme.Colors.cardBackground)
                    }
                }
            }
        }
    }
}
