//
//  AssignmentListView.swift
//  Global "งาน & To-Do" list, with Smart Rules-style
//  priority sorting (overdue/high-priority first).
//

import SwiftUI
import SwiftData

struct AssignmentListView: View {
    @Query private var assignments: [Assignment]
    @Environment(\.modelContext) private var context
    @State private var showDone = false

    private var sorted: [Assignment] {
        assignments
            .filter { showDone || !$0.isDone }
            .sorted { lhs, rhs in
                if lhs.dueDate != rhs.dueDate { return lhs.dueDate < rhs.dueDate }
                return priorityRank(lhs.priority) > priorityRank(rhs.priority)
            }
    }

    private func priorityRank(_ p: AssignmentPriority) -> Int {
        switch p { case .high: return 2; case .medium: return 1; case .low: return 0 }
    }

    var body: some View {
        List {
            Toggle("แสดงงานที่เสร็จแล้ว", isOn: $showDone)
            ForEach(sorted) { assignment in
                HStack {
                    Button {
                        assignment.isDone.toggle()
                    } label: {
                        Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(assignment.isDone ? Theme.Colors.success : .secondary)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(assignment.title).strikethrough(assignment.isDone)
                        HStack(spacing: 6) {
                            Text(assignment.dueDate.thaiShortString).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(assignment.priority.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(sorted[i]) }
            }
        }
        .navigationTitle("งาน & To-Do")
        .overlay { if assignments.isEmpty { ContentUnavailableView("ไม่มีงาน", systemImage: "checkmark.square") } }
    }
}

#Preview {
    NavigationStack { AssignmentListView() }
        .modelContainer(for: Assignment.self, inMemory: true)
}
