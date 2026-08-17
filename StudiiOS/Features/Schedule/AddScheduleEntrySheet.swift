//
//  AddScheduleEntrySheet.swift
//  Add/edit form for a single ScheduleEntry. `editing == nil` is add mode;
//  passing an existing entry switches to edit mode (with a delete button).
//

import SwiftUI
import SwiftData
import UIKit

struct AddScheduleEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allEntries: [ScheduleEntry]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    let editing: ScheduleEntry?
    let defaultDay: Int
    /// Called with the first day the import touched, so the Schedule tab can
    /// land on a day that actually has the new rows on it.
    let onImported: ((Int) -> Void)?

    @State private var dayOfWeek: Int
    @State private var periodNumber: Int
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var subjectName: String
    @State private var subjectCode: String
    @State private var teacherName: String
    @State private var location: String
    @State private var showDeleteConfirm = false
    @State private var isPickingSubject = false
    @State private var isRenamingSubject = false
    @State private var renameText = ""

    // Photo import (add mode only). Every step of the chain is presented from
    // this NavigationStack, never from a child view — nesting a picker inside a
    // sheet that is itself inside a sheet is what makes presentations vanish.
    @State private var isShowingScanWarning = false
    @State private var isShowingPhotoSource = false
    @State private var activePickerSource: ProfileImagePicker.Source?
    @State private var isAnalyzingPhoto = false
    @State private var scanError: String?
    @State private var reviewPayload: ImportReviewPayload?

    init(editing: ScheduleEntry?, defaultDay: Int, onImported: ((Int) -> Void)? = nil) {
        self.editing = editing
        self.defaultDay = defaultDay
        self.onImported = onImported

        _dayOfWeek = State(initialValue: editing?.dayOfWeek ?? defaultDay)
        _periodNumber = State(initialValue: editing?.periodNumber ?? 0)

        _startTime = State(initialValue: (editing?.startMinute ?? 480).asClockDate)
        _endTime = State(initialValue: (editing?.endMinute ?? 530).asClockDate)

        _subjectName = State(initialValue: editing?.subject?.name ?? editing?.subjectName ?? "")
        _subjectCode = State(initialValue: editing?.subject?.code ?? "")
        _teacherName = State(initialValue: editing?.teacherName ?? "")
        _location = State(initialValue: editing?.location ?? "")
    }

    private var isEditing: Bool { editing != nil }

    private var startMinuteValue: Int { startTime.minutesFromMidnight }
    private var endMinuteValue: Int { endTime.minutesFromMidnight }

    private var overlappingEntry: ScheduleEntry? {
        allEntries.inTerm(activeTerm).first { other in
            other.dayOfWeek == dayOfWeek && other !== editing &&
            startMinuteValue < other.endMinute && endMinuteValue > other.startMinute
        }
    }

    private var canSave: Bool {
        !subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && endMinuteValue > startMinuteValue
    }

    var body: some View {
        NavigationStack {
            Form {
                if editing == nil {
                    scanSection
                }
                // Same order as ScheduleImportRowEditSheet — Few asked for the
                // two edit screens to read identically.
                subjectSection
                timeSection
                detailSection
                if editing != nil {
                    deleteSection
                }
            }
            .themedFormBackground()
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
            .sheet(isPresented: $isPickingSubject) {
                SubjectPickerSheet(allowsCustomName: true, showsBreakOptions: true) { name, _ in
                    applyPickedSubject(named: name)
                }
            }
            .alert("แก้ชื่อวิชา", isPresented: $isRenamingSubject) {
                TextField("ชื่อวิชา", text: $renameText)
                Button("บันทึก") { renameSubject() }
                Button("ยกเลิก", role: .cancel) {}
            } message: {
                Text("เปลี่ยนชื่อวิชานี้ทุกที่ในแอป — ทั้งตารางเรียน งานที่ผูกวิชานี้ และเกรดรายวิชา")
            }
            .onAppear {
                if let editing {
                    AppLog.action("Schedule", "เปิดฟอร์มแก้คาบ: คาบ \(editing.periodNumber) · \(editing.subject?.name ?? editing.subjectName)")
                } else {
                    AppLog.action("Schedule", "เปิดฟอร์มเพิ่มคาบ (วัน=\(ScheduleConstants.dayLabels[dayOfWeek] ?? ""))")
                }
            }
            .alert("ระบบอาจอ่านผิด", isPresented: $isShowingScanWarning) {
                Button("ยกเลิก", role: .cancel) {}
                Button("เข้าใจแล้ว") { isShowingPhotoSource = true }
            } message: {
                Text("การอ่านตารางจากรูปอาจอ่านผิด โดยเฉพาะรหัสวิชาและเวลา กรุณาตรวจทุกคาบก่อนบันทึก")
            }
            .confirmationDialog(
                "เลือกรูปตารางเรียน",
                isPresented: $isShowingPhotoSource,
                titleVisibility: .visible
            ) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("ถ่ายรูป") { activePickerSource = .camera }
                }
                Button("เลือกจากคลังภาพ") { activePickerSource = .photoLibrary }
                Button("ยกเลิก", role: .cancel) {}
            }
            .fullScreenCover(item: $activePickerSource) { source in
                ProfileImagePicker(source: source, allowsEditing: false) { analyze($0) }
                    .ignoresSafeArea()
            }
            .sheet(item: $reviewPayload) { payload in
                ScheduleImportReviewSheet(payload: payload) { confirmed in
                    commitImport(confirmed)
                }
                .presentationDetents([.large])
                .interactiveDismissDisabled(true)
            }
        }
    }

    // MARK: - Sections

    /// Kept as its own property on purpose: the Form body is already close to
    /// SwiftUI's type-check budget and inlining this tips it over.
    private var scanSection: some View {
        Section {
            Button {
                isShowingScanWarning = true
            } label: {
                Label("ถ่ายตารางเรียน", systemImage: "camera.viewfinder")
            }
            .disabled(isAnalyzingPhoto)

            if isAnalyzingPhoto {
                HStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                    Text("กำลังอ่านตารางเรียน…").foregroundStyle(.secondary)
                }
            }
            if let scanError {
                Text(scanError)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.warning)
            }
        } footer: {
            Text("อ่านตารางทั้งใบจากรูป แล้วกรอกคาบให้อัตโนมัติ")
        }
    }

    /// วิชาเลือกจาก `SubjectPickerSheet` ชุดเดียวกับหน้ากรอกเกรด (16 ส.ค. 2569)
    /// เดิมเป็น `SubjectPickerFields` (กลุ่มสาระ → ชื่อ → พิมพ์เอง) ซึ่งคนละหน้าตากับที่อื่น
    private var subjectSection: some View {
        Section("วิชา") {
            Button {
                isPickingSubject = true
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Text(subjectName.isEmpty ? "เลือกวิชา" : subjectName)
                        .font(Theme.Font.body)
                        .foregroundStyle(subjectName.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    Spacer(minLength: Theme.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("รหัสวิชา (ไม่บังคับ)", text: $subjectCode)
                .textInputAutocapitalization(.characters)

            // เปลี่ยนชื่อ Subject ตัวจริง — มีผลกับทุกคาบ/งาน/เกรดที่ผูกวิชานี้
            if editing?.subject != nil {
                Button("แก้ชื่อวิชานี้ (มีผลทุกคาบ)") {
                    renameText = subjectName
                    isRenamingSubject = true
                }
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.primaryDeep)
            }
        }
    }

    private var timeSection: some View {
        Section("เวลา") {
            Picker("วัน", selection: $dayOfWeek) {
                ForEach(ScheduleConstants.visibleDays, id: \.self) { day in
                    Text(ScheduleConstants.dayLabels[day] ?? "").tag(day)
                }
            }
            PeriodNumberField(periodNumber: $periodNumber)
            DatePicker("เวลาเริ่ม", selection: $startTime, displayedComponents: .hourAndMinute)
            DatePicker("เวลาสิ้นสุด", selection: $endTime, displayedComponents: .hourAndMinute)
            if let overlap = overlappingEntry {
                Text("เวลาซ้อนทับกับคาบ \(overlap.periodNumber) (\(overlap.startMinute.asClockString)-\(overlap.endMinute.asClockString))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.warning)
            }
        }
    }

    private var detailSection: some View {
        Section("รายละเอียด") {
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

    // MARK: - Photo import

    /// `parseScheduleDetailed` already calls back on the main thread, so there
    /// is no hop here. A thin result is reported inline rather than opening an
    /// empty review sheet — a sheet with nothing in it reads as a crash.
    private func analyze(_ image: UIImage) {
        isAnalyzingPhoto = true
        scanError = nil
        ScheduleOCRParser.parseScheduleDetailed(from: image, onRawBoxes: nil) { result in
            isAnalyzingPhoto = false
            let periods = ScheduleImportBuilder.build(from: result.entries)
            guard !periods.isEmpty else {
                scanError = result.problem?.message
                    ?? "อ่านตารางจากรูปนี้ไม่สำเร็จ ลองถ่ายให้เห็นตารางทั้งใบและอย่าให้เอียง"
                AppLog.warn(
                    "ScheduleImport",
                    "OCR ไม่ได้คาบเลย · problem=\(String(describing: result.problem))"
                )
                return
            }
            // A readable table can still carry a problem worth mentioning —
            // "the times are guesses" is a warning, not a reason to throw the
            // whole sheet away.
            if let problem = result.problem { scanError = problem.message }
            AppLog.action(
                "ScheduleImport",
                "อ่านได้ \(periods.count) คาบ · ต้องตรวจ \(periods.filter(\.needsAttention).count)"
            )
            reviewPayload = ImportReviewPayload(image: image, periods: periods)
        }
    }

    private func commitImport(_ periods: [ImportedPeriod]) {
        guard let activeTerm else {
            reviewPayload = nil
            scanError = "ไม่พบเทอมปัจจุบัน ลองใหม่อีกครั้ง"
            AppLog.error("ScheduleImport", "commitImport ล้มเหลว: ไม่มี activeTerm")
            return
        }
        let summary = ScheduleImportCommitter.commit(periods, into: activeTerm, in: context)
        reviewPayload = nil                       // closes the review sheet
        if let day = summary.firstDay { onImported?(day) }
        dismiss()                                 // closes this sheet
    }

    // MARK: - Actions

    /// เลือกวิชาจาก picker — **ต้องเซ็ตรหัสตามวิชาที่เลือกด้วยเสมอ**
    /// `ScheduleConstants.resolveSubject` จับคู่ด้วย "รหัส" ก่อน "ชื่อ" ถ้าปล่อยรหัสของ
    /// วิชาเดิมค้างไว้ ตอนกดบันทึกมันจะคืนวิชาเดิมกลับมา = ชื่อไม่เปลี่ยน
    /// (บั๊กที่ Few เจอ 16 ส.ค. 2569)
    private func applyPickedSubject(named name: String) {
        subjectName = name
        let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        let match = existing.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        subjectCode = match?.code ?? ""
    }

    /// เปลี่ยนชื่อ `Subject` ตัวจริง แล้วไล่อัปเดต**สำเนาชื่อ**ที่โมเดลอื่นเก็บไว้
    /// (ScheduleEntry / Assignment / TermGradeSubject เก็บชื่อเป็น String ไม่ใช่ relation)
    private func renameSubject() {
        guard let subject = editing?.subject else { return }
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldName = subject.name
        guard !newName.isEmpty, newName != oldName else { return }

        subject.name = newName

        for entry in allEntries where entry.subject?.persistentModelID == subject.persistentModelID
            || entry.subjectName.caseInsensitiveCompare(oldName) == .orderedSame {
            entry.subjectName = newName
        }
        let assignments = (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
        for task in assignments where task.subjectName.caseInsensitiveCompare(oldName) == .orderedSame {
            task.subjectName = newName
        }
        let gradeSubjects = (try? context.fetch(FetchDescriptor<TermGradeSubject>())) ?? []
        for row in gradeSubjects where row.name.caseInsensitiveCompare(oldName) == .orderedSame {
            row.name = newName
        }

        subjectName = newName
        try? context.save()
        AppLog.action("Subject", "เปลี่ยนชื่อวิชา: \(oldName) → \(newName) (อัปเดตคาบ/งาน/เกรดที่ผูกชื่อเดิมด้วย)")
    }

    private func save() {
        // Time is checked first: resolveSubject can *insert* a Subject, and
        // bailing out after that would leave a stray one behind.
        guard endMinuteValue > startMinuteValue else {
            AppLog.warn("Schedule", "บันทึกไม่ได้: เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม")
            return
        }
        // Resolves to the Subject the row means, creating it if the user typed
        // a name that does not exist yet — the same rule the import path uses.
        guard let subject = ScheduleConstants.resolveSubject(
            named: subjectName, code: subjectCode, in: context
        ) else { return }

        // เลือกจากกลุ่ม "คาบพัก" ใน picker → วิชาที่เพิ่งสร้างต้องเป็นคาบพักด้วย
        // (ไม่งั้นคาบพักจะถูกนับเป็นวิชาปกติในเกรด/สถิติ)
        if ThaiSubjectCatalog.isBreakLabel(subject.name), !subject.isBreak {
            subject.isBreak = true
        }

        if let overlap = overlappingEntry {
            AppLog.warn("Schedule", "เวลาซ้อนทับกับ คาบ \(overlap.periodNumber) (\(overlap.startMinute.asClockString)-\(overlap.endMinute.asClockString))")
        }

        let trimmedTeacher = teacherName.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        if let editing {
            let oldLocation = editing.location
            let oldSubject = editing.subject?.name ?? editing.subjectName
            editing.dayOfWeek = dayOfWeek
            editing.startMinute = startMinuteValue
            editing.endMinute = endMinuteValue
            editing.periodNumber = periodNumber
            editing.teacherName = trimmedTeacher
            editing.location = trimmedLocation
            editing.subjectName = subject.name
            editing.subject = subject

            if let activeTerm {
                TermStore.syncTermSubjects(for: activeTerm, in: context)
            }
            do {
                try context.save()
                // Subject is logged as a before→after pair on purpose: a save
                // that resolved back to the old Subject looks identical to a
                // real edit without it.
                AppLog.action("Schedule", "แก้คาบสำเร็จ: คาบ \(periodNumber) · วิชา \(oldSubject) → \(subject.name) (รหัส \(subject.code.isEmpty ? "-" : subject.code)) · ห้อง \(oldLocation) → \(trimmedLocation)")
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
                subject: subject,
                term: activeTerm
            )
            context.insert(entry)

            if let activeTerm {
                TermStore.syncTermSubjects(for: activeTerm, in: context)
            }
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
        .modelContainer(for: [Subject.self, ScheduleEntry.self, Term.self, TermSubject.self], inMemory: true)
}
