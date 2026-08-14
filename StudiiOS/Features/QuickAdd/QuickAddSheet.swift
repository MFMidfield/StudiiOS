//
//  QuickAddSheet.swift
//  Half-sheet menu shown by the tab bar's "+" button. Picks what to add, then
//  presents the app's real form on top of itself.
//
//  There is no second, thinner copy of a form living in here any more: the old
//  CaptureDetailSheet dropped repeat, tags and images on the floor, and "โน๊ต"
//  saved into a model nothing in the app reads.
//
//  Adding a new kind later = one more entry in `options` + one more case in
//  QuickAddForm.
//

import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var activeForm: QuickAddForm?
    /// Set by the form just before it closes. Read in `onDismiss` — by then the
    /// form is fully gone, so dismissing this menu is its own clean transition
    /// instead of two dismissals racing inside one update.
    @State private var didSave = false

    private let options: [QuickAddOption] = [
        QuickAddOption(icon: "checklist", title: "งาน",
                       color: Theme.Colors.primary, form: .task),
        QuickAddOption(icon: "calendar.badge.plus", title: "กิจกรรมปฏิทิน",
                       color: Theme.Colors.subjectPalette[3], form: .event),
        QuickAddOption(icon: "folder.badge.plus", title: "ผลงาน",
                       color: Theme.Colors.subjectPalette[4], form: .portfolio),
    ]

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                    ForEach(options) { option in
                        Button {
                            activeForm = option.form
                        } label: {
                            tile(for: option)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("เพิ่มอะไรดี?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(item: $activeForm, onDismiss: closeIfSaved) { form in
            formView(for: form)
        }
    }

    // MARK: - Forms

    /// บันทึก → ปิดทั้งฟอร์มและเมนู · ยกเลิก → ปิดแค่ฟอร์ม กลับมาที่เมนู
    @ViewBuilder
    private func formView(for form: QuickAddForm) -> some View {
        switch form {
        case .task:
            AddTaskSheet(onSaved: { didSave = true })
        case .event:
            EventFormSheet(initialDate: .now, onSaved: { didSave = true })
        case .portfolio:
            PortfolioItemSheet(mode: .create, onSaved: { didSave = true })
        }
    }

    private func closeIfSaved() {
        guard didSave else { return }
        didSave = false
        dismiss()
    }

    // MARK: - Tile

    private func tile(for option: QuickAddOption) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            IconTile(systemName: option.icon, size: 64, color: option.color, cornerRadius: Theme.Radius.card)
            Text(option.title)
                .font(Theme.Font.plex(13, .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Options

/// Which real form the menu opens. Identifiable so `.sheet(item:)` can drive it.
private enum QuickAddForm: String, Identifiable {
    case task, event, portfolio

    var id: String { rawValue }
}

private struct QuickAddOption: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
    let form: QuickAddForm
}

#Preview {
    QuickAddSheet()
        .modelContainer(for: [Assignment.self, CalendarEvent.self, PortfolioItem.self, Subject.self, ScheduleEntry.self], inMemory: true)
}
