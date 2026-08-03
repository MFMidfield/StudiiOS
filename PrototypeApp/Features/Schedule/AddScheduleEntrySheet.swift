//
//  AddScheduleEntrySheet.swift
//  Add/edit form for a single ScheduleEntry. `editing == nil` is add mode;
//  passing an existing entry switches to edit mode (with a delete button).
//

import SwiftUI
import SwiftData

private enum PeriodChoice: Hashable {
    case number(Int)
    case custom
}

struct AddScheduleEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Query private var allEntries: [ScheduleEntry]

    let editing: ScheduleEntry?
    let defaultDay: Int

    @State private var dayOfWeek: Int
    @State private var periodChoice: PeriodChoice
    @State private var customPeriodText: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedSubject: Subject?
    @State private var teacherName: String
    @State private var location: String
    @State private var showDeleteConfirm = false
    @State private var isAddingSubject = false

    init(editing: ScheduleEntry?, defaultDay: Int) {
        self.editing = editing
        self.defaultDay = defaultDay

        _dayOfWeek = State(initialValue: editing?.dayOfWeek ?? defaultDay)

        if let editing, (0...10).contains(editing.periodNumber) {
            _periodChoice = State(initialValue: .number(editing.periodNumber))
            _customPeriodText = State(initialValue: "")
        } else if let editing {
            _periodChoice = State(initialValue: .custom)
            _customPeriodText = State(initialValue: String(editing.periodNumber))
        } else {
            _periodChoice = State(initialValue: .number(0))
            _customPeriodText = State(initialValue: "")
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        _startTime = State(initialValue: cal.date(byAdding: .minute, value: editing?.startMinute ?? 480, to: today) ?? today)
        _endTime = State(initialValue: cal.date(byAdding: .minute, value: editing?.endMinute ?? 530, to: today) ?? today)

        _selectedSubject = State(initialValue: editing?.subject)
        _teacherName = State(initialValue: editing?.teacherName ?? "")
        _location = State(initialValue: editing?.location ?? "")
    }

    private var isEditing: Bool { editing != nil }

    private var startMinuteValue: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var endMinuteValue: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: endTime)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var periodNumberValue: Int? {
        switch periodChoice {
        case .number(let n): return n
        case .custom: return Int(customPeriodText)
        }
    }

    private var overlappingEntry: ScheduleEntry? {
        allEntries.first { other in
            other.dayOfWeek == dayOfWeek && other !== editing &&
            startMinuteValue < other.endMinute && endMinuteValue > other.startMinute
        }
    }

    private var canSave: Bool {
        selectedSubject != nil && periodNumberValue != nil && endMinuteValue > startMinuteValue
    }

    var body: some View {
        NavigationStack {
            Form {
                dayAndPeriodSection
                timeSection
                subjectSection
                if editing != nil {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "แก้คาบเรียน" : "เพิ่มคาบเรียน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "ลบคาบนี้?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("ลบคาบเรียนนี้", role: .destructive, action: delete)
                Button("ยกเลิก", role: .cancel) {}
            }
            .sheet(isPresented: $isAddingSubject) {
                AddSubjectSheet { subject in
                    selectedSubject = subject
                }
            }
            .onAppear {
                if let editing {
                    AppLog.action("Schedule", "เปิดฟอร์มแก้คาบ: คาบ \(editing.periodNumber) · \(editing.subject?.name ?? editing.subjectName)")
                } else {
                    AppLog.action("Schedule", "เปิดฟอร์มเพิ่มคาบ (วัน=\(ScheduleConstants.dayLabels[dayOfWeek] ?? ""))")
                }
            }
        }
    }

    // MARK: - Sections

    private var dayAndPeriodSection: some View {
        Section {
            Picker("วัน", selection: $dayOfWeek) {
                ForEach(ScheduleConstants.visibleDays, id: \.self) { day in
                    Text(ScheduleConstants.dayLabels[day] ?? "").tag(day)
                }
            }

            Picker("คาบที่", selection: $periodChoice) {
                ForEach(0...10, id: \.self) { n in
                    Text("\(n)").tag(PeriodChoice.number(n))
                }
                Text("กำหนดเอง").tag(PeriodChoice.custom)
            }
            if periodChoice == .custom {
                TextField("เลขคาบ", text: $customPeriodText)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var timeSection: some View {
        Section {
            DatePicker("เวลาเริ่ม", selection: $startTime, displayedComponents: .hourAndMinute)
            DatePicker("เวลาสิ้นสุด", selection: $endTime, displayedComponents: .hourAndMinute)
            if let overlap = overlappingEntry {
                Text("เวลาซ้อนทับกับคาบ \(overlap.periodNumber) (\(overlap.startMinute.asClockString)-\(overlap.endMinute.asClockString))")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.warning)
            }
        }
    }

    private var subjectSection: some View {
        Section {
            Picker("วิชา", selection: $selectedSubject) {
                Text("เลือกวิชา").tag(Subject?.none)
                ForEach(subjects) { subject in
                    Text(subject.name).tag(Subject?.some(subject))
                }
            }
            Button {
                isAddingSubject = true
            } label: {
                Label("เพิ่มวิชาใหม่", systemImage: "plus.circle.fill")
            }

            TextField("ชื่อครู", text: $teacherName)
            TextField("ห้องเรียน", text: $location)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Text("ลบคาบเรียนนี้")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard let subject = selectedSubject, let periodNumber = periodNumberValue else { return }
        guard endMinuteValue > startMinuteValue else {
            AppLog.warn("Schedule", "บันทึกไม่ได้: เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม")
            return
        }

        if let overlap = overlappingEntry {
            AppLog.warn("Schedule", "เวลาซ้อนทับกับ คาบ \(overlap.periodNumber) (\(overlap.startMinute.asClockString)-\(overlap.endMinute.asClockString))")
        }

        let trimmedTeacher = teacherName.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        if let editing {
            let oldLocation = editing.location
            editing.dayOfWeek = dayOfWeek
            editing.startMinute = startMinuteValue
            editing.endMinute = endMinuteValue
            editing.periodNumber = periodNumber
            editing.teacherName = trimmedTeacher
            editing.location = trimmedLocation
            editing.subjectName = subject.name
            editing.subject = subject

            do {
                try context.save()
                AppLog.action("Schedule", "แก้คาบสำเร็จ: คาบ \(periodNumber) · ห้อง \(oldLocation) → \(trimmedLocation)")
            } catch {
                AppLog.error("Schedule", "save ล้มเหลว: \(error.localizedDescription)")
                return
            }
        } else {
            let entry = ScheduleEntry(
                dayOfWeek: dayOfWeek,
                startMinute: startMinuteValue,
                endMinute: endMinuteValue,
                periodNumber: periodNumber,
                teacherName: trimmedTeacher,
                location: trimmedLocation,
                subjectName: subject.name,
                subject: subject
            )
            context.insert(entry)

            do {
                try context.save()
                AppLog.action("Schedule", "เพิ่มคาบสำเร็จ: คาบ \(periodNumber) · \(subject.name) · \(startMinuteValue.asClockString)-\(endMinuteValue.asClockString) · ห้อง \(trimmedLocation) · ครู\(trimmedTeacher)")
            } catch {
                AppLog.error("Schedule", "save ล้มเหลว: \(error.localizedDescription)")
                return
            }
        }

        dismiss()
    }

    private func delete() {
        guard let editing else { return }
        let periodNumber = editing.periodNumber
        let subjectLabel = editing.subject?.name ?? editing.subjectName
        let dayLabel = ScheduleConstants.dayLabelsFull[editing.dayOfWeek] ?? ""

        context.delete(editing)
        do {
            try context.save()
            AppLog.action("Schedule", "ลบคาบ: คาบ \(periodNumber) · \(subjectLabel) · \(dayLabel)")
        } catch {
            AppLog.error("Schedule", "save ล้มเหลว: \(error.localizedDescription)")
        }
        dismiss()
    }
}

#Preview {
    AddScheduleEntrySheet(editing: nil, defaultDay: 1)
        .modelContainer(for: [Subject.self, ScheduleEntry.self], inMemory: true)
}
