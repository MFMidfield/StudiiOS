//
//  PortfolioSearchSheet.swift
//  หน้าค้นหาผลงาน — เปิดจากปุ่มแว่นขยายข้างปุ่ม + ของ PortfolioView
//
//  แยกเป็น sheet ด้วยเหตุผลเดียวกับ TaskSearchSheet / CalendarSearchSheet:
//  `.searchable` ที่แปะบนหน้าในแท็บจะไปโผล่เป็นแท็บค้นหาที่แถบล่างบน iOS 26
//
//  รายละเอียดผลงาน push อยู่ใน NavigationStack ของ sheet เอง ไม่ต้องปิด sheet ก่อน
//

import SwiftUI

struct PortfolioSearchSheet: View {
    let items: [PortfolioItem]

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [PortfolioItem] {
        let needle = trimmedQuery
        guard !needle.isEmpty else { return [] }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(needle)
                || $0.detail.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .background(Theme.Colors.background)
                .navigationTitle("ค้นหาผลงาน")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "ค้นหาชื่อหรือรายละเอียด"
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("ปิด") { dismiss() }
                    }
                }
                .navigationDestination(for: PortfolioItem.self) { item in
                    PortfolioDetailView(item: item)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if trimmedQuery.isEmpty {
            ContentUnavailableView(
                "ค้นหาผลงาน",
                systemImage: "magnifyingglass",
                description: Text("พิมพ์ชื่อผลงานหรือรายละเอียดที่จำได้")
            )
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                    ForEach(results) { item in
                        NavigationLink(value: item) {
                            PortfolioCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }
}
