//
//  TaskFilterChips.swift
//  Horizontal chip bar + "กรอง" button at the top of the Todo screen.
//

import SwiftUI

struct TaskFilterChips: View {
    @Binding var selection: TaskScope
    /// Shows a dot on the "กรอง" button when any filter is not at its default.
    let hasActiveFilters: Bool
    let onOpenFilters: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(TaskScope.chips) { scope in
                    chip(for: scope)
                }
                filterButton
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
            Text(scope.label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.Colors.onPrimary : Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Theme.Colors.separator, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var filterButton: some View {
        Button(action: onOpenFilters) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .semibold))
                Text("กรอง")
                    .font(.system(size: 13))
                if hasActiveFilters {
                    Circle()
                        .fill(Theme.Colors.primary)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TaskFilterChips(selection: .constant(.all), hasActiveFilters: true, onOpenFilters: {})
        .background(Theme.Colors.background)
}
