//
//  SOPEditorView.swift
//  เขียน SOP ของคณะหนึ่ง — การ์ดหัว · พื้นที่เขียนก้อนเดียว · คำแนะนำ 13 หัวข้อ
//
//  เขียนใหม่ 16 ส.ค. 2569 (รวม `TCASEntryDetailView` + `SOPEditorView` เดิมเข้าด้วยกัน):
//  · ตัดโหมด "เขียนทีละส่วน 6 ช่อง" ทิ้ง เหลือก้อนเดียวเสมอ
//  · ตัดการ์ดคะแนน · น้ำหนักวิชา · เป้าคะแนน · ลิงก์ระเบียบการ · โน้ต ออกทั้งหมด
//  · **autosave ระหว่างพิมพ์** (แบบเดียวกับ TermGradeEditView) จึงไม่มีปุ่ม "บันทึก"
//    และไม่มีกล่องถาม "ยังไม่ได้บันทึก" ตอนกดย้อนกลับอีกแล้ว
//

import SwiftUI
import SwiftData
import UIKit

struct SOPEditorView: View {
    @Bindable var target: SOPTarget
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var hasLoaded = false
    @State private var showGuide = false
    @State private var guideStartPage = 0
    @State private var showCopied = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerCard
                editorCard
                guideCard
                deleteButton
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("SOP")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadIfNeeded)
        .onChange(of: text) { _, _ in save() }
        .sheet(isPresented: $showGuide) {
            SOPGuideSheet(startPage: guideStartPage)
        }
        .alert("ลบคณะนี้?", isPresented: $isConfirmingDelete) {
            Button("ลบ", role: .destructive, action: deleteTarget)
            Button("ยกเลิก", role: .cancel) {}
        } message: {
            Text("\(target.universityName) — \(target.facultyLine)\nSOP ที่เขียนไว้จะถูกลบไปด้วย กู้คืนไม่ได้")
        }
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("คัดลอกแล้ว")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.onPrimary)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.primaryDeep, in: Capsule())
                    .padding(.bottom, Theme.Spacing.xxl)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: showCopied)
    }

    // MARK: - การ์ดหัว

    private var headerCard: some View {
        CardContainer {
            Text(target.universityName)
                .font(Theme.Font.plex(19, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(target.facultyLine)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - พื้นที่เขียน

    private var editorCard: some View {
        CardContainer {
            HStack {
                Text("เรียงความ SOP")
                    .font(Theme.Font.plex(15, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(text.count.formatted()) ตัวอักษร")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            TextEditor(text: $text)
                .font(Theme.Font.body)
                .frame(minHeight: 320)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("เริ่มเขียนได้เลย — อ่านคำแนะนำด้านล่างก่อนก็ได้")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.md)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Text("บันทึกอัตโนมัติ")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Button {
                    copyAll()
                } label: {
                    Label("คัดลอกทั้งฉบับ", systemImage: "doc.on.doc")
                        .font(Theme.Font.plex(13, .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.primaryDeep)
                .disabled(text.isEmpty)
            }
        }
    }

    // MARK: - คำแนะนำ

    private var guideCard: some View {
        CardContainer {
            Text("คำแนะนำการเขียน SOP")
                .font(Theme.Font.plex(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(SOPGuideContent.pages.enumerated()), id: \.offset) { index, page in
                Button {
                    guideStartPage = index
                    showGuide = true
                } label: {
                    HStack {
                        Text(page.title)
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Theme.Spacing.sm)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < SOPGuideContent.pages.count - 1 {
                    Divider()
                }
            }
        }
    }

    // MARK: - ลบคณะ

    /// ลบทั้งคณะ (SOP หายตาม cascade) แล้วปิดหน้า — ตัวเดียวกับกดค้างการ์ดในลิสต์
    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("ลบคณะนี้", systemImage: "trash")
                .font(Theme.Font.plex(15, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
        }
        .buttonStyle(.bordered)
        .tint(Theme.Colors.danger)
    }

    /// ปิดหน้าก่อนแล้วค่อยลบ — ลบทั้งที่ view ยังอ่าน `target` อยู่ = แตะ object
    /// ที่ถูกลบไปแล้ว (autosave ก็ยิงตามหลังได้อีก จึงมี `isDeleting` กันไว้ด้วย)
    private func deleteTarget() {
        let name = "\(target.universityName) · \(target.facultyLine)"
        isDeleting = true
        dismiss()
        Task { @MainActor in
            context.delete(target)
            try? context.save()
            AppLog.action("SOP", "ลบคณะจากหน้าเขียน: \(name)")
        }
    }

    // MARK: - ข้อมูล

    /// สร้าง `SOPDocument` ตอนเปิดหน้าเลย — ผู้ใช้ไม่ต้องเลือกโหมดอะไรอีกแล้ว
    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if let sop = target.sop {
            text = sop.fullText
        } else {
            let sop = SOPDocument(target: target)
            context.insert(sop)
            target.sopStore.append(sop)
            try? context.save()
        }
    }

    private func save() {
        guard hasLoaded, !isDeleting, let sop = target.sop else { return }
        guard sop.fullText != text else { return }
        sop.fullText = text
        sop.updatedAt = .now
        try? context.save()
    }

    private func copyAll() {
        UIPasteboard.general.string = text
        showCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showCopied = false
        }
    }
}

#Preview {
    NavigationStack {
        SOPEditorView(target: SOPTarget(universityName: "จุฬาลงกรณ์มหาวิทยาลัย",
                                        facultyName: "คณะวิศวกรรมศาสตร์",
                                        majorName: "คอมพิวเตอร์"))
    }
    .modelContainer(for: [SOPTarget.self, SOPDocument.self], inMemory: true)
}
