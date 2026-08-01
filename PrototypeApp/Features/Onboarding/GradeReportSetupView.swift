//
//  GradeReportSetupView.swift
//  Setup wizard, phase 3 of N: import last semester's grades either by
//  hand or by photographing a ปพ. report card and letting on-device OCR
//  (GradeReportOCRParser) draft the rows. Shown once — gated by
//  AppStorage("hasCompletedGradeSetup") in RootContainerView. Can be
//  skipped entirely via the "ข้าม" button.
//

import SwiftUI
import SwiftData
import UIKit

private enum GradeSetupMode: String, CaseIterable, Identifiable {
    case manual = "กรอกเอง"
    case photo = "ถ่ายภาพ"

    var id: String { rawValue }
}

private let thaiGradeScale: [Double] = [0, 1, 1.5, 2, 2.5, 3, 3.5, 4]

struct GradeReportSetupView: View {
    @AppStorage("hasCompletedGradeSetup") private var hasCompletedGradeSetup = false
    @Environment(\.modelContext) private var context

    @State private var semesterLabel = ""
    @State private var mode: GradeSetupMode = .manual
    @State private var draftEntries: [GradeDraftEntry] = []
    @State private var isPresentingManualEntrySheet = false
    @State private var isShowingPhotoSourceMenu = false
    @State private var activePickerSource: ProfileImagePicker.Source?
    @State private var isAnalyzingPhoto = false
    @State private var ocrFoundNothing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("นำเข้าใบ ปพ.")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("ขั้นตอน 3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 12)

                TextField("ภาคเรียน เช่น 1/2568", text: $semesterLabel)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                Picker("", selection: $mode) {
                    ForEach(GradeSetupMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                switch mode {
                case .manual: manualSection
                case .photo: photoSection
                }

                Button {
                    saveAndContinue()
                } label: {
                    Text("ถัดไป")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.primary)
                .disabled(semesterLabel.trimmingCharacters(in: .whitespaces).isEmpty || draftEntries.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Theme.Colors.background)

            Button("ข้าม") {
                hasCompletedGradeSetup = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.trailing, 30)
        }
        .sheet(isPresented: $isPresentingManualEntrySheet) {
            ManualGradeEntrySheet { entry in
                draftEntries.append(entry)
            }
        }
        .confirmationDialog("เลือกรูปใบ ปพ.", isPresented: $isShowingPhotoSourceMenu, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("ถ่ายรูป") { activePickerSource = .camera }
            }
            Button("เลือกจากคลังภาพ") { activePickerSource = .photoLibrary }
            Button("ยกเลิก", role: .cancel) {}
        }
        .fullScreenCover(item: $activePickerSource) { source in
            ProfileImagePicker(source: source, allowsEditing: false) { image in
                analyze(image)
            }
            .ignoresSafeArea()
        }
    }

    private var manualSection: some View {
        List {
            ForEach(draftEntries) { entry in
                entryRow(entry)
            }
        }
        .overlay {
            if draftEntries.isEmpty {
                ContentUnavailableView("ยังไม่มีรายวิชา", systemImage: "doc.text.badge.plus", description: Text("แตะ + เพื่อเพิ่มวิชา"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingManualEntrySheet = true } label: { Image(systemName: "plus") }
            }
        }
    }

    private var photoSection: some View {
        VStack(spacing: 16) {
            if isAnalyzingPhoto {
                ProgressView("กำลังอ่านใบ ปพ....")
                    .padding(.top, 40)
            } else {
                Button {
                    isShowingPhotoSourceMenu = true
                } label: {
                    Label("ถ่ายภาพใบ ปพ.", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.primary)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if ocrFoundNothing {
                    Text("อ่านตารางจากรูปนี้ไม่สำเร็จ ลองถ่ายให้เห็นหัวคอลัมน์ \"หน่วยกิต\" และ \"เกรด\" ชัดๆ หรือสลับไปกรอกเองแทน")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.warning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Text("ผลลัพธ์จาก AI เป็นแค่ร่าง — ตรวจสอบและแก้ไขได้ก่อนบันทึกจริง")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            List {
                ForEach(draftEntries) { entry in
                    entryRow(entry)
                }
            }
        }
    }

    private func entryRow(_ entry: GradeDraftEntry) -> some View {
        HStack {
            Text(entry.subjectName).font(.system(size: 14, weight: .medium))
            Spacer()
            Text("\(entry.creditHours, specifier: "%.1f") นก.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", entry.gradePoint))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 32)
        }
        .swipeActions {
            Button(role: .destructive) {
                draftEntries.removeAll { $0.id == entry.id }
            } label: {
                Label("ลบ", systemImage: "trash")
            }
        }
    }

    private func analyze(_ image: UIImage) {
        isAnalyzingPhoto = true
        ocrFoundNothing = false
        GradeReportOCRParser.parseGradeReport(from: image) { parsed in
            isAnalyzingPhoto = false
            if parsed.isEmpty {
                ocrFoundNothing = true
            } else {
                draftEntries.append(contentsOf: parsed)
            }
        }
    }

    private func saveAndContinue() {
        let label = semesterLabel.trimmingCharacters(in: .whitespaces)
        for draft in draftEntries {
            context.insert(
                SemesterRecord(
                    semesterLabel: label,
                    subjectName: draft.subjectName,
                    creditHours: draft.creditHours,
                    gradePoint: draft.gradePoint
                )
            )
        }
        hasCompletedGradeSetup = true
    }
}

private struct ManualGradeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (GradeDraftEntry) -> Void

    @State private var subjectName = ""
    @State private var creditHours = 1.0
    @State private var gradePoint = 3.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("ชื่อวิชา", text: $subjectName)
                Stepper("หน่วยกิต: \(creditHours, specifier: "%.1f")", value: $creditHours, in: 0.5...4, step: 0.5)
                Picker("เกรด", selection: $gradePoint) {
                    ForEach(thaiGradeScale, id: \.self) { Text(String(format: "%.1f", $0)).tag($0) }
                }
            }
            .navigationTitle("เพิ่มรายวิชา")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ยกเลิก") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("เพิ่ม") {
                        onAdd(GradeDraftEntry(subjectName: subjectName.trimmingCharacters(in: .whitespaces), creditHours: creditHours, gradePoint: gradePoint))
                        dismiss()
                    }
                    .disabled(subjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    GradeReportSetupView()
        .modelContainer(for: [SemesterRecord.self], inMemory: true)
}
