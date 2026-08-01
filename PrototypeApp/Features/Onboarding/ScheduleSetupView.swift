//
//  ScheduleSetupView.swift
//  Setup wizard, phase 2 of N: build the weekly class schedule either by
//  hand or by photographing a printed timetable and letting on-device OCR
//  (ScheduleOCRParser) draft the entries. Shown once — gated by
//  AppStorage("hasCompletedScheduleSetup") in RootContainerView.
//

import SwiftUI
import SwiftData
import UIKit

private enum ScheduleSetupMode: String, CaseIterable, Identifiable {
    case manual = "กรอกเอง"
    case photo = "ถ่ายภาพ"

    var id: String { rawValue }
}

struct ScheduleSetupView: View {
    @AppStorage("hasCompletedScheduleSetup") private var hasCompletedScheduleSetup = false
    @Environment(\.modelContext) private var context

    @State private var mode: ScheduleSetupMode = .manual
    @State private var draftEntries: [ScheduleDraftEntry] = []
    @State private var isPresentingManualEntrySheet = false
    @State private var isShowingPhotoSourceMenu = false
    @State private var activePickerSource: ProfileImagePicker.Source?
    @State private var isAnalyzingPhoto = false
    @State private var ocrFoundNothing = false

    private let dayLabels = ["จันทร์", "อังคาร", "พุธ", "พฤหัสบดี", "ศุกร์", "เสาร์", "อาทิตย์"]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("ตารางเรียน")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("ขั้นตอน 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 12)

                Picker("", selection: $mode) {
                    ForEach(ScheduleSetupMode.allCases) { Text($0.rawValue).tag($0) }
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
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Theme.Colors.background)

            Button("ข้าม") {
                hasCompletedScheduleSetup = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.trailing, 30)
        }
        .sheet(isPresented: $isPresentingManualEntrySheet) {
            ManualScheduleEntrySheet { entry in
                draftEntries.append(entry)
            }
        }
        .confirmationDialog("เลือกรูปตารางเรียน", isPresented: $isShowingPhotoSourceMenu, titleVisibility: .visible) {
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
            ForEach(1...7, id: \.self) { day in
                let entries = draftEntries.filter { $0.dayOfWeek == day }.sorted { $0.startTime < $1.startTime }
                if !entries.isEmpty {
                    Section(dayLabels[day - 1]) {
                        ForEach(entries) { entry in
                            entryRow(entry)
                        }
                    }
                }
            }
        }
        .overlay {
            if draftEntries.isEmpty {
                ContentUnavailableView("ยังไม่มีคาบเรียน", systemImage: "calendar.badge.plus", description: Text("แตะ + เพื่อเพิ่มคาบเรียน"))
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
                ProgressView("กำลังอ่านตารางเรียน...")
                    .padding(.top, 40)
            } else {
                Button {
                    isShowingPhotoSourceMenu = true
                } label: {
                    Label("ถ่ายภาพตารางเรียน", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.primary)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if ocrFoundNothing {
                    Text("อ่านตารางจากรูปนี้ไม่สำเร็จ ลองถ่ายให้เห็นหัวคอลัมน์วันและเวลาชัดๆ หรือสลับไปกรอกเองแทน")
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
                ForEach(1...7, id: \.self) { day in
                    let entries = draftEntries.filter { $0.dayOfWeek == day }.sorted { $0.startTime < $1.startTime }
                    if !entries.isEmpty {
                        Section(dayLabels[day - 1]) {
                            ForEach(entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: ScheduleDraftEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.subjectName).font(.system(size: 14, weight: .medium))
                Text("\(entry.startTime.formatted(date: .omitted, time: .shortened)) - \(entry.endTime.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
        ScheduleOCRParser.parseSchedule(from: image) { parsed in
            isAnalyzingPhoto = false
            if parsed.isEmpty {
                ocrFoundNothing = true
            } else {
                draftEntries.append(contentsOf: parsed)
            }
        }
    }

    private func saveAndContinue() {
        for draft in draftEntries {
            context.insert(
                ScheduleEntry(
                    dayOfWeek: draft.dayOfWeek,
                    startTime: draft.startTime,
                    endTime: draft.endTime,
                    kind: .classPeriod,
                    subjectName: draft.subjectName
                )
            )
        }
        hasCompletedScheduleSetup = true
    }
}

private struct ManualScheduleEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (ScheduleDraftEntry) -> Void

    @State private var dayOfWeek = 1
    @State private var subjectName = ""
    @State private var startTime = Date.now
    @State private var endTime = Date.now.addingTimeInterval(3000)

    private let dayLabels = ["จันทร์", "อังคาร", "พุธ", "พฤหัสบดี", "ศุกร์", "เสาร์", "อาทิตย์"]

    var body: some View {
        NavigationStack {
            Form {
                Picker("วัน", selection: $dayOfWeek) {
                    ForEach(1...7, id: \.self) { Text(dayLabels[$0 - 1]).tag($0) }
                }
                TextField("ชื่อวิชา", text: $subjectName)
                DatePicker("เริ่ม", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("สิ้นสุด", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            .navigationTitle("เพิ่มคาบเรียน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ยกเลิก") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("เพิ่ม") {
                        onAdd(ScheduleDraftEntry(dayOfWeek: dayOfWeek, startTime: startTime, endTime: endTime, subjectName: subjectName.trimmingCharacters(in: .whitespaces)))
                        dismiss()
                    }
                    .disabled(subjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ScheduleSetupView()
        .modelContainer(for: ScheduleEntry.self, inMemory: true)
}
