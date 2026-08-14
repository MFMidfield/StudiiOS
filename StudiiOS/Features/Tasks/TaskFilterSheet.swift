//
//  TaskFilterSheet.swift
//  Secondary filters that don't fit in the chip bar: ประเภท · วิชา · เลยกำหนด · เรียงตาม
//

import SwiftUI
import SwiftData

struct TaskFilterSheet: View {
    @Binding var kindFilter: TaskKindFilter
    @Binding var subjectFilter: String
    @Binding var overdueOnly: Bool
    @Binding var sortOrder: TaskSortOrder

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    private var selectableSubjects: [Subject] {
        subjects.filter { !$0.isBreak }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ประเภท") {
                    Picker("ประเภท", selection: $kindFilter) {
                        ForEach(TaskKindFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("วิชา") {
                    Picker("วิชา", selection: $subjectFilter) {
                        Text("ทุกวิชา").tag("")
                        ForEach(selectableSubjects) { subject in
                            Text(subject.name).tag(subject.name)
                        }
                    }
                    .disabled(kindFilter == .personal)
                }

                Section {
                    Toggle("เฉพาะงานที่เลยกำหนด", isOn: $overdueOnly)
                }

                Section("เรียงตาม") {
                    Picker("เรียงตาม", selection: $sortOrder) {
                        ForEach(TaskSortOrder.allCases) { order in
                            Text(order.label).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button("ล้างตัวกรอง", role: .destructive, action: reset)
                }
            }
            .navigationTitle("กรอง")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func reset() {
        kindFilter = .all
        subjectFilter = ""
        overdueOnly = false
        sortOrder = .dueDate
    }
}

#Preview {
    TaskFilterSheet(
        kindFilter: .constant(.all),
        subjectFilter: .constant(""),
        overdueOnly: .constant(false),
        sortOrder: .constant(.dueDate)
    )
    .modelContainer(for: [Subject.self], inMemory: true)
}
