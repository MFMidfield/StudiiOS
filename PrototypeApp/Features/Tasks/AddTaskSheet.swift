//
//  AddTaskSheet.swift
//  Shared create/edit form for Assignment (both การบ้าน and งานทั่วไป).
//  Opened from the tab bar's "+", the Dashboard, and the Todo screen's FAB.
//

import SwiftUI
import SwiftData

struct AddTaskSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    /// `nil` = creating a new task.
    private let editing: Assignment?
    /// Called after a successful save, so a presenting sheet (QuickAddSheet)
    /// can dismiss itself too.
    private let onSaved: (() -> Void)?

    @State private var title: String
    @State private var kind: AssignmentKind
    @State private var subjectName: String
    @State private var detail: String
    @State private var priorityChoice: PriorityChoice
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var remindersEnabled: Bool

    @State private var showSubjectSheet = false
    @State private var saveError: String?

    init(editing: Assignment? = nil, onSaved: (() -> Void)? = nil) {
        self.editing = editing
        self.onSaved = onSaved
        _title = State(initialValue: editing?.title ?? "")
        _kind = State(initialValue: editing?.kind ?? .homework)
        _subjectName = State(initialValue: editing?.subjectName ?? "")
        _detail = State(initialValue: editing?.detail ?? "")
        _priorityChoice = State(initialValue: PriorityChoice.forEditing(editing))
        _hasDueDate = State(initialValue: editing?.hasDueDate ?? false)
        _dueDate = State(initialValue: editing?.resolvedDueDate ?? Self.defaultDueDate())
        _remindersEnabled = State(initialValue: editing?.remindersEnabled ?? false)
    }

    // MARK: - Derived

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedTitle.isEmpty }

    /// Break slots are not something homework can belong to.
    private var selectableSubjects: [Subject] {
        subjects.filter { !$0.isBreak }
    }

    private var autoPriorityLabel: String {
        AssignmentPriorityEngine
            .priority(kind: kind, dueDate: hasDueDate ? dueDate : nil)
            .label
    }

    private static func defaultDueDate() -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 59, second: 0, of: .now) ?? .now
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                if kind == .homework { subjectSection }
                detailSection
                prioritySection
                dueDateSection
            }
            .navigationTitle(editing == nil ? "เพิ่มงาน" : "แก้ไขงาน")
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
            .sheet(isPresented: $showSubjectSheet) {
                AddSubjectSheet { created in
                    subjectName = created.name
                }
            }
            .alert("บันทึกงานไม่สำเร็จ", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("ตกลง", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var basicSection: some View {
        Section {
            TextField("ชื่องาน", text: $title)

            Picker("ประเภท", selection: $kind) {
                ForEach(AssignmentKind.allCases, id: \.self) { value in
                    Text(value.label).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var subjectSection: some View {
        Section {
            Picker("วิชา", selection: $subjectName) {
                Text("ไม่ระบุ").tag("")
                ForEach(selectableSubjects) { subject in
                    Text(subject.name).tag(subject.name)
                }
            }
            Button("เพิ่มวิชาใหม่") { showSubjectSheet = true }
        }
    }

    private var detailSection: some View {
        Section {
            TextField("รายละเอียด (ไม่บังคับ)", text: $detail, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var prioritySection: some View {
        Section {
            Picker("ความสำคัญ", selection: $priorityChoice) {
                ForEach(PriorityChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
        } footer: {
            if priorityChoice == .auto {
                Text("คำนวณจากกำหนดส่งและประเภทงาน — ตอนนี้ได้ระดับ \(autoPriorityLabel)")
            }
        }
    }

    private var dueDateSection: some View {
        Section {
            Toggle("กำหนดส่ง", isOn: $hasDueDate.animation(.easeInOut(duration: 0.2)))
            if hasDueDate {
                DatePicker(
                    "วันและเวลา",
                    selection: $dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            Toggle("แจ้งเตือน", isOn: $remindersEnabled)
                .disabled(!hasDueDate)
        } footer: {
            if hasDueDate {
                Text("เตือน 1 วันก่อน · เช้าวันกำหนด 07:00 · 1 ชม.ก่อน")
            } else {
                Text("ต้องกำหนดวันส่งก่อนถึงจะตั้งแจ้งเตือนได้")
            }
        }
        .onChange(of: hasDueDate) { _, isOn in
            remindersEnabled = isOn
        }
    }

    // MARK: - Save

    private func save() {
        guard canSave else { return }

        let target = editing ?? Assignment(title: trimmedTitle)
        if editing == nil { context.insert(target) }

        target.title = trimmedTitle
        target.kind = kind
        target.subjectName = kind == .homework ? subjectName : ""
        target.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isPriorityManual = priorityChoice != .auto
        if let manual = priorityChoice.priority { target.priority = manual }
        target.hasDueDate = hasDueDate
        if hasDueDate { target.dueDate = dueDate }
        // No due date means there is nothing to schedule reminders against.
        target.remindersEnabled = hasDueDate && remindersEnabled
        target.ensureUID()

        do {
            try context.save()
        } catch {
            saveError = error.localizedDescription
            return
        }

        // เฟส 4: เรียก NotificationManager.shared.schedule(for: target) ตรงนี้
        // (ยังไม่มี API นั้นในเฟส 2 — ดู PLAN_TodoList.md §4)

        AppLog.action("Assignment", "\(editing == nil ? "เพิ่ม" : "แก้ไข")งาน: \(target.title) ประเภท=\(target.kind.rawValue) วิชา=\(target.subjectName) กำหนดส่ง=\(target.hasDueDate) แจ้งเตือน=\(target.remindersEnabled)")
        dismiss()
        onSaved?()
    }

    // MARK: - Priority choice

    private enum PriorityChoice: String, CaseIterable, Identifiable {
        case auto, low, medium, high

        var id: String { rawValue }

        var label: String {
            switch self {
            case .auto: return "อัตโนมัติ"
            case .low: return "ต่ำ"
            case .medium: return "ปานกลาง"
            case .high: return "สูง"
            }
        }

        /// `nil` for `.auto` — the priority is derived on read instead.
        var priority: AssignmentPriority? {
            switch self {
            case .auto: return nil
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
            }
        }

        static func forEditing(_ assignment: Assignment?) -> PriorityChoice {
            guard let assignment, assignment.isPriorityManual else { return .auto }
            switch assignment.priority {
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
            }
        }
    }
}

#Preview {
    AddTaskSheet()
        .modelContainer(for: [Assignment.self, Subject.self], inMemory: true)
}
