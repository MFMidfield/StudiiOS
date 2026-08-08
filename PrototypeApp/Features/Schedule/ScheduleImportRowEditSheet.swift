//
//  ScheduleImportRowEditSheet.swift
//  Fixes one row of an OCR import.
//
//  Every ⚠️ on a row corresponds to one control here, and using that control
//  clears that flag — picking a real subject name clears `nameIsGuessed`,
//  picking a code clears `codeNeedsReview`, touching a time clears
//  `timeIsGuessed`. The row stops nagging because it was actually answered,
//  never because the flag was dropped on save.
//

import SwiftUI

struct ScheduleImportRowEditSheet: View {
    let period: ImportedPeriod
    let onSave: (ImportedPeriod) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: ImportedPeriod
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var periodText: String
    /// nil means "อื่นๆ (พิมพ์เอง)" — the name field is the answer instead.
    @State private var commonChoice: String?
    @State private var isConfirmingDelete = false

    init(
        period: ImportedPeriod,
        onSave: @escaping (ImportedPeriod) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.period = period
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: period)
        _startTime = State(initialValue: period.startMinute.asClockDate)
        _endTime = State(initialValue: period.endMinute.asClockDate)
        _periodText = State(initialValue: String(period.periodNumber))
    }

    // MARK: - Derived

    private var trimmedName: String {
        draft.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var startMinuteValue: Int { startTime.minutesFromMidnight }
    private var endMinuteValue: Int { endTime.minutesFromMidnight }

    private var timesAreValid: Bool { endMinuteValue > startMinuteValue }
    private var canSave: Bool { !trimmedName.isEmpty && timesAreValid }

    /// The readings OCR could not choose between, with whatever is currently in
    /// the code field kept in the list so the picker always has a selection.
    private var codeChoices: [String] {
        var result = period.codeOptions.filter { !$0.isEmpty }
        let current = draft.subjectCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty, !result.contains(current) { result.insert(current, at: 0) }
        return result
    }

    private var strand: ThaiSubjectStrand? {
        ThaiSubjectCatalog.parse(draft.subjectCode)?.strand
    }

    /// visibleDays plus this row's own day: a Saturday row imported from a
    /// seven-day photo must still show a day it can be moved off of.
    private var dayChoices: [Int] {
        var result = ScheduleConstants.visibleDays
        if !result.contains(draft.dayOfWeek) { result.append(draft.dayOfWeek) }
        return result.sorted()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                subjectSection
                timeSection
                detailSection
                deleteSection
            }
            .navigationTitle(period.isUserAdded ? "เพิ่มคาบเรียน" : "แก้คาบที่อ่านมา")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog(
                "ลบคาบนี้ออกจากรายการ?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("ลบคาบนี้", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("ยกเลิก", role: .cancel) {}
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("ยกเลิก") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("เสร็จสิ้น", action: save)
                .fontWeight(.semibold)
                .disabled(!canSave)
        }
    }

    // MARK: - Sections

    private var subjectSection: some View {
        Section("วิชา") {
            TextField("ชื่อวิชา", text: $draft.subjectName)
                .onChange(of: draft.subjectName) { _, _ in draft.nameIsGuessed = false }

            if !period.codeOptions.isEmpty {
                Picker("รหัสที่อ่านได้", selection: $draft.subjectCode) {
                    ForEach(codeChoices, id: \.self) { Text($0).tag($0) }
                }
            }

            if let strand {
                Picker("วิชาที่พบบ่อย", selection: $commonChoice) {
                    Text("อื่นๆ (พิมพ์เอง)").tag(String?.none)
                    ForEach(strand.commonSubjects, id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
                .onChange(of: commonChoice) { _, new in
                    guard let new else { return }
                    draft.subjectName = new
                }
            }

            TextField("รหัสวิชา", text: $draft.subjectCode)
                .autocorrectionDisabled()
                .onChange(of: draft.subjectCode) { _, _ in draft.codeNeedsReview = false }

            if draft.nameIsGuessed {
                hint("ชื่อวิชานี้เดามาจากรหัส ตรวจให้ตรงกับที่เรียนจริง", color: Theme.Colors.warning)
            }
        }
    }

    private var timeSection: some View {
        Section("เวลา") {
            Picker("วัน", selection: $draft.dayOfWeek) {
                ForEach(dayChoices, id: \.self) { day in
                    Text(ScheduleConstants.dayLabels[day] ?? "").tag(day)
                }
            }
            TextField("คาบที่", text: $periodText)
                .keyboardType(.numberPad)
            DatePicker("เวลาเริ่ม", selection: $startTime, displayedComponents: .hourAndMinute)
                .onChange(of: startTime) { _, _ in draft.timeIsGuessed = false }
            DatePicker("เวลาสิ้นสุด", selection: $endTime, displayedComponents: .hourAndMinute)
                .onChange(of: endTime) { _, _ in draft.timeIsGuessed = false }

            if !timesAreValid {
                hint("เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม", color: Theme.Colors.danger)
            } else if draft.timeIsGuessed {
                hint("เวลานี้เดามาจากคาบข้างเคียง ไม่ได้อ่านจากรูป", color: Theme.Colors.warning)
            }
        }
    }

    private var detailSection: some View {
        Section("รายละเอียด") {
            TextField("ชื่อครู", text: $draft.teacherName)
            TextField("ห้องเรียน", text: $draft.room)
            Toggle("เป็นคาบพัก / กิจกรรม", isOn: $draft.isBreak)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                HStack {
                    Spacer()
                    Text("ลบคาบนี้")
                    Spacer()
                }
            }
        }
    }

    private func hint(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }

    // MARK: - Save

    private func save() {
        guard canSave else { return }
        var result = draft
        result.subjectName = trimmedName
        result.subjectCode = draft.subjectCode.trimmingCharacters(in: .whitespacesAndNewlines)
        result.teacherName = draft.teacherName.trimmingCharacters(in: .whitespaces)
        result.room = draft.room.trimmingCharacters(in: .whitespaces)
        result.periodNumber = Int(periodText.trimmingCharacters(in: .whitespaces)) ?? draft.periodNumber
        result.startMinute = startMinuteValue
        result.endMinute = endMinuteValue
        // A break is never a coded subject, so its two code flags cannot apply.
        if result.isBreak {
            result.codeNeedsReview = false
            result.nameIsGuessed = false
        }
        onSave(result)
        dismiss()
    }
}
