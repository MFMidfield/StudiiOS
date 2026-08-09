//
//  TermGradeEditSheet.swift
//  Screen 3 (§6.3) — GPA + credits for one term. Opened by tapping a past or
//  current row in TermGradeListSection.
//
//  Saving is the only place that ever creates a Term row here, and it goes
//  through TermStore.findOrCreate — never `context.insert(Term(...))` directly.
//

import SwiftUI
import SwiftData

struct TermGradeEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let gradeLevel: Int
    let termNumber: Int

    @State private var gpaText: String
    @State private var creditsText: String
    @State private var showCumulativeSheet = false

    init(gradeLevel: Int, termNumber: Int, existingTerm: Term?) {
        self.gradeLevel = gradeLevel
        self.termNumber = termNumber
        _gpaText = State(initialValue: existingTerm?.gpa.map { String(format: "%.2f", $0) } ?? "")
        _creditsText = State(initialValue: existingTerm?.totalCredits.map { String(format: "%.1f", $0) } ?? "")
    }

    private var displayName: String { "ม.\(gradeLevel) เทอม \(termNumber)" }

    private var parsedGPA: Double? { Double(gpaText) }
    private var parsedCredits: Double? { Double(creditsText) }

    private var gpaIsValid: Bool {
        gpaText.isEmpty || (parsedGPA.map { (0.0...4.0).contains($0) } ?? false)
    }
    private var creditsAreValid: Bool {
        creditsText.isEmpty || (parsedCredits.map { (0.5...40.0).contains($0) } ?? false)
    }
    private var canSave: Bool { gpaIsValid && creditsAreValid }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("เกรดเฉลี่ยเทอมนี้")
                            .font(.subheadline).fontWeight(.medium)
                        TextField("เช่น 3.28", text: $gpaText)
                            .keyboardType(.decimalPad)
                        Text("อยู่บนใบ ปพ.1 ช่อง \"ผลการเรียนเฉลี่ย\"")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        if !gpaIsValid {
                            Text("กรอกได้ 0.00–4.00")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.danger)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }

                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("หน่วยกิตรวม (ไม่บังคับ)")
                            .font(.subheadline).fontWeight(.medium)
                        TextField("เช่น 20.0", text: $creditsText)
                            .keyboardType(.decimalPad)
                        Text("ไม่กรอกก็ได้ แต่ GPAX จะคลาดเคลื่อน ±0.03")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        if !creditsAreValid {
                            Text("กรอกได้ 0.5–40.0")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.danger)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }

                Section {
                    Button("จำเกรดเทอมนี้ไม่ได้") { showCumulativeSheet = true }
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .navigationTitle("ผลการเรียน \(displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") { save() }
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showCumulativeSheet) {
                CumulativeGPAXSheet(onDone: { dismiss() })
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let term = TermStore.findOrCreate(gradeLevel: gradeLevel, termNumber: termNumber, in: context)
        term.gpa = gpaText.isEmpty ? nil : parsedGPA
        term.totalCredits = creditsText.isEmpty ? nil : parsedCredits
        try? context.save()
        dismiss()
    }
}

#Preview {
    TermGradeEditSheet(gradeLevel: 5, termNumber: 2, existingTerm: nil)
        .modelContainer(for: [Term.self, TermSubject.self], inMemory: true)
}
