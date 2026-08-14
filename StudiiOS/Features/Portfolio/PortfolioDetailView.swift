//
//  PortfolioDetailView.swift
//  Full detail for one PortfolioItem: swipeable image gallery, fields,
//  edit (reuses PortfolioItemSheet.Mode.edit), and delete (rows + files).
//

import SwiftUI
import SwiftData
import UIKit

struct PortfolioDetailView: View {
    let item: PortfolioItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingEdit = false
    @State private var isPresentingDeleteConfirm = false

    private var sortedImages: [PortfolioImage] {
        item.images.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if !sortedImages.isEmpty {
                    gallery
                }
                Text(item.title)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: Theme.Spacing.sm) {
                    categoryPill
                    Text(item.dateRangeText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                deleteButton
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("แก้ไข") { isPresentingEdit = true }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            PortfolioItemSheet(mode: .edit(item))
        }
        .alert("ลบผลงานนี้?", isPresented: $isPresentingDeleteConfirm) {
            Button("ลบ", role: .destructive) { deleteItem() }
            Button("ยกเลิก", role: .cancel) {}
        } message: {
            Text("การลบจะลบรูปภาพที่แนบไว้ทั้งหมดด้วย และไม่สามารถย้อนกลับได้")
        }
    }

    private var gallery: some View {
        TabView {
            ForEach(sortedImages, id: \.persistentModelID) { image in
                GalleryPage(image: image)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private var categoryPill: some View {
        Text(item.category.label)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(item.category.color.opacity(0.15))
            .foregroundStyle(item.category.color)
            .clipShape(Capsule())
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isPresentingDeleteConfirm = true
        } label: {
            Label("ลบผลงาน", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Theme.Colors.danger)
        .padding(.top, Theme.Spacing.md)
    }

    private func deleteItem() {
        for image in item.images {
            PortfolioImageStore.delete(image.filename)
        }
        context.delete(item)
        try? context.save()
        dismiss()
    }
}

private struct GalleryPage: View {
    let image: PortfolioImage
    @State private var fullImage: UIImage?

    var body: some View {
        ZStack {
            Theme.Colors.background
            if let fullImage {
                Image(uiImage: fullImage)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .task {
            fullImage = PortfolioImageStore.load(image.filename)
        }
    }
}
