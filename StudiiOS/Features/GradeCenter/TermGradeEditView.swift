//
//  TermGradeEditView.swift
//  Pushed page (not a sheet) for one term's grades. Opened from a past or
//  current row in TermGradeListSection. Replaces the old TermGradeEditSheet.
//
//  Simple mode writes term.gpa/totalCredits directly (old behaviour).
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
    /// หนึ่ง `.sheet` ต่อหนึ่ง view — สองตัวแขวนที่เดียวกันแล้วตัวหลังจะปิดตัวแรกทิ้ง
    private enum ActiveSheet: String, Identifiable {
        case cumulative, addSubject
        var id: String { rawValue }
    }

    @State private var activeSheet: ActiveSheet?

    /// Thai 8-step grade point scale.
    static let gradeSteps: [Double] = [0, 1, 1.5, 2, 2.5, 3, 3.5, 4]

    init(gradeLevel: Int, termNumber: Int, existingTerm: Term?, seedFrom: Term? = nil) {
        self.gradeLevel = gradeLevel
        self.termNumber = termNumber
        self.seedFrom = seedFrom
        _usesDetailed = State(initialValue: existingTerm?.usesDetailedGrades ?? false)
        // เทอมที่ยังไม่มีข้อมูลเลย prefill 2.00 ไว้เป็นคำตอบเริ่มต้น
        _gpaText = State(initialValue: existingTerm?.gpa.map { String(format: "%.2f", $0) } ?? "2.00")
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
        Form {
            Section {
                Toggle("กรอกละเอียด", isOn: $usesDetailed)
            }

            if usesDetailed {
                detailedSubjectsSection
                detailedSummarySection
            } else {
                simpleGPASection
                simpleCreditsSection
                cumulativeSection
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: usesDetailed) { _, new in
            let term = ensureTerm()
            term.usesDetailedGrades = new
            try? context.save()
            if new {
                seedSubjectsFromTimetable(term: term)
                recomputeDetailedTotals()
            }
        }
        .onChange(of: gpaText) { _, _ in saveSimpleGrade() }
        .onChange(of: creditsText) { _, _ in saveSimpleGrade() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .cumulative:
                CumulativeGPAXSheet(onDone: {})
            case .addSubject:
                SubjectPickerSheet(allowsCustomName: true) { name, _ in
                    addSubject(named: name)
                }
            }
        }
    }

    // MARK: - Simple mode

    private var simpleGPASection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("เกรดเฉลี่ยเทอมนี้")
                    .font(Theme.Font.plex(15, .medium))
                TextField("เช่น 3.28", text: $gpaText)
                    .keyboardType(.decimalPad)
                Text("อยู่บนใบ ปพ.1 ช่อง \"ผลการเรียนเฉลี่ย\"")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if !gpaIsValid {
                    Text("กรอกได้ 0.00–4.00")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.danger)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private var simpleCreditsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("หน่วยกิตรวม (ไม่บังคับ)")
                    .font(Theme.Font.plex(15, .medium))
                TextField("เช่น 20.0", text: $creditsText)
                    .keyboardType(.decimalPad)
                Text("ไม่กรอกก็ได้ แต่ GPAX จะคลาดเคลื่อน ±0.03")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if !creditsAreValid {
                    Text("กรอกได้ 0.5–40.0")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.danger)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private var cumulativeSection: some View {
        Section {
            Button("จำเกรดเทอมนี้ไม่ได้") { activeSheet = .cumulative }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func saveSimpleGrade() {
        guard gpaIsValid, creditsAreValid else { return }
        let term = ensureTerm()
        term.gpa = gpaText.isEmpty ? nil : parsedGPA
        term.totalCredits = creditsText.isEmpty ? nil : parsedCredits
        try? context.save()
    }

    // MARK: - Detailed mode

    private var detailedSubjectsSection: some View {
        Section {
            ForEach(subjects) { subject in
                TermGradeSubjectRow(subject: subject, onChanged: recomputeDetailedTotals)
            }
            .onDelete(perform: deleteSubjects)

            Button {
                activeSheet = .addSubject
            } label: {
                Label("เพิ่มวิชา", systemImage: "plus.circle.fill")
            }

            Button {
                let term = ensureTerm()
                seedSubjectsFromTimetable(term: term)
                recomputeDetailedTotals()
            } label: {
                Label("ดึงวิชาจากตารางเรียนอีกครั้ง", systemImage: "arrow.clockwise")
            }
            .font(Theme.Font.caption)
            .disabled(!termHasTimetable)
        } header: {
            Text("รายวิชา")
        } footer: {
            if subjects.isEmpty {
                Text(termHasTimetable
                     ? "ยังไม่มีวิชา — กด \"ดึงวิชาจากตารางเรียน\" หรือเพิ่มเอง"
                     : "เทอมนี้ยังไม่มีตารางเรียน — กด \"เพิ่มวิชา\" เพื่อเริ่มกรอกเอง")
            }
        }
    }

    private var detailedSummarySection: some View {
        Section("สรุป") {
            HStack {
                Text("เกรดเฉลี่ย")
                Spacer()
                Text(summaryGPA.map { String(format: "%.2f", $0) } ?? "—")
                    .fontWeight(.semibold)
            }
            HStack {
                Text("หน่วยกิตรวม")
                Spacer()
                Text("\(String(format: "%.1f", summaryCredits)) นก.")
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

    private func deleteSubjects(at offsets: IndexSet) {
        for index in offsets { context.delete(subjects[index]) }
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

private struct TermGradeSubjectRow: View {
    @Bindable var subject: TermGradeSubject
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            TextField("ชื่อวิชา", text: $subject.name)
                .font(Theme.Font.plex(14, .medium))
                .onChange(of: subject.name) { _, _ in onChanged() }

            HStack {
                Stepper(
                    "หน่วยกิต \(String(format: "%.1f", subject.creditHours))",
                    value: $subject.creditHours,
                    in: 0.5...4.0,
                    step: 0.5
                )
                .font(Theme.Font.caption)
                .onChange(of: subject.creditHours) { _, _ in onChanged() }
            }

            HStack {
                Text("เกรด")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Stepper(
                    String(format: "%.1f", subject.gradePoint),
                    onIncrement: { stepGrade(by: 1) },
                    onDecrement: { stepGrade(by: -1) }
                )
                .fixedSize()
                .font(Theme.Font.plex(14, .semibold))
                .onChange(of: subject.gradePoint) { _, _ in onChanged() }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func stepGrade(by delta: Int) {
        let steps = TermGradeEditView.gradeSteps
        guard let currentIndex = steps.firstIndex(of: subject.gradePoint) else {
            subject.gradePoint = 2.5
            return
        }
        let newIndex = min(max(currentIndex + delta, 0), steps.count - 1)
        subject.gradePoint = steps[newIndex]
    }
}

#Preview {
    NavigationStack {
        TermGradeEditView(gradeLevel: 5, termNumber: 2, existingTerm: nil)
    }
    .modelContainer(for: [Term.self, TermSubject.self, TermGradeSubject.self, ScheduleEntry.self, Subject.self], inMemory: true)
}
