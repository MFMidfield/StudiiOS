//
//  GradeBacklogSetupView.swift
//  หน้า 4 ของ setup — เกรดของเทอมที่ผ่านมาแล้ว
//
//  เทอมที่ให้กรอก = ทุกเทอม ม.ปลายที่ `sortKey` น้อยกว่าเทอมปัจจุบัน (จากหน้า 2)
//  เทอมปัจจุบันกรอกไม่ได้โดยตั้งใจ — `GPAXCalculator` นับเฉพาะเทอมที่จบไปแล้ว
//  ถ้ากรอกให้เทอมที่กำลังเรียน ตัวเลขจะถูกเมินทั้งหมดแบบเงียบๆ
//
//  ม.4 เทอม 1 = ไม่มีเทอมก่อนหน้าเลย → `OnboardingFlowView` ข้ามหน้านี้ไปตั้งแต่แรก
//  ไม่ใช่เข้ามาแล้วเด้งออก (เด้งออกเองแปลว่าปัดย้อนกลับมาหน้านี้ไม่ได้อีก)
//
//  เขียนลง `Term.gpa` / `Term.totalCredits` ผ่าน `TermStore.findOrCreate` เท่านั้น
//  โหมดละเอียดใช้ `TermGradeEditView` ตัวเดียวกับหน้าเกรดจริง — สูตรถ่วงน้ำหนัก
//  หน่วยกิตจึงมีอยู่ที่เดียว
//

import SwiftUI
import SwiftData

struct GradeBacklogSetupView: View {
    let onBack: () -> Void
    let onNext: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var allTerms: [Term]
    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""

    @State private var editingSlot: TermSlot?

    /// เทอมย้อนหลังที่ควรถาม — ว่างเมื่อเพิ่งขึ้น ม.4 เทอม 1
    static var backlogSortKeys: [Int] {
        guard let current = GPAXSettings.currentSortKey else { return [] }
        return GPAXCalculator.upperBandSortKeys.filter { $0 < current }
    }

    static var hasBacklog: Bool { !backlogSortKeys.isEmpty }

    private var slots: [TermSlot] {
        Self.backlogSortKeys.map { TermSlot(sortKey: $0) }
    }

    private var filledCount: Int {
        slots.filter { term(for: $0)?.gpa != nil }.count
    }

    private var currentTerm: Term? { TermStore.find(idString: activeTermID, in: allTerms) }

    var body: some View {
        OnboardingScaffold(
            step: .grades,
            onBack: onBack,
            primaryTitle: filledCount == 0 ? "ยังไม่กรอก ข้ามไปก่อน" : "ถัดไป",
            onPrimary: onNext
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                explainer
                ForEach(slots) { slot in
                    TermGradeCard(
                        slot: slot,
                        term: term(for: slot),
                        onEdit: { editingSlot = slot },
                        onChange: { gpa, credits in save(slot: slot, gpa: gpa, credits: credits) }
                    )
                }
            }
        }
        .sheet(item: $editingSlot) { slot in
            NavigationStack {
                TermGradeEditView(
                    gradeLevel: slot.gradeLevel,
                    termNumber: slot.termNumber,
                    existingTerm: term(for: slot),
                    // เทอมย้อนหลังไม่มีตารางเรียนของตัวเอง ยืมรายวิชาจากเทอมปัจจุบันมาตั้งต้น
                    seedFrom: currentTerm
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("เสร็จ") { editingSlot = nil }
                    }
                }
            }
        }
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Text("กรอกเท่าที่จำได้ก็พอ ข้ามไปเลยก็ได้ แล้วค่อยมาเติมทีหลังที่หน้าเกรด — ยิ่งกรอกครบ ตัวเลข GPAX กับเป้าที่ต้องทำยิ่งตรงความจริง")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    // MARK: - Data

    private func term(for slot: TermSlot) -> Term? {
        allTerms.first { $0.gradeLevel == slot.gradeLevel && $0.termNumber == slot.termNumber }
    }

    /// สร้าง `Term` ต่อเมื่อมีตัวเลขจริงเท่านั้น — ไม่งั้นแค่แตะช่องก็ได้เทอมเปล่า 5 แถว
    /// ค้างในหน้า "จัดการเทอม"
    private func save(slot: TermSlot, gpa: Double?, credits: Double?) {
        if gpa == nil, term(for: slot) == nil { return }
        let term = TermStore.findOrCreate(gradeLevel: slot.gradeLevel,
                                          termNumber: slot.termNumber,
                                          in: context)
        term.gpa = gpa
        term.totalCredits = credits
        try? context.save()
    }
}

