//
//  DashboardPendingCard.swift
//  "งานค้าง" — split out of DashboardView.swift. Rows can now be checked
//  off directly from the Dashboard (writes Assignment.isDone the same way
//  AssignmentListView.toggleDone does) instead of only opening the full list.
//

import SwiftUI
import SwiftData

struct DashboardPendingCard: View {
    let pending: [Assignment]

    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Environment(\.modelContext) private var context
    @State private var showAddTask = false

    private var visible: [Assignment] { Array(pending.prefix(4)) }

    var body: some View {
        CardContainer {
            SectionHeader("งานค้าง") {
                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.Colors.primaryDeep)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("เพิ่มงาน")

                    NavigationLink(value: DashboardDestination.assignments) {
                        SectionMoreLabel()
                    }
                    .buttonStyle(.plain)
                }
            }

            if pending.isEmpty {
                EmptyRow(text: "ไม่มีงานค้าง 🎉")
            } else {
                ForEach(visible) { assignment in
                    DashboardAssignmentRow(
                        assignment: assignment,
                        subjectColor: color(for: assignment),
                        onToggleDone: { toggleDone(assignment) }
                    )
                    if assignment.id != visible.last?.id {
                        Divider()
                            .background(Theme.Colors.separator)
                    }
                }
                if pending.count > visible.count {
                    Text("และอีก \(pending.count - visible.count) งาน")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet()
        }
    }

    /// `Assignment` stores the subject as free text, so the stripe color has to
    /// be looked up by name — an unmatched name falls back to the accent.
    private func color(for assignment: Assignment) -> Color {
        subjects.first { $0.name == assignment.subjectName }?.color ?? Theme.Colors.primary
    }

    private func toggleDone(_ assignment: Assignment) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            assignment.isDone.toggle()
        }
        try? context.save()
        Task { await NotificationManager.shared.schedule(for: assignment) }
        AppLog.action("Assignment", "\(assignment.isDone ? "ทำเสร็จ" : "ยกเลิกเสร็จ"): \(assignment.title)")
    }
}

private struct DashboardAssignmentRow: View {
    let assignment: Assignment
    let subjectColor: Color
    let onToggleDone: () -> Void

    /// "<วิชา> · <เวลา>" — with either half dropped when it's missing, so a
    /// task with no subject never shows a dangling separator.
    private var subtitle: String {
        var parts: [String] = []
        if !assignment.subjectName.isEmpty { parts.append(assignment.subjectName) }
        if assignment.kind != .exam, let due = assignment.resolvedDueDate {
            parts.append(DateFormatter.time24h.string(from: due))
        }
        return parts.joined(separator: " · ")
    }

    private var dueTone: PillLabel.Tone {
        guard let due = assignment.resolvedDueDate else { return .neutral }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<0: return .danger
        case 0: return .accent
        case 1: return .warning
        default: return .neutral
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onToggleDone) {
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(assignment.isDone ? Theme.Colors.success : Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.isDone ? "ทำเครื่องหมายว่ายังไม่เสร็จ" : "ทำเครื่องหมายว่าเสร็จแล้ว")

            Capsule()
                .fill(subjectColor)
                .frame(width: 3, height: subtitle.isEmpty ? 18 : 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .strikethrough(assignment.isDone)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            if let due = assignment.resolvedDueDate {
                PillLabel(due.thaiDueLabel, tone: dueTone)
            } else {
                PillLabel("ไม่กำหนดส่ง")
            }
        }
        .opacity(assignment.isDone ? 0.55 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: assignment.isDone)
        .padding(.vertical, 2)
    }
}

struct EmptyRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.Font.label)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        DashboardPendingCard(pending: [])
            .padding()
            .background(Theme.Colors.background)
    }
    .modelContainer(for: [Assignment.self, Subject.self], inMemory: true)
}
