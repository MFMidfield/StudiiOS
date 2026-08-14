//
//  TaskRowCard.swift
//  One task row: toggle · subject stripe · title + subtitle · due pill.
//  The date lives in the pill and in the day-group header — never spelled out
//  a third time inside the card.
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
        HStack(spacing: 0) {
            stripe
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                doneButton
                content
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
        .opacity(assignment.isDone ? 0.55 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: assignment.isDone)
    }

    // MARK: - Parts

    /// 3pt of the subject's color down the left edge — replaces the old 36×36
    /// icon tile, so a column of rows reads as one list instead of a grid.
    private var stripe: some View {
        Rectangle()
            .fill(stripeColor)
            .frame(width: 3)
    }

    private var doneButton: some View {
        Button(action: onToggleDone) {
            Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(assignment.isDone ? Theme.Colors.success : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(assignment.isDone ? "ทำเครื่องหมายว่ายังไม่เสร็จ" : "ทำเครื่องหมายว่าเสร็จแล้ว")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Text(assignment.title)
                    .font(Theme.Font.plex(15, .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .strikethrough(assignment.isDone)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Spacing.xs)
                if let due = assignment.resolvedDueDate {
                    PillLabel(due.thaiDueLabel, tone: pillTone)
                        .fixedSize()
                }
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Derived

    private var stripeColor: Color {
        subject?.color ?? Theme.Colors.primary
    }

    /// "<วิชา> · <เวลา>" — either half is dropped when missing so no separator
    /// is ever left dangling.
    private var subtitle: String {
        var parts: [String] = []
        if !assignment.subjectName.isEmpty { parts.append(assignment.subjectName) }
        if let due = assignment.resolvedDueDate {
            parts.append(DateFormatter.time24h.string(from: due))
        }
        return parts.joined(separator: " · ")
    }

    private var pillTone: PillLabel.Tone {
        guard let due = assignment.resolvedDueDate, !assignment.isDone else { return .neutral }
        switch AssignmentPriorityEngine.daysUntil(due) {
        case ..<0: return .danger
        case 0: return .accent
        default: return .neutral
        }
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