// MARK: - Slot

/// ช่องเทอมหนึ่งช่อง ยังไม่ใช่แถวในฐานข้อมูล (เทอมถูกสร้างแบบ lazy — D4)
struct TermSlot: Identifiable, Hashable {
    let sortKey: Int

    var id: Int { sortKey }
    var gradeLevel: Int { sortKey / 10 }
    var termNumber: Int { sortKey % 10 }
    var displayName: String { "ม.\(gradeLevel) เทอม \(termNumber)" }
}

// MARK: - Card

private struct TermGradeCard: View {
    let slot: TermSlot
    let term: Term?
    let onEdit: () -> Void
    let onChange: (_ gpa: Double?, _ credits: Double?) -> Void

    @State private var gpaText = ""
    @State private var creditsText = ""
    @FocusState private var isEditingGPA: Bool

    /// หน่วยกิตต่อเทอมของ ม.ปลายส่วนใหญ่อยู่แถวนี้ — ใส่ให้ก่อนแล้วแก้ได้
    private static let defaultCredits = GPAXCalculator.defaultTermCredits

    private var parsedGPA: Double? {
        let value = Double(gpaText)
        guard let value, (0.0...4.0).contains(value) else { return nil }
        return value
    }

    private var parsedCredits: Double? {
        let value = Double(creditsText)
        guard let value, (0.5...40.0).contains(value) else { return nil }
        return value
    }

    private var gpaIsInvalid: Bool { !gpaText.isEmpty && parsedGPA == nil }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                if term?.usesDetailedGrades == true {
                    detailedSummary
                } else {
                    fields
                }
                Button(action: onEdit) {
                    Label(term?.usesDetailedGrades == true ? "แก้รายวิชา" : "กรอกละเอียดเป็นรายวิชา",
                          systemImage: "list.bullet.rectangle")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.primaryDeep)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear(perform: prefill)
    }

    private var header: some View {
        HStack {
            Text(slot.displayName)
                .font(Theme.Font.plex(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if let gpa = term?.gpa {
                PillLabel(String(format: "%.2f", gpa), tone: .accent)
            } else {
                Text("ยังไม่กรอก")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var fields: some View {
        HStack(spacing: Theme.Spacing.md) {
            valueField(title: "เกรดเฉลี่ย", placeholder: "3.25", text: $gpaText)
                .focused($isEditingGPA)
            valueField(title: "หน่วยกิต", placeholder: "20", text: $creditsText)
        }
        .overlay(alignment: .bottomLeading) {
            if gpaIsInvalid {
                Text("กรอกได้ 0.00–4.00")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.danger)
                    .offset(y: 18)
            }
        }
    }

    private func valueField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            TextField(placeholder, text: text)
                .font(Theme.Font.body)
                .keyboardType(.decimalPad)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .onChange(of: text.wrappedValue) { _, _ in commit() }
        }
    }

    private var detailedSummary: some View {
        HStack {
            Text("กรอกเป็นรายวิชาไว้แล้ว")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text("\(String(format: "%.1f", term?.totalCredits ?? 0)) นก.")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func prefill() {
        guard gpaText.isEmpty, creditsText.isEmpty else { return }
        gpaText = term?.gpa.map { String(format: "%.2f", $0) } ?? ""
        creditsText = term?.totalCredits.map { String(format: "%.1f", $0) }
            ?? String(format: "%.0f", Self.defaultCredits)
    }

    /// เกรดว่าง = ยังไม่กรอก (เขียน nil) · หน่วยกิตว่าง = ใช้ค่ากลางของ GPAXCalculator
    private func commit() {
        guard !gpaIsInvalid else { return }
        onChange(parsedGPA, parsedGPA == nil ? nil : parsedCredits)
    }
}
