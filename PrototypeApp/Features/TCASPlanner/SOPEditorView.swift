//
//  SOPEditorView.swift
//  เขียน SOP ของ 1 คณะ — เลือกโหมด "ก้อนเดียว"/"6 ช่อง" ตอนเริ่มครั้งแรกเท่านั้น (§5.1)
//  โหมด 6 ช่องกด "รวมเป็นฉบับเดียว" แล้ว isMerged = true ถาวร กลับไปแก้ทีละส่วนไม่ได้อีก
//  ปุ่ม "บันทึก" มุมขวาบนเขียนค่าลง TCASSOP ตรงๆ — ไม่ autosave ระหว่างพิมพ์
//

import SwiftUI
import SwiftData
import UIKit

struct SOPEditorView: View {
    @Bindable var entry: TCASEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var hasLoaded = false
    @State private var fullText = ""
    @State private var s1 = ""
    @State private var s2 = ""
    @State private var s3 = ""
    @State private var s4 = ""
    @State private var s5 = ""
    @State private var s6 = ""
    @State private var isDirty = false

    @State private var showUnsavedDialog = false
    @State private var showMergeConfirm = false
    @State private var showGuide = false
    @State private var guideStartPage = 0
    @State private var showCopiedToast = false

    var body: some View {
        Group {
            if let sop = entry.sop {
                content(sop: sop)
            } else {
                modePicker
            }
        }
        .navigationTitle("SOP")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - ยังไม่เลือกโหมด (ครั้งแรกเท่านั้น)

    private var modePicker: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Text("เริ่มเขียน SOP ยังไงดี?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    startSOP(modeRaw: "sections")
                } label: {
                    Text("เขียนทีละส่วน (6 ช่อง)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    startSOP(modeRaw: "single")
                } label: {
                    Text("เขียนก้อนเดียว")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Text("เลือกได้ครั้งเดียวตอนเริ่ม — โหมด 6 ช่องกด \"รวมเป็นฉบับเดียว\" ทีหลังได้")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }

    private func startSOP(modeRaw: String) {
        let sop = TCASSOP(modeRaw: modeRaw, entry: entry)
        context.insert(sop)
        entry.sopStore.append(sop)
    }

    // MARK: - เนื้อหา

    @ViewBuilder
    private func content(sop: TCASSOP) -> some View {
        List {
            if sop.modeRaw == "sections" && !sop.isMerged {
                sectionsEditor
                Section {
                    Button("รวมเป็นฉบับเดียว") { showMergeConfirm = true }
                }
            } else {
                Section {
                    TextEditor(text: $fullText)
                        .frame(minHeight: 320)
                        .onChange(of: fullText) { _, _ in isDirty = true }
                }
            }

            Section {
                HStack {
                    Text("\(characterCount(sop: sop)) ตัวอักษร")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Button {
                        copyAll(sop: sop)
                    } label: {
                        Label("คัดลอกทั้งฉบับ", systemImage: "doc.on.doc")
                    }
                }
            }

            Section("คำแนะนำการเขียน SOP") {
                ForEach(Array(SOPGuideContent.pages.enumerated()), id: \.offset) { index, page in
                    Button {
                        guideStartPage = index
                        showGuide = true
                    } label: {
                        HStack {
                            Text(page.title)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
        .onAppear { loadIfNeeded(sop: sop) }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("บันทึก") { save(sop: sop) }
            }
        }
        .alert("รวมเป็นฉบับเดียว?", isPresented: $showMergeConfirm) {
            Button("รวมเลย", role: .destructive) { merge(sop: sop) }
            Button("ยกเลิก", role: .cancel) {}
        } message: {
            Text("รวมแล้วจะกลับไปแก้ทีละส่วนไม่ได้อีก ข้อความที่แยกไว้ 6 ช่องจะกลายเป็นเรียงความก้อนเดียว แก้ต่อได้เฉพาะแบบก้อนเดียวเท่านั้น")
        }
        .confirmationDialog(
            "ยังไม่ได้บันทึก",
            isPresented: $showUnsavedDialog,
            titleVisibility: .visible
        ) {
            Button("บันทึกแล้วออก") { save(sop: sop); dismiss() }
            Button("ออกโดยไม่บันทึก", role: .destructive) { dismiss() }
            Button("ยกเลิก", role: .cancel) {}
        }
        .sheet(isPresented: $showGuide) {
            SOPGuideSheet(startPage: guideStartPage)
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("คัดลอกแล้ว")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.textPrimary)
                    .clipShape(Capsule())
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    private var sectionsEditor: some View {
        Group {
            sectionField(title: "1. บทนำ", text: $s1)
            sectionField(title: "2. พื้นฐานการศึกษา", text: $s2)
            sectionField(title: "3. ผลงานและประสบการณ์", text: $s3)
            sectionField(title: "4. ทำไมต้องที่นี่", text: $s4)
            sectionField(title: "5. เป้าหมายในอนาคต", text: $s5)
            sectionField(title: "6. บทสรุป", text: $s6)
        }
    }

    private func sectionField(title: String, text: Binding<String>) -> some View {
        Section(title) {
            TextEditor(text: text)
                .frame(minHeight: 100)
                .onChange(of: text.wrappedValue) { _, _ in isDirty = true }
        }
    }

    // MARK: - Logic

    private func loadIfNeeded(sop: TCASSOP) {
        guard !hasLoaded else { return }
        fullText = sop.fullText
        s1 = sop.s1Intro
        s2 = sop.s2Academic
        s3 = sop.s3Projects
        s4 = sop.s4WhyHere
        s5 = sop.s5Future
        s6 = sop.s6Conclusion
        hasLoaded = true
    }

    /// เรียงความล้วน ไม่มีหัวข้อกำกับ — 6 ส่วนคั่นด้วย \n\n ข้ามช่องที่ว่าง (§5.1)
    private var assembledSections: String {
        [s1, s2, s3, s4, s5, s6]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    private func characterCount(sop: TCASSOP) -> Int {
        (sop.modeRaw == "sections" && !sop.isMerged)
            ? assembledSections.count
            : fullText.count
    }

    private func save(sop: TCASSOP) {
        if sop.modeRaw == "sections" && !sop.isMerged {
            sop.s1Intro = s1
            sop.s2Academic = s2
            sop.s3Projects = s3
            sop.s4WhyHere = s4
            sop.s5Future = s5
            sop.s6Conclusion = s6
        } else {
            sop.fullText = fullText
        }
        sop.updatedAt = Date.now
        isDirty = false
    }

    private func merge(sop: TCASSOP) {
        sop.s1Intro = s1
        sop.s2Academic = s2
        sop.s3Projects = s3
        sop.s4WhyHere = s4
        sop.s5Future = s5
        sop.s6Conclusion = s6
        sop.fullText = assembledSections
        sop.isMerged = true
        sop.updatedAt = Date.now
        fullText = sop.fullText
        isDirty = false
    }

    private func copyAll(sop: TCASSOP) {
        let text = (sop.modeRaw == "sections" && !sop.isMerged) ? assembledSections : fullText
        UIPasteboard.general.string = text
        withAnimation { showCopiedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showCopiedToast = false }
        }
    }

    private func handleBack() {
        if isDirty {
            showUnsavedDialog = true
        } else {
            dismiss()
        }
    }
}
