//
//  PortfolioView.swift
//  Portfolio Hub: เกียรติบัตร, กิจกรรม, จิตอาสา, การแข่งขัน, โปรเจกต์. Free feature.
//

import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Query(sort: \PortfolioItem.startDate, order: .reverse) private var items: [PortfolioItem]
    @State private var isPresentingNew = false
    @State private var selectedCategory: PortfolioCategory?

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    private var filteredItems: [PortfolioItem] {
        guard let selectedCategory else { return items }
        return items.filter { $0.category == selectedCategory }
    }

    var body: some View {
        content
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isPresentingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $isPresentingNew) {
                PortfolioItemSheet(mode: .create)
            }
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            ContentUnavailableView(
                "ยังไม่มีผลงาน",
                systemImage: "folder",
                description: Text("กดปุ่ม + เพื่อเพิ่มผลงานชิ้นแรก")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    categoryChipRow
                    grid
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
        }
    }

    private var categoryChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                CategoryChip(label: "ทั้งหมด", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(PortfolioCategory.allCases, id: \.self) { category in
                    CategoryChip(label: category.label, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(filteredItems) { item in
                PortfolioCard(item: item)
            }
        }
    }
}

private struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(isSelected ? Theme.Colors.primary : Theme.Colors.cardBackground)
                .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                .clipShape(Capsule())
                .overlay {
                    if !isSelected {
                        Capsule().strokeBorder(Theme.Colors.separator, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { PortfolioView() }
        .modelContainer(for: PortfolioItem.self, inMemory: true)
}
