//
//  TaskRowCard.swift
//  One task card, used by both the "ใกล้ถึงกำหนด" section and the full list.
//

import SwiftUI

struct TaskRowCard: View {
    let assignment: Assignment
    /// Looked up by name in AssignmentListView — `nil` for personal tasks or
    /// when the subject was deleted.
    let subject: Subject?
    let onToggleDone: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            doneButton
            icon
            content
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(assignment.isOverdue ? Theme.Colors.danger.opacity(0.4) : .clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .opacity(assignment.isDone ? 0.6 : 1)
    }

    // MARK: - Parts

    private var doneButton: some View {
        Button(action: onToggleDone) {
            Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(assignment.isDone ? Theme.Colors.success : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(assignment.isDone ? "ทำเครื่องหมายว่ายังไม่เสร็จ" : "ทำเครื่องหมายว่าเสร็จแล้ว")
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(iconColor.opacity(0.12))
                .frame(width: 36, height: 36)
            Image(systemName: subject?.iconName ?? assignment.kind.iconName)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Text(assignment.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .strikethrough(assignment.isDone)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Spacing.xs)
                dueBadge
            }

            if !assignment.subjectName.isEmpty {
                Text(assignment.subjectName)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if let due = assignment.resolvedDueDate {
                Label(
                    "\(due.thaiDayMonthYearString) \(DateFormatter.time24h.string(from: due))",
                    systemImage: "calendar"
                )
                .font(.caption2)
                .foregroundStyle(assignment.isOverdue ? Theme.Colors.danger : Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var dueBadge: some View {
        Text(dueLabel)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(badgeBackground)
            .clipShape(Capsule())
            .fixedSize()
    }

    // MARK: - Derived styling

    private var iconColor: Color {
        subject?.color ?? Theme.Colors.primary
    }

    private var dueLabel: String {
        AssignmentPriorityEngine.dueLabel(for: assignment.resolvedDueDate)
    }

    private var badgeForeground: Color {
        guard let due = assignment.resolvedDueDate else { return Theme.Colors.textSecondary }
        switch AssignmentPriorityEngine.daysUntil(due) {
        case ..<0: return Theme.Colors.danger
        case 0: return Theme.Colors.warning
        case 1: return Theme.Colors.purple
        default: return Theme.Colors.success
        }
    }

    private var badgeBackground: Color {
        assignment.resolvedDueDate == nil
            ? Theme.Colors.separator
            : badgeForeground.opacity(0.15)
    }
}

#Preview {
    let subject = Subject(name: "เคมี", colorHex: "9C27B0", iconName: "flask.fill")
    return VStack(spacing: Theme.Spacing.md) {
        TaskRowCard(
            assignment: Assignment(title: "แบบฝึกหัด 2.1 ข้อ 1-20", dueDate: .now, subjectName: "เคมี"),
            subject: subject,
            onToggleDone: {},
            onTap: {}
        )
        TaskRowCard(
            assignment: Assignment(
                title: "ซื้อสมุดเล่มใหม่",
                kind: .personal,
                hasDueDate: false
            ),
            subject: nil,
            onToggleDone: {},
            onTap: {}
        )
    }
    .padding()
    .background(Theme.Colors.background)
}
