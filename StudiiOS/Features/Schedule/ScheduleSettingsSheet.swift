//
//  ScheduleSettingsSheet.swift
//  Opened from ScheduleView's gear button. Lets the student switch which
//  term's timetable is active, and holds "ร่นคาบวันนี้" (which used to be its
//  own toolbar button). Switching term does NOT dismiss this sheet — the
//  picker just updates in place.
//

import SwiftUI
import SwiftData

struct ScheduleSettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let day: Int
    let dayEntries: [ScheduleEntry]
    let targetDate: Date
    let existingOverride: DayScheduleOverride?

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    @Query private var allScheduleEntries: [ScheduleEntry]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    @State private var isShiftingPeriods = false

    /// nil เมื่อเทอมที่ใช้อยู่ไม่ได้อยู่ในเมนูนี้ (เช่น เทอม ม.ต้น ที่เคยสร้างไว้ก่อนหน้า)
    /// — เมนูจะไม่มี tag ตรงกับมัน ต้องคืน nil ให้ Picker แสดง "ยังไม่เลือก"
    /// แทนที่จะยัดค่าเก่าที่ไม่มีอยู่ในเมนูเข้าไป
    private var termSelection: Binding<Int?> {
        Binding(
            get: {
                guard let activeTerm, SchoolBand.upper.gradeLevels.contains(activeTerm.gradeLevel) else { return nil }
                return activeTerm.sortKey
            },
            set: { newSortKey in
                guard let newSortKey else { return }
                let gradeLevel = newSortKey / 10
                let termNumber = newSortKey % 10
                let term = TermStore.findOrCreate(gradeLevel: gradeLevel, termNumber: termNumber, in: context)
                TermStore.setActive(term)
                TermStore.syncTermSubjects(for: term, in: context)
                try? context.save()
            }
        )
    }

    private func entryCount(gradeLevel: Int, termNumber: Int) -> Int {
        guard let term = terms.first(where: { $0.gradeLevel == gradeLevel && $0.termNumber == termNumber }) else {
            return 0
        }
        return allScheduleEntries.filter { $0.term?.id == term.id }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("เทอม", selection: termSelection) {
                        ForEach(SchoolBand.upper.gradeLevels, id: \.self) { level in
                            ForEach([1, 2], id: \.self) { termNumber in
                                let count = entryCount(gradeLevel: level, termNumber: termNumber)
                                Text(count > 0 ? "ม.\(level) เทอม \(termNumber) (\(count) คาบ)" : "ม.\(level) เทอม \(termNumber)")
                                    .tag(Int?(level * 10 + termNumber))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("เทอม")
                } footer: {
                    if termSelection.wrappedValue == nil, let activeTerm {
                        Text("ตอนนี้ใช้ \(activeTerm.displayName) อยู่ — เลือกเทอมด้านบนเพื่อสลับมา")
                    } else {
                        Text("ตารางสอน งาน และคะแนน จะแยกเก็บตามเทอม")
                    }
                }

                Section("วันนี้") {
                    Button {
                        isShiftingPeriods = true
                    } label: {
                        HStack {
                            Label("ร่นคาบวันนี้", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)

                    if let existingOverride {
                        Text("ร่นจากคาบ \(existingOverride.startPeriodNumber) เวลา \(existingOverride.startMinute.asClockString)")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                Section {
                    NavigationLink {
                        TermManagementView()
                    } label: {
                        Text("จัดการเทอมทั้งหมด")
                    }
                }
            }
            .navigationTitle("ตั้งค่าตารางสอน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
            .sheet(isPresented: $isShiftingPeriods) {
                PeriodShiftSheet(
                    day: day,
                    dayEntries: dayEntries,
                    targetDate: targetDate,
                    existing: existingOverride
                )
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Subject.self, ScheduleEntry.self, DayScheduleOverride.self, Term.self, TermSubject.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let term = Term(gradeLevel: 4, termNumber: 1)
    container.mainContext.insert(term)
    TermStore.setActive(term)

    return Text("").sheet(isPresented: .constant(true)) {
        ScheduleSettingsSheet(day: 1, dayEntries: [], targetDate: .now, existingOverride: nil)
    }
    .modelContainer(container)
}
