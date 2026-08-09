//
//  TermManagementView.swift
//  Lists every term that actually exists in the DB (lazy creation — decision
//  D4 in PLAN_TermSystem — means a term row only exists once the user has
//  picked it at least once). Tap to switch, swipe to delete.
//

import SwiftUI
import SwiftData

struct TermManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    @Query private var scheduleEntries: [ScheduleEntry]
    @Query private var assignments: [Assignment]
    @Query private var gradeComponents: [GradeComponent]

    @State private var termPendingDelete: Term?

    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    private var sortedTerms: [Term] {
        terms.sorted { $0.sortKey < $1.sortKey }
    }

    private func counts(for term: Term) -> (entries: Int, assignments: Int, grades: Int) {
        (
            scheduleEntries.filter { $0.term?.id == term.id }.count,
            assignments.filter { $0.term?.id == term.id }.count,
            gradeComponents.filter { $0.term?.id == term.id }.count
        )
    }

    var body: some View {
        List {
            Section {
                ForEach(sortedTerms) { term in
                    termRow(term)
                }
            } footer: {
                Text("แตะเพื่อสลับเทอม · ปัดซ้ายเพื่อลบ")
            }
        }
        .navigationTitle("เทอมทั้งหมด")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            termPendingDelete.map { "ลบ \($0.displayName)?" } ?? "",
            isPresented: Binding(
                get: { termPendingDelete != nil },
                set: { if !$0 { termPendingDelete = nil } }
            )
        ) {
            Button("ลบ", role: .destructive) {
                if let term = termPendingDelete { performDelete(term) }
                termPendingDelete = nil
            }
            Button("ยกเลิก", role: .cancel) { termPendingDelete = nil }
        } message: {
            if let term = termPendingDelete {
                let c = counts(for: term)
                Text("คาบเรียน \(c.entries), งาน \(c.assignments), คะแนน \(c.grades) รายการ จะถูกลบถาวร")
            }
        }
    }

    private func termRow(_ term: Term) -> some View {
        let c = counts(for: term)
        return Button {
            TermStore.setActive(term)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(term.displayName)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(c.entries) คาบ · \(c.assignments) งาน")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                if term.id == activeTerm?.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                termPendingDelete = term
            } label: {
                Label("ลบ", systemImage: "trash")
            }
        }
    }

    private func performDelete(_ term: Term) {
        TermStore.delete(term, in: context)
        TermStore.bootstrap(in: context)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Term.self, TermSubject.self, ScheduleEntry.self, Assignment.self, GradeComponent.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let t1 = Term(gradeLevel: 4, termNumber: 1)
    let t2 = Term(gradeLevel: 4, termNumber: 2)
    [t1, t2].forEach { container.mainContext.insert($0) }
    TermStore.setActive(t1)

    return NavigationStack { TermManagementView() }
        .modelContainer(container)
}
