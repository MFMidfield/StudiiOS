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
    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    @Query private var scheduleEntries: [ScheduleEntry]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    /// คาบของเทอมปัจจุบัน ตัดคาบพักออก — ใช้เป็นแหล่งชื่อวิชาของฟอร์มนี้
    private var termEntries: [ScheduleEntry] {
        scheduleEntries.filter { entry in
            guard entry.term?.id == activeTerm?.id else { return false }
            return entry.subject?.isBreak != true && !entry.subjectName.isEmpty
        }
    }

    /// `nil` = creating a new task.
    private let editing: Assignment?
    /// Called after a successful save, so a presenting sheet (QuickAddSheet)
    /// can dismiss itself too.
    private let onSaved: (() -> Void)?

    @State private var title: String
    @State private var kind: AssignmentKind
    @State private var examScope: ExamScope
    @State private var subjectName: String
    @State private var detail: String
    @State private var priorityChoice: PriorityChoice
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var remindersEnabled: Bool

    @State private var saveError: String?

    /// - Parameter presetKind: which kind the form opens on when creating a new
    ///   task. Ignored when `editing` is non-nil — an existing task keeps its own
    ///   kind. Lets a caller open the form already set to "สอบ" (Dashboard's
    ///   exam-countdown card) without the user having to switch tabs in the form.
    init(editing: Assignment? = nil, presetKind: AssignmentKind = .homework, onSaved: (() -> Void)? = nil) {
        self.editing = editing
        self.onSaved = onSaved
        _title = State(initialValue: editing?.title ?? "")
        _kind = State(initialValue: editing?.kind ?? presetKind)
        _examScope = State(initialValue: editing?.examScope ?? .midterm)
        _subjectName = State(initialValue: editing?.subjectName ?? "")
        _detail = State(initialValue: editing?.detail ?? "")
        _priorityChoice = State(initialValue: PriorityChoice.forEditing(editing))
        // An exam with no date can't be counted down to — start it switched on.
        _hasDueDate = State(initialValue: editing?.hasDueDate ?? (presetKind == .exam))
        _dueDate = State(initialValue: editing?.resolvedDueDate ?? Self.defaultDueDate())
        // A NEW task follows the "เตือนงานใหม่อัตโนมัติ" switch in Settings;
        // an existing one always keeps whatever it was saved with.
        // `object(forKey:)` rather than `bool(forKey:)`: bool returns false for
        // a key never written, which would read as "switched off" on first run.
        _remindersEnabled = State(initialValue: editing?.remindersEnabled
            ?? (UserDefaults.standard.object(forKey: SettingsView.reminderDefaultKey) as? Bool ?? true))
    }

    // MARK: - Derived

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedTitle.isEmpty }

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
                if kind == .exam { examSection }
                if needsSubject { subjectSection }
                detailSection
                prioritySection
                dueDateSection
            }
            .themedFormBackground()
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

    private var examSection: some View {
        Section("ประเภทการสอบ") {
            Picker("ประเภท", selection: $examScope) {
                ForEach(ExamScope.allCases, id: \.self) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    /// เลือกวิชาด้วย "วัน → คาบ" ไม่ใช่รายชื่อวิชา (ดู TaskSubjectPeriodPicker)
    /// โชว์เฉพาะการบ้าน กับสอบแบบ "เก็บคะแนน" — กลางภาค/ปลายภาคสอบรวมทุกวิชา
    /// จึงไม่ต้องผูกวิชา
    private var subjectSection: some View {
        Section {
            if termEntries.isEmpty {
                Text("ยังไม่ได้ตั้งตารางเรียนของเทอมนี้ — ตั้งก่อนถึงจะเลือกวิชาได้")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                TaskSubjectPeriodPicker(entries: termEntries, subjectName: $subjectName)
            }
        } header: {
            Text("วิชา")
        } footer: {
            if !subjectName.isEmpty {
                Text("วิชาที่เลือก: \(subjectName)")
            }
        }
    }

    /// การบ้าน = ผูกวิชาเสมอ · สอบ = เฉพาะ "เก็บคะแนน" · งานทั่วไป = ไม่ผูก
    private var needsSubject: Bool {
        switch kind {
        case .homework: return true
        case .exam: return examScope == .quiz
        case .personal: return false
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
            if kind != .exam {
                Toggle("กำหนดส่ง", isOn: $hasDueDate.animation(.easeInOut(duration: 0.2)))
            }
            if hasDueDate {
                DatePicker(
                    kind == .exam ? "วันสอบ" : "วันและเวลา",
                    selection: $dueDate,
                    displayedComponents: kind == .exam ? [.date] : [.date, .hourAndMinute]
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
        .onChange(of: kind) { _, newKind in
            if newKind == .exam { hasDueDate = true }
        }
    }

    // MARK: - Save

    private func save() {
        guard canSave else { return }

        let target = editing ?? Assignment(title: trimmedTitle, term: activeTerm)
        if editing == nil { context.insert(target) }

        target.title = trimmedTitle
        target.kind = kind
        target.examScope = kind == .exam ? examScope : nil
        target.subjectName = needsSubject ? subjectName : ""
        target.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        target.isPriorityManual = priorityChoice != .auto
        if let manual = priorityChoice.priority { target.priority = manual }
        target.hasDueDate = kind == .exam ? true : hasDueDate
        if target.hasDueDate { target.dueDate = dueDate }
        // No due date means there is nothing to schedule reminders against.
        target.remindersEnabled = hasDueDate && remindersEnabled
        target.ensureUID()

        do {
            try context.save()
        } catch {
            saveError = error.localizedDescription
            return
        }

        // schedule() ยกเลิกของเดิมให้ก่อนเสมอ — ครอบคลุมทั้งกรณีเปิดและปิด toggle
        let saved = target
        Task { await NotificationManager.shared.schedule(for: saved) }

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
        .modelContainer(for: [Assignment.self, Subject.self, Term.self, TermSubject.self, ScheduleEntry.self], inMemory: true)
}
