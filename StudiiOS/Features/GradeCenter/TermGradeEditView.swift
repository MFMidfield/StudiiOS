//
//  TermGradeEditView.swift
//  Pushed page (not a sheet) for one term's grades. Opened from a past or
//  current row in TermGradeListSection, from the chart, and from the
//  onboarding backlog step.
//
//  ยกเครื่องหน้าตา 16 ส.ค. 2569: ทิ้ง `Form` มาเป็น ScrollView + CardContainer
//  บนพื้น `Theme.Colors.background` ให้เหมือนหน้าอื่นในแอป · สวิตช์ "กรอกละเอียด"
//  กลายเป็น segmented 2 โหมดพร้อมคำอธิบาย เพราะของเดิมผู้ใช้เปิดมาแล้วไม่รู้ว่า
//  ต้องกรอกอะไร · ปุ่ม "จำเกรดเทอมนี้ไม่ได้" ถูกเอาออก (โหมด GPAX สะสมถูก
//  ถอดออกจาก UI ทั้งแอป 16 ส.ค. 2569 — `CumulativeGPAXSheet.swift` ถูกลบทิ้ง)
//
//  Simple mode writes term.gpa/totalCredits directly.
//  Detailed mode (Term.usesDetailedGrades) keeps a TermGradeSubject per
//  subject and derives term.gpa/totalCredits from them on every edit — so
//  GPAXCalculator/GPAXSummaryCard/the dashboard card need no changes, they
//  keep reading Term.gpa/totalCredits either way.
//
//  Saving is autosave-on-change throughout (this is a push, there is no
//  "บันทึก" toolbar button) but always goes through TermStore.findOrCreate —
//  never `context.insert(Term(...))` directly.
//

import SwiftUI
import SwiftData

struct TermGradeEditView: View {
    @Environment(\.modelContext) private var context

    let gradeLevel: Int
    let termNumber: Int

    /// วิชาสำรองสำหรับ seed เมื่อเทอมนี้เองไม่มีตารางเรียน — ใช้ตอน setup: เทอมย้อนหลัง
    /// ไม่มีใครกรอกตารางไว้ แต่ตารางของเทอมปัจจุบันมักเป็นวิชาชุดเดียวกัน
    /// nil = พฤติกรรมเดิมทุกอย่าง (หน้าเกรดปกติส่ง nil)
    var seedFrom: Term?

    @Query private var allTerms: [Term]
    @Query private var allGradeSubjects: [TermGradeSubject]
    @Query private var allEntries: [ScheduleEntry]

    @State private var usesDetailed: Bool
    @State private var gpaText: String
    @State private var creditsText: String
    @State private var isPickingSubject = false
    @State private var isConfirmingModeSwitch = false

    /// Thai 8-step grade point scale. ไม่มี 0.5 — โรงเรียนไม่ให้เกรดนี้
    static let gradeSteps: [Double] = [0, 1, 1.5, 2, 2.5, 3, 3.5, 4]

    init(gradeLevel: Int, termNumber: Int, existingTerm: Term?, seedFrom: Term? = nil) {
        self.gradeLevel = gradeLevel
        self.termNumber = termNumber
        self.seedFrom = seedFrom
        _usesDetailed = State(initialValue: existingTerm?.usesDetailedGrades ?? false)
        // ช่องว่างไว้เสมอถ้ายังไม่เคยกรอก — ค่า prefill 2.00 ของเดิมทำให้แยกไม่ออกว่า
        // นี่คือเกรดจริงหรือแค่ค่าตั้งต้นที่ลืมแก้
        _gpaText = State(initialValue: existingTerm?.gpa.map { String(format: "%.2f", $0) } ?? "")
        _creditsText = State(initialValue: existingTerm?.totalCredits.map { String(format: "%.1f", $0) } ?? "")
    }

    private var displayName: String { "ม.\(gradeLevel) เทอม \(termNumber)" }

    private var term: Term? {
        allTerms.first { $0.gradeLevel == gradeLevel && $0.termNumber == termNumber }
    }

