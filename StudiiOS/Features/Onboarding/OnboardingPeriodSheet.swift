//
//  OnboardingPeriodSheet.swift
//  เพิ่มคาบเรียนหนึ่งคาบระหว่าง setup
//
//  ต่างจาก `AddScheduleEntrySheet` ตรงที่ชื่อวิชาพิมพ์เองไม่ได้ — ต้องเลือกจาก
//  `SubjectPickerSheet` เท่านั้น (สเปคหน้า 3) ที่เหลือเหมือนกัน และบันทึกผ่าน
//  `ScheduleConstants.resolveSubject` ตัวเดียวกัน วิชาจึงไม่ซ้ำกับที่มีอยู่แล้ว
//

import SwiftUI
import SwiftData

struct OnboardingPeriodSheet: View {
    let term: Term
    /// เวลาเริ่มต้นของคาบใหม่ = ต่อจากคาบสุดท้ายของวันนั้น
    var defaultDay: Int = ScheduleConstants.defaultEntryDay
    var defaultStartMinute: Int = 8 * 60

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var dayOfWeek: Int
    @State private var subjectName = ""
    @State private var subjectStrand: ThaiSubjectStrand?
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var teacherName = ""
    @State private var location = ""
    @State private var isPickingSubject = false

    init(term: Term, defaultDay: Int = ScheduleConstants.defaultEntryDay, defaultStartMinute: Int = 8 * 60) {
        self.term = term
        self.defaultDay = defaultDay
        self.defaultStartMinute = defaultStartMinute
        _dayOfWeek = State(initialValue: defaultDay)
        _startTime = State(initialValue: defaultStartMinute.asClockDate)
        _endTime = State(initialValue: (defaultStartMinute + 50).asClockDate)
    }

    private var canSave: Bool {
        !subjectName.isEmpty && endTime.minutesFromMidnight > startTime.minutesFromMidnight
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("วิชา") {
                    Button {
                        isPickingSubject = true
                    } label: {
                        HStack {
                            Text(subjectName.isEmpty ? "เลือกวิชา" : subjectName)
                                .foregroundStyle(subjectName.isEmpty
                                                 ? Theme.Colors.textSecondary
                                                 : Theme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                }

                Section("เวลา") {
                    Picker("วัน", selection: $dayOfWeek) {
                        ForEach(ScheduleConstants.visibleDays, id: \.self) { day in
                            Text(ScheduleConstants.dayLabels[day] ?? "").tag(day)
                        }
                    }
                    DatePicker("เริ่ม", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("สิ้นสุด", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                Section("รายละเอียด (ไม่บังคับ)") {
                    TextField("ชื่อครู", text: $teacherName)
                    TextField("ห้องเรียน", text: $location)
                }
            }
            .navigationTitle("เพิ่มคาบเรียน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("เพิ่ม", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isPickingSubject) {
                SubjectPickerSheet(allowsCustomName: true) { name, strand in
                    subjectName = name
                    subjectStrand = strand
                }
            }
        }
    }

    private func save() {
        guard let subject = ScheduleConstants.resolveSubject(
            named: subjectName, code: "", strand: subjectStrand, in: context
        ) else { return }

        context.insert(
            ScheduleEntry(
                dayOfWeek: dayOfWeek,
                startMinute: startTime.minutesFromMidnight,
                endMinute: endTime.minutesFromMidnight,
                periodNumber: 0,
                teacherName: teacherName.trimmingCharacters(in: .whitespaces),
                location: location.trimmingCharacters(in: .whitespaces),
                subjectName: subject.name,
                subject: subject,
                term: term
            )
        )
        TermStore.syncTermSubjects(for: term, in: context)
        try? context.save()
        AppLog.action("Onboarding", "เพิ่มคาบเรียน \(subject.name) · \(ScheduleConstants.dayLabels[dayOfWeek] ?? "")")
        dismiss()
    }
}
