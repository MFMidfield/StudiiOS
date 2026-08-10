//
//  DashboardPendingCard.swift
//  "งานค้าง" — split out of DashboardView.swift. Rows can now be checked
//  off directly from the Dashboard (writes Assignment.isDone the same way
//  AssignmentListView.toggleDone does) instead of only opening the full list.
//

import SwiftUI
import SwiftData

struct DashboardPendingCard: View {
    let dueToday: [Assignment]
    let pending: [Assignment]

    @Environment(\.modelContext) private var context
    @State private var showAddTask = false

    var body: some View {
        CardContainer {
            HStack {
                Text("งานค้าง")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(pending.count) รายการ")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("เพิ่มงาน")
            }
            if pending.isEmpty {
                EmptyRow(text: "ไม่มีงานค้าง 🎉")
            } else {
                ForEach(pending.prefix(4)) { assignment in
                    DashboardAssignmentRow(
                        assignment: assignment,
                        isDueToday: dueToday.contains(assignment),
                        onToggleDone: { toggleDone(assignment) }
                    )
                    if assignment.id != pending.prefix(4).last?.id {
                        Divider()
                            .background(Theme.Colors.separator)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet()
        }
    }

    private func toggleDone(_ assignment: Assignment) {
        withAnimation(.snappy) {
            assignment.isDone.toggle()
        }
        try? context.save()
        Task { await NotificationManager.shared.schedule(for: assignment) }
        AppLog.action("Assignment", "\(assignment.isDone ? "ทำเสร็จ" : "ยกเลิกเสร็จ"): \(assignment.title)")
    }
}

private struct DashboardAssignmentRow: View {
    let assignment: Assignment
    var isDueToday: Bool = false
    let onToggleDone: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleDone) {
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(assignment.isDone ? Theme.Colors.success : (isDueToday ? Theme.Colors.danger : Theme.Colors.primary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.isDone ? "ทำเครื่องหมายว่ายังไม่เสร็จ" : "ทำเครื่องหมายว่าเสร็จแล้ว")

            Text(assignment.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .strikethrough(assignment.isDone)
                .lineLimit(1)
            Spacer()
            Text(assignment.resolvedDueDate?.thaiShortString ?? "ไม่กำหนดส่ง")
                .font(.caption2)
                .foregroundStyle(isDueToday ? Theme.Colors.danger : Theme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct EmptyRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }
}

#Preview {
    DashboardPendingCard(dueToday: [], pending: [])
        .padding()
        .modelContainer(for: [Assignment.self], inMemory: true)
}