    private var subjects: [TermGradeSubject] {
        guard let term else { return [] }
        return allGradeSubjects
            .filter { $0.term?.id == term.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// คาบที่จะใช้ seed: ของเทอมนี้ก่อน ไม่มีค่อยยืมของ `seedFrom`
    private var seedEntries: [ScheduleEntry] {
        if let term {
            let own = allEntries.filter { $0.term?.id == term.id }
            if !own.isEmpty { return own }
        }
        guard let seedFrom else { return [] }
        return allEntries.filter { $0.term?.id == seedFrom.id }
    }

    private var termHasTimetable: Bool { !seedEntries.isEmpty }

    private var summaryCredits: Double { subjects.reduce(0) { $0 + $1.creditHours } }
    private var summaryGPA: Double? {
        guard summaryCredits > 0 else { return nil }
        let weighted = subjects.reduce(0.0) { $0 + $1.creditHours * $1.gradePoint }
        return weighted / summaryCredits
    }

    private var parsedGPA: Double? { Double(gpaText) }
    private var parsedCredits: Double? { Double(creditsText) }
    private var gpaIsValid: Bool {
        gpaText.isEmpty || (parsedGPA.map { (0.0...4.0).contains($0) } ?? false)
    }
    private var creditsAreValid: Bool {
        creditsText.isEmpty || (parsedCredits.map { (0.5...40.0).contains($0) } ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                introCard
                if usesDetailed {
                    detailedSubjectsCard
                    detailedSummaryCard
                } else {
                    simpleCard
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: gpaText) { _, _ in saveSimpleGrade() }
        .onChange(of: creditsText) { _, _ in saveSimpleGrade() }
        .sheet(isPresented: $isPickingSubject) {
            SubjectPickerSheet(allowsCustomName: true) { name, _ in
                addSubject(named: name)
            }
        }
        .alert("เปลี่ยนวิธีกรอก?", isPresented: $isConfirmingModeSwitch) {
            Button("เปลี่ยน") { applyMode(!usesDetailed) }
            Button("ยกเลิก", role: .cancel) {}
        } message: {
            Text(usesDetailed
                 ? "เกรดเฉลี่ยจะคิดจากที่กรอกเอง รายวิชายังเก็บไว้"
                 : "เกรดเฉลี่ยจะคิดจากรายวิชาแทน ค่าที่กรอกไว้ยังเก็บไว้")
        }
    }

    // MARK: - หัวหน้า

    /// ปุ่มเดียวสลับโหมด — ค่าเริ่มต้นคือกรอกเกรดเฉลี่ยรวม กดแล้วไปรายวิชา กดอีกที
    /// กลับมา ข้อมูลของโหมดที่ไม่ได้ใช้ไม่ถูกลบ (เตือนก่อนเฉพาะตอนมีของจะโดนทับ)
    private var introCard: some View {
        CardContainer {
            Text(usesDetailed ? "กรอกรายวิชา" : "กรอกเกรดเฉลี่ยรวม")
                .font(Theme.Font.plex(17, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                requestModeSwitch()
            } label: {
                Label(
                    usesDetailed ? "เปลี่ยนเป็นเกรดเฉลี่ยรวม" : "เปลี่ยนเป็นกรอกรายวิชา",
                    systemImage: "arrow.left.arrow.right"
                )
                .font(Theme.Font.plex(13, .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(Theme.Colors.primary)
        }
    }

    /// เตือนก่อนเฉพาะตอนที่โหมดปลายทางจะทับตัวเลขที่อีกโหมดกรอกไว้
    private func requestModeSwitch() {
        let losesSomething = usesDetailed ? !subjects.isEmpty : !gpaText.isEmpty
        if losesSomething {
            isConfirmingModeSwitch = true
        } else {
            applyMode(!usesDetailed)
        }
    }

    /// สลับโหมดแล้วเขียน `term.gpa`/`totalCredits` ใหม่ให้ตรงกับโหมดที่เลือก —
    /// ของอีกโหมดยังอยู่ครบ (รายวิชาไม่ถูกลบ · `gpaText` ยังอยู่ใน state)
    private func applyMode(_ detailed: Bool) {
        usesDetailed = detailed
        let term = ensureTerm()
        term.usesDetailedGrades = detailed
        try? context.save()
        if detailed {
            seedSubjectsFromTimetable(term: term)
            recomputeDetailedTotals()
        } else {
            saveSimpleGrade()
        }
    }

    // MARK: - โหมดเกรดเฉลี่ยรวม

    private var simpleCard: some View {
        CardContainer {
            FieldBlock(
                title: "เกรดเฉลี่ยเทอมนี้",
                hint: "อยู่บนใบ ปพ.1 ช่อง \"ผลการเรียนเฉลี่ย\"",
                // สั้นได้แค่นี้ — ถ้าตัดชื่อช่องออก ผู้ใช้หาไม่เจอว่าเลขไหน
                error: gpaIsValid ? nil : "กรอกได้ 0.00–4.00"
            ) {
                ThemedNumberField(placeholder: "เช่น 3.28", text: $gpaText)
            }

            Divider()

            FieldBlock(
                title: "หน่วยกิตรวม (ไม่บังคับ)",
                hint: "ไม่กรอก GPAX จะคลาดเคลื่อน ±0.03",
                error: creditsAreValid ? nil : "กรอกได้ 0.5–40.0"
            ) {
                ThemedNumberField(placeholder: "เช่น 20.0", text: $creditsText)
            }
        }
    }

    private func saveSimpleGrade() {
        guard gpaIsValid, creditsAreValid else { return }
        let term = ensureTerm()
        term.gpa = gpaText.isEmpty ? nil : parsedGPA
        term.totalCredits = creditsText.isEmpty ? nil : parsedCredits
        try? context.save()
    }

    // MARK: - โหมดรายวิชา

    private var detailedSubjectsCard: some View {
        CardContainer {
            // maxWidth บังคับไว้เพราะ CardContainer กว้างตามเนื้อหา — การ์ดนี้ตอนยังไม่มี
            // วิชาจะแคบกว่าการ์ดอื่นในหน้าเดียวกัน
            Text("รายวิชา")
                .font(Theme.Font.plex(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if subjects.isEmpty {
                Text(termHasTimetable
                     ? "ยังไม่มีวิชา — ดึงจากตารางเรียน หรือเพิ่มเอง"
                     : "ยังไม่มีวิชา — กด \"เพิ่มวิชา\" เพื่อเริ่ม")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(subjects) { subject in
                        TermGradeSubjectRow(
                            subject: subject,
                            onChanged: recomputeDetailedTotals,
                            onDelete: { delete(subject) }
                        )
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    isPickingSubject = true
                } label: {
                    Label("เพิ่มวิชา", systemImage: "plus.circle.fill")
                        .font(Theme.Font.plex(13, .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.primary)

                Button {
                    let term = ensureTerm()
                    seedSubjectsFromTimetable(term: term)
                    recomputeDetailedTotals()
                } label: {
                    Label("ดึงจากตารางเรียน", systemImage: "arrow.clockwise")
                        .font(Theme.Font.plex(13, .medium))
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.primary)
                .disabled(!termHasTimetable)
            }
        }
    }

    private var detailedSummaryCard: some View {
        CardContainer {
            Text("สรุปของเทอมนี้")
                .font(Theme.Font.plex(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("เกรดเฉลี่ย")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(summaryGPA.map { String(format: "%.2f", $0) } ?? "—")
                    .font(Theme.Font.plex(19, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            HStack {
                Text("หน่วยกิตรวม")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("\(String(format: "%.1f", summaryCredits)) นก.")
                    .font(Theme.Font.plex(15, .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    /// ชื่อมาจาก `SubjectPickerSheet` เสมอ — เดิมแถวใหม่ชื่อ "วิชาใหม่" แล้วต้องมาพิมพ์ทับเอง
    /// ซึ่งเป็นบ่อเกิดของชื่อวิชาที่สะกดไม่ตรงกับตารางเรียน
    private func addSubject(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let term = ensureTerm()
        guard !subjects.contains(where: { $0.name == trimmed }) else { return }
        let order = (subjects.map(\.sortOrder).max() ?? -1) + 1
        context.insert(TermGradeSubject(term: term, name: trimmed, sortOrder: order))
        try? context.save()
        recomputeDetailedTotals()
    }

    /// ไม่มี `List` แล้ว = ไม่มี swipe-to-delete — ปุ่มถังขยะในแถวแทน
    private func delete(_ subject: TermGradeSubject) {
        context.delete(subject)
        try? context.save()
        recomputeDetailedTotals()
    }

    /// วิชาที่ยังไม่มีในลิสต์เท่านั้นที่ถูกเพิ่ม — ไม่เคยลบของเดิม แม้คาบนั้นจะ
    /// ถูกลบออกจากตารางเรียนไปแล้วก็ตาม (เกรดที่กรอกไว้ต้องไม่หายเงียบๆ)
    private func seedSubjectsFromTimetable(term: Term) {
        let entries = seedEntries
        var existingNames = Set(subjects.map(\.name))
        var order = (subjects.map(\.sortOrder).max() ?? -1) + 1

        for entry in entries.sorted(by: { $0.periodNumber < $1.periodNumber }) {
            guard let subject = entry.subject, !subject.isBreak else { continue }
            guard existingNames.insert(subject.name).inserted else { continue }
            context.insert(TermGradeSubject(
                term: term,
                name: subject.name,
                code: subject.code,
                sortOrder: order
            ))
            order += 1
        }
        try? context.save()
    }

    private func recomputeDetailedTotals() {
        guard usesDetailed else { return }
        let term = ensureTerm()
        term.gpa = summaryCredits > 0 ? summaryGPA : nil
        term.totalCredits = summaryCredits > 0 ? summaryCredits : nil
        try? context.save()
    }

    private func ensureTerm() -> Term {
        TermStore.findOrCreate(gradeLevel: gradeLevel, termNumber: termNumber, in: context)
    }
}

// MARK: - ชิ้นส่วนของหน้า

/// หัวข้อ + ช่องกรอก + คำใบ้ + ข้อความ error — รูปแบบเดียวกันทุกช่องในหน้านี้
private struct FieldBlock<Field: View>: View {
    let title: String
    let hint: String?
    let error: String?
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Font.plex(15, .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
            field
            if let hint {
                Text(hint)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.danger)
            }
        }
    }
}

/// ช่องตัวเลขหน้าตาเดียวกันทั้งหน้า — `Form` เคยวาดกรอบให้ฟรี พอทิ้ง Form
/// ต้องวาดเอง ไม่งั้นช่องกรอกกลืนไปกับพื้นการ์ด
private struct ThemedNumberField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.Font.plex(17, .medium))
            .foregroundStyle(Theme.Colors.textPrimary)
            .keyboardType(.decimalPad)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .stroke(Theme.Colors.separator, lineWidth: 1)
            )
    }
}

private struct TermGradeSubjectRow: View {
    @Bindable var subject: TermGradeSubject
    let onChanged: () -> Void
    let onDelete: () -> Void

    /// หน่วยกิตเป็นช่องพิมพ์ — เก็บเป็นข้อความระหว่างพิมพ์ แล้วเขียนกลับลง model
    /// เฉพาะตอนค่าอยู่ในช่วง 0.5–4.0 (ระหว่างพิมพ์ "1." ค่ายังไม่ valid)
    @State private var creditsText: String

    init(subject: TermGradeSubject, onChanged: @escaping () -> Void, onDelete: @escaping () -> Void) {
        _subject = Bindable(subject)
        self.onChanged = onChanged
        self.onDelete = onDelete
        _creditsText = State(initialValue: String(format: "%.1f", subject.creditHours))
    }

    private var parsedCredits: Double? { Double(creditsText) }
    private var creditsAreValid: Bool {
        parsedCredits.map { (0.5...4.0).contains($0) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                TextField("ชื่อวิชา", text: $subject.name)
                    .font(Theme.Font.plex(15, .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .onChange(of: subject.name) { _, _ in onChanged() }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("ลบวิชา \(subject.name)")
            }

            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("หน่วยกิต")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    ThemedNumberField(placeholder: "1.0", text: $creditsText)
                        .frame(width: 84)
                        .onChange(of: creditsText) { _, _ in saveCredits() }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("เกรด")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    gradeStepper
                }

                Spacer(minLength: 0)
            }

            if !creditsAreValid {
                Text("หน่วยกิตกรอกได้ 0.5–4.0")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.danger)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    /// เลื่อนทีละขั้นตามสเกลไทย (0 · 1 · 1.5 … 4) — ไม่ใช่ทีละ 0.5 ตรงๆ
    /// เพราะเกรด 0.5 ไม่มีจริง
    private var gradeStepper: some View {
        Stepper(
            value: Binding(
                get: { gradeIndex },
                set: { setGradeIndex($0) }
            ),
            in: 0...(TermGradeEditView.gradeSteps.count - 1)
        ) {
            Text(String(format: "%.1f", subject.gradePoint))
                .font(Theme.Font.plex(17, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(minWidth: 34, alignment: .leading)
        }
        .fixedSize()
    }

    private var gradeIndex: Int {
        // 4 = 2.5 ซึ่งเป็นค่า default ของ TermGradeSubject.gradePoint
        TermGradeEditView.gradeSteps.firstIndex(of: subject.gradePoint) ?? 4
    }

    private func setGradeIndex(_ index: Int) {
        let steps = TermGradeEditView.gradeSteps
        let clamped = min(max(index, 0), steps.count - 1)
        guard subject.gradePoint != steps[clamped] else { return }
        subject.gradePoint = steps[clamped]
        onChanged()
    }

    private func saveCredits() {
        guard let value = parsedCredits, (0.5...4.0).contains(value) else { return }
        guard subject.creditHours != value else { return }
        subject.creditHours = value
        onChanged()
    }
}

#Preview {
    NavigationStack {
        TermGradeEditView(gradeLevel: 5, termNumber: 2, existingTerm: nil)
    }
    .modelContainer(for: [Term.self, TermSubject.self, TermGradeSubject.self, ScheduleEntry.self, Subject.self], inMemory: true)
}
