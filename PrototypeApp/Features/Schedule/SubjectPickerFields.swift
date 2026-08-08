//
//  SubjectPickerFields.swift
//  The two-level subject chooser (กลุ่มสาระ → รายวิชา) shared by
//  AddScheduleEntrySheet and ScheduleImportRowEditSheet. One file so the two
//  screens cannot drift apart — Few asked for them to look the same.
//
//  Renders Form rows only, never a Section, so each caller can add its own
//  extra rows (OCR code options, the existing-Subject picker) beside these.
//
//  The dropdowns are a convenience, never a constraint: the free-text name
//  field is always visible, always editable, and always wins.
//

import SwiftUI

struct SubjectPickerFields: View {
    @Binding var name: String
    @Binding var code: String

    /// Called when the user actively changes the name/code, so a caller that
    /// tracks "this was guessed" flags can clear the right one. nil when the
    /// caller has no such flags.
    var onNameEdited: (() -> Void)? = nil
    var onCodeEdited: (() -> Void)? = nil

    /// nil = "อื่นๆ / ไม่ระบุ" — the free-text name field is the answer instead.
    @State private var strandChoice: ThaiSubjectStrand?
    /// nil = "อื่นๆ (พิมพ์เอง)".
    @State private var nameChoice: String?

    // @ViewBuilder rather than a Group: the rows go straight into the caller's
    // Form, and Group's overload set (View / Scene / TableColumn / …) is
    // needlessly ambiguous here.
    @ViewBuilder
    var body: some View {
        strandPicker

        if let strandChoice {
            commonNamePicker(for: strandChoice)
        }

        TextField("ชื่อวิชา", text: $name)

        codeField
    }

    // MARK: - Rows

    private var strandPicker: some View {
        Picker("กลุ่มสาระ", selection: $strandChoice) {
            Text("อื่นๆ / ไม่ระบุ").tag(ThaiSubjectStrand?.none)
            ForEach(ThaiSubjectStrand.allCases) { strand in
                Text(strand.displayName).tag(ThaiSubjectStrand?.some(strand))
            }
        }
    }

    private func commonNamePicker(for strand: ThaiSubjectStrand) -> some View {
        Picker("รายวิชา", selection: $nameChoice) {
            Text("อื่นๆ (พิมพ์เอง)").tag(String?.none)
            ForEach(strand.commonSubjects, id: \.self) { subject in
                Text(subject).tag(String?.some(subject))
            }
        }
    }

    /// Every lifecycle modifier hangs off this one row on purpose. Attaching
    /// them to the enclosing `Group` would apply them to each child, so a
    /// single edit would fire the handler four times.
    private var codeField: some View {
        TextField("รหัสวิชา", text: $code)
            .autocorrectionDisabled()
            .onAppear(perform: syncFromCurrentValues)
            .onChange(of: code) { _, new in codeChanged(new) }
            .onChange(of: strandChoice) { _, new in strandChanged(new) }
            .onChange(of: nameChoice) { _, new in nameChoiceChanged(new) }
            .onChange(of: name) { _, new in nameChanged(new) }
    }

    // MARK: - Sync

    private func syncFromCurrentValues() {
        strandChoice = ThaiSubjectCatalog.parse(code)?.strand
        let isKnownName = strandChoice?.commonSubjects.contains(name) ?? false
        nameChoice = isKnownName ? name : nil
    }

    /// A valid code names its strand, so follow it. A half-typed code does not
    /// mean the user changed their mind about the strand, so never clear it.
    private func codeChanged(_ new: String) {
        onCodeEdited?()
        guard let parsed = ThaiSubjectCatalog.parse(new)?.strand, parsed != strandChoice else { return }
        strandChoice = parsed
    }

    /// Drops a รายวิชา selection the new strand cannot offer. Never touches
    /// `name` — the typed name outlives the dropdown that suggested it.
    private func strandChanged(_ new: ThaiSubjectStrand?) {
        let stillOffered = new?.commonSubjects.contains(name) ?? false
        if !stillOffered { nameChoice = nil }
    }

    private func nameChoiceChanged(_ new: String?) {
        guard let new else { return }
        name = new
        onNameEdited?()
    }

    /// Typing something the dropdown does not say means the dropdown is no
    /// longer describing this row. Guarded on an actual difference, otherwise
    /// this and `nameChoiceChanged` bounce off each other forever.
    private func nameChanged(_ new: String) {
        onNameEdited?()
        if new != nameChoice { nameChoice = nil }
    }
}
