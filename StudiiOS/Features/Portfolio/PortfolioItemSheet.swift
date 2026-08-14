//
//  PortfolioItemSheet.swift
//  Create/edit form for a single portfolio item. Picked images are staged
//  in memory and only written to disk + SwiftData on บันทึก, so backing out
//  with ยกเลิก never leaves orphan files.
//
//  Body is split into small private `var`s per section — a single flat
//  Form here type-checks slowly enough to trip the SwiftUI compiler timeout.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import VisionKit
import PDFKit

struct PortfolioItemSheet: View {
    enum Mode {
        case create
        case edit(PortfolioItem)
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var detail: String
    @State private var category: PortfolioCategory
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date

    @State private var existingImages: [PortfolioImage]
    @State private var removedImages: [PortfolioImage] = []
    @State private var pendingImages: [UIImage] = []
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var saveErrorMessage: String?

    @State private var isPresentingSourceDialog = false
    @State private var isPresentingPhotoPicker = false
    @State private var isPresentingScanner = false
    @State private var isPresentingCamera = false
    @State private var isPresentingFileImporter = false
    @State private var isScannerUnavailable = false
    @State private var isCameraUnavailable = false

    /// Called after a successful save — lets a presenting sheet (QuickAddSheet)
    /// close itself too instead of staying behind the form. `nil` everywhere
    /// else, so existing call sites are untouched.
    private let onSaved: (() -> Void)?

