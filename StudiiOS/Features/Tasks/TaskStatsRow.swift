//
//  TaskStatsRow.swift
//  Four tappable stat cards under the chip bar. Counts come from the same
//  TaskScope rules the chips use.
//

import SwiftUI

struct TaskStatsRow: View {
    /// Counts keyed by scope, computed once in AssignmentListView.
    let counts: [TaskScope: Int]
    let onSelect: (TaskScope) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(TaskScope.stats) { scope in
                Button {
                    onSelect(scope)
                } label: {
                    card(for: scope)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func card(for scope: TaskScope) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("\(counts[scope] ?? 0)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color(for: scope))
            Text(scope.label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func color(for scope: TaskScope) -> Color {
        switch scope {
        case .all: return Theme.Colors.textPrimary
        case .dueSoon: return Theme.Colors.warning
        case .overdue: return Theme.Colors.danger
        case .done: return Theme.Colors.success
        case .notDone: return Theme.Colors.primary
        }
    }
}

#Preview {
    TaskStatsRow(
        counts: [.all: 12, .dueSoon: 3, .overdue: 1, .done: 8],
        onSelect: { _ in }
    )
    .padding(.vertical)
    .background(Theme.Colors.background)
}
