//
//  PortfolioView.swift
//  Portfolio Hub: เกียรติบัตร, กิจกรรม, จิตอาสา, การแข่งขัน, โปรเจกต์. Free feature.
//

import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Query(sort: \PortfolioItem.date, order: .reverse) private var items: [PortfolioItem]
    @Environment(\.modelContext) private var context
    @State private var isPresentingNew = false

    var body: some View {
        unlockedContent
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var unlockedContent: some View {
        List {
            ForEach(PortfolioCategory.allCases, id: \.self) { category in
                let categoryItems = items.filter { $0.category == category }
                if !categoryItems.isEmpty {
                    Section(category.label) {
                        ForEach(categoryItems) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Label(item.title, systemImage: category.icon)
                                    .font(.system(size: 14, weight: .medium))
                                Text(item.date.thaiShortString).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(categoryItems[i]) }
                        }
                    }
                }
            }
        }
        .overlay { if items.isEmpty { ContentUnavailableView("ยังไม่มีผลงาน", systemImage: "folder") } }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            NewPortfolioItemSheet()
        }
    }
}

private struct NewPortfolioItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var detail = ""
    @State private var category: PortfolioCategory = .activity
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                TextField("ชื่อผลงาน", text: $title)
                Picker("หมวดหมู่", selection: $category) {
                    ForEach(PortfolioCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                DatePicker("วันที่", selection: $date, displayedComponents: .date)
                TextField("รายละเอียด", text: $detail, axis: .vertical)
            }
            .navigationTitle("เพิ่มผลงาน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ยกเลิก") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        context.insert(PortfolioItem(title: title, detail: detail, category: category, date: date))
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { PortfolioView() }
        .modelContainer(for: PortfolioItem.self, inMemory: true)
}
