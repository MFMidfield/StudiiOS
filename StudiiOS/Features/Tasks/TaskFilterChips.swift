//
//  TaskFilterChips.swift
//  Horizontal chip bar at the top of the Todo screen. Each chip carries its own
//  count — the stats cards that used to sit below are gone.
//

import SwiftUI

struct TaskFilterChips: View {
    @Binding var selection: TaskScope
    let counts: [TaskScope: Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(TaskScope.chips) { scope in
                    chip(for: scope)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private func chip(for scope: TaskScope) -> some View {
        let isSelected = selection == scope
        return Button {
            selection = scope
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(scope.label)
                    .font(Theme.Font.plex(13, isSelected ? .semibold : .regular))
                if scope.showsCount {
                    Text("\(counts[scope] ?? 0)")
                        .font(Theme.Font.plex(13, .semibold))
                        .contentTransition(.numericText())
                        .foregroundStyle(countColor(for: scope, isSelected: isSelected))
                }
            }
            .foregroundStyle(isSelected ? Theme.Colors.onPrimary : Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Theme.Colors.separator, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    /// Overdue is the one count that should catch the eye while unselected —
    /// once the chip itself is filled, the number rides the chip's own color.
    private func countColor(for scope: TaskScope, isSelected: Bool) -> Color {
        if isSelected { return Theme.Colors.onPrimary }
        return scope == .overdue ? Theme.Colors.danger : Theme.Colors.textPrimary
    }
}

#Preview {
    TaskFilterChips(
        selection: .constant(.notDone),
        counts: [.notDone: 4, .overdue: 1, .done: 8]
    )
    .background(Theme.Colors.background)
}
