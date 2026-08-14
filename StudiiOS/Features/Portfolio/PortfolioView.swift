//
//  PortfolioView.swift
//  Portfolio Hub: เกียรติบัตร, กิจกรรม, จิตอาสา, การแข่งขัน, โปรเจกต์. Free feature.
//

import SwiftUI
import SwiftData

struct PortfolioView: View {
    // Sorting happens in `visibleItems` instead of the query: the sort order is
    // user-switchable, and a dynamic @Query sort is more machinery than this needs.
    @Query private var items: [PortfolioItem]

    @Environment(\.modelContext) private var context
    @State private var isPresentingNew = false
    @State private var selectedCategory: PortfolioCategory?
    @State private var sortOrder: PortfolioSortOrder = .newestFirst
    @State private var searchText = ""
    @State private var detailItem: PortfolioItem?
    @State private var pendingDelete: PortfolioItem?
    @State private var isConfirmingDelete = false

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md)
    ]

    /// Fixed pipeline: category → search text → sort. Reordering these changes
    /// what the user sees.
    private var visibleItems: [PortfolioItem] {
        var result = items
        if let selectedCategory {
            result = result.filter { $0.category == selectedCategory }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.detail.localizedCaseInsensitiveContains(query)
            }
        }
        return sortOrder.sorted(result)
    }

    private var categoryCounts: [PortfolioCategory: Int] {
        Dictionary(grouping: items, by: \.category).mapValues(\.count)
    }

    var body: some View {
        content
            .navigationTitle("ผลงาน")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "ค้นหาชื่อหรือรายละเอียด")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { addButton }
            }
            .sheet(isPresented: $isPresentingNew) {
                PortfolioItemSheet(mode: .create)
            }
            .navigationDestination(for: PortfolioItem.self) { item in
                PortfolioDetailView(item: item)
            }
            .navigationDestination(item: $detailItem) { item in
                PortfolioDetailView(item: item)
            }
            .alert("ลบผลงานนี้?", isPresented: $isConfirmingDelete, presenting: pendingDelete) { item in
                Button("ลบ", role: .destructive) {
                    PortfolioItemActions.delete(item, in: context)
                    pendingDelete = nil
                }
                Button("ยกเลิก", role: .cancel) { pendingDelete = nil }
            } message: { _ in
                Text("การลบจะลบรูปภาพที่แนบไว้ทั้งหมดด้วย และไม่สามารถย้อนกลับได้")
            }
    }

    private var addButton: some View {
        Button {
            isPresentingNew = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("เพิ่มผลงาน")
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if selectedCategory == nil {
                        PortfolioSummaryCard(items: items)
                    }
                    filterRow
                    if visibleItems.isEmpty {
                        noMatchState
                    } else {
                        grid
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("ยังไม่มีผลงาน", systemImage: "folder")
        } description: {
            Text("เก็บเกียรติบัตร กิจกรรม จิตอาสา และโปรเจกต์ไว้ที่นี่\nพอถึงเวลายื่นพอร์ตรอบ 1 จะได้ไม่ต้องรื้อหาทีหลัง")
        } actions: {
            Button("เพิ่มผลงานชิ้นแรก") { isPresentingNew = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.primary)
        }
    }

    private var noMatchState: some View {
        Text("ไม่พบผลงานที่ตรงกับที่ค้นหา")
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xxl)
    }

    private var filterRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    chip(label: "ทั้งหมด", count: items.count, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(PortfolioCategory.allCases, id: \.self) { category in
                        chip(
                            label: category.label,
                            count: categoryCounts[category] ?? 0,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            sortMenu
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("เรียงลำดับ", selection: $sortOrder) {
                ForEach(PortfolioSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(Theme.Colors.primaryDeep)
        }
        .accessibilityLabel("เรียงลำดับ")
    }

    private func chip(
        label: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(label)
                    .font(Theme.Font.plex(13, isSelected ? .semibold : .regular))
                Text("\(count)")
                    .font(Theme.Font.plex(13, .semibold))
                    .contentTransition(.numericText())
                    .foregroundStyle(isSelected ? Theme.Colors.onPrimary : Theme.Colors.textPrimary)
            }
            .foregroundStyle(isSelected ? Theme.Colors.onPrimary : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Theme.Colors.separator, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(visibleItems) { item in
                NavigationLink(value: item) {
                    PortfolioCard(item: item)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("ดูรายละเอียด", systemImage: "eye") { detailItem = item }
                    Divider()
                    Button("ลบผลงาน", systemImage: "trash", role: .destructive) {
                        pendingDelete = item
                        isConfirmingDelete = true
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { PortfolioView() }
        .modelContainer(for: PortfolioItem.self, inMemory: true)
}