    init(mode: Mode, onSaved: (() -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create:
            _title = State(initialValue: "")
            _detail = State(initialValue: "")
            _category = State(initialValue: .activity)
            _startDate = State(initialValue: .now)
            _hasEndDate = State(initialValue: false)
            _endDate = State(initialValue: .now)
            _existingImages = State(initialValue: [])
        case .edit(let item):
            _title = State(initialValue: item.title)
            _detail = State(initialValue: item.detail)
            _category = State(initialValue: item.category)
            _startDate = State(initialValue: item.startDate)
            _hasEndDate = State(initialValue: item.endDate != nil)
            _endDate = State(initialValue: item.endDate ?? item.startDate)
            _existingImages = State(initialValue: item.images.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    private var isDateRangeValid: Bool {
        !hasEndDate || endDate >= startDate
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isDateRangeValid
    }

    var body: some View {
        NavigationStack {
            Form {
                imagesSection
                titleSection
                categorySection
                dateSection
                detailSection
            }
            .navigationTitle(mode.isCreate ? "เพิ่มผลงาน" : "แก้ไขผลงาน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("บันทึกไม่สำเร็จ", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("ตกลง", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .confirmationDialog("เพิ่มรูป", isPresented: $isPresentingSourceDialog, titleVisibility: .visible) {
                Button("สแกนเอกสาร") { presentScanner() }
                Button("ถ่ายรูป") { presentCamera() }
                Button("เลือกจากคลังรูป") { isPresentingPhotoPicker = true }
                Button("เลือกจากไฟล์") { isPresentingFileImporter = true }
                Button("ยกเลิก", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $isPresentingPhotoPicker,
                selection: $photosPickerItems,
                maxSelectionCount: nil,
                matching: .images
            )
            .onChange(of: photosPickerItems) { _, newItems in
                loadPickedImages(newItems)
            }
            .fullScreenCover(isPresented: $isPresentingScanner) {
                DocumentScannerView(
                    onScanned: { images in
                        pendingImages.append(contentsOf: images)
                        isPresentingScanner = false
                    },
                    onCancel: { isPresentingScanner = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isPresentingCamera) {
                ProfileImagePicker(source: .camera, allowsEditing: false) { image in
                    pendingImages.append(image)
                }
            }
            .fileImporter(
                isPresented: $isPresentingFileImporter,
                allowedContentTypes: [.image, .pdf],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .alert("สแกนเอกสารใช้ได้เฉพาะบนเครื่องจริง", isPresented: $isScannerUnavailable) {
                Button("ตกลง", role: .cancel) {}
            }
            .alert("ถ่ายรูปใช้ได้เฉพาะบนเครื่องจริง", isPresented: $isCameraUnavailable) {
                Button("ตกลง", role: .cancel) {}
            }
        }
    }

    // MARK: - Sections

    private var imagesSection: some View {
        Section("รูปผลงาน") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(existingImages, id: \.persistentModelID) { image in
                        ExistingImageThumbnail(image: image) { removeExisting(image) }
                    }
                    ForEach(Array(pendingImages.enumerated()), id: \.offset) { offset, image in
                        PendingImageThumbnail(image: image) { pendingImages.remove(at: offset) }
                    }
                    Button {
                        isPresentingSourceDialog = true
                    } label: {
                        addImageCell
                    }
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
    }

    private var addImageCell: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.control)
            .strokeBorder(Theme.Colors.separator, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            .frame(width: 80, height: 80)
            .overlay {
                VStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("เพิ่มรูป")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Theme.Colors.textSecondary)
            }
    }

    private var titleSection: some View {
        Section {
            TextField("ชื่อกิจกรรม", text: $title)
        }
    }

    private var categorySection: some View {
        Section {
            Picker("หมวดหมู่", selection: $category) {
                ForEach(PortfolioCategory.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("วันที่เริ่ม", selection: $startDate, displayedComponents: .date)
            Toggle("กิจกรรมหลายวัน", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("วันที่สิ้นสุด", selection: $endDate, displayedComponents: .date)
                if !isDateRangeValid {
                    Text("วันที่สิ้นสุดต้องอยู่หลังวันที่เริ่ม")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.danger)
                }
            }
        }
    }

    private var detailSection: some View {
        Section("รายละเอียด") {
            TextField("รายละเอียด", text: $detail, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    // MARK: - Actions

    private func removeExisting(_ image: PortfolioImage) {
        existingImages.removeAll { $0.persistentModelID == image.persistentModelID }
        removedImages.append(image)
    }

    private func presentScanner() {
        if VNDocumentCameraViewController.isSupported {
            isPresentingScanner = true
        } else {
            isScannerUnavailable = true
        }
    }

    private func presentCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isPresentingCamera = true
        } else {
            isCameraUnavailable = true
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            if url.pathExtension.lowercased() == "pdf" {
                if let image = Self.renderFirstPage(ofPDFAt: url) {
                    pendingImages.append(image)
                }
            } else if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                pendingImages.append(image)
            }
        }
    }

    private static func renderFirstPage(ofPDFAt url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    private func loadPickedImages(_ items: [PhotosPickerItem]) {
        Task {
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loaded.append(image)
                }
            }
            pendingImages.append(contentsOf: loaded)
            photosPickerItems = []
        }
    }

    private func save() {
        let targetItem: PortfolioItem
        switch mode {
        case .create:
            targetItem = PortfolioItem(
                title: title,
                detail: detail,
                category: category,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil
            )
            context.insert(targetItem)
        case .edit(let item):
            item.title = title
            item.detail = detail
            item.category = category
            item.startDate = startDate
            item.endDate = hasEndDate ? endDate : nil
            targetItem = item
        }

        for removed in removedImages {
            PortfolioImageStore.delete(removed.filename)
            context.delete(removed)
        }

        var nextSortOrder = (existingImages.map(\.sortOrder).max() ?? -1) + 1
        for image in pendingImages {
            do {
                let filename = try PortfolioImageStore.save(image)
                let portfolioImage = PortfolioImage(filename: filename, sortOrder: nextSortOrder)
                portfolioImage.item = targetItem
                context.insert(portfolioImage)
                nextSortOrder += 1
            } catch {
                saveErrorMessage = "บันทึกรูปไม่สำเร็จ ลองใหม่อีกครั้ง"
                return
            }
        }

        try? context.save()
        dismiss()
        onSaved?()
    }
}

private extension PortfolioItemSheet.Mode {
    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}

private struct ExistingImageThumbnail: View {
    let image: PortfolioImage
    let onRemove: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Colors.background)
                .frame(width: 80, height: 80)
                .overlay {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

            removeButton
        }
        .task {
            thumbnail = PortfolioImageStore.loadThumbnail(image.filename)
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.white, Color.black.opacity(0.6))
        }
        .padding(4)
    }
}

private struct PendingImageThumbnail: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

            removeButton
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.white, Color.black.opacity(0.6))
        }
        .padding(4)
    }
}

#Preview {
    PortfolioItemSheet(mode: .create)
        .modelContainer(for: PortfolioItem.self, inMemory: true)
}
