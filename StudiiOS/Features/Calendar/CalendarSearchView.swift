//
//  CalendarSearchView.swift
//  ผลค้นหากิจกรรม/งาน จัดกลุ่มตามเดือน
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิม (`searchResultsList` / `searchResultRow`
//  / `groupedSearchResults`) มาตรงๆ ไม่เปลี่ยนพฤติกรรม
//

import SwiftUI

/// หน้าค้นหาแบบ sheet — หัวเดือน/ปีย้ายมาอยู่ในหน้าแล้ว (§3.2) จึงไม่มี
/// navigation bar ให้แปะ `.searchable` เหมือนเดิม ต้องเปิดเป็น sheet ของตัวเอง
struct CalendarSearchSheet: View {
    let calendar: Calendar
    let results: (String) -> [CalendarItem]
    let onSelect: (CalendarItem) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CalendarSearchView(
                searchText: query,
                results: results(query),
                calendar: calendar,
                onSelect: { item in
                    onSelect(item)
                    dismiss()
                }
            )
            .background(Theme.Colors.background)
            .navigationTitle("ค้นหา")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "ค้นหากิจกรรม การบ้าน วิชา")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
    }
}

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
