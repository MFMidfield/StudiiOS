//
//  QuickAddSheet.swift
//  Half-sheet menu shown by the tab bar's "+" button, plus the flow container
//  that swaps the menu out for a real form.
//
//  Every option opens the app's own form — there is no second, thinner copy of
//  a form living in here any more (the old CaptureDetailSheet dropped repeat,
//  tags and images on the floor, and "โน๊ต" saved into a model nothing reads).
//
//  Adding a new kind later = one more entry in `options` + one more case in
//  QuickAddTarget.
//

import SwiftUI

/// One screen inside the quick-add flow. Declared in RootTabView so the tab bar
/// can start the flow already pointing at a form.
extension QuickAddTarget {
    /// The forms are full-height; only the menu is a half-sheet.
    var detent: PresentationDetent { self == .menu ? .medium : .large }
}

/// Holds the whole quick-add flow in a single sheet. Swapping the *content*
/// (rather than re-presenting a new sheet) means "ยกเลิก" closes everything
/// once, with no menu left hanging behind the form.
struct QuickAddFlow: View {
    let start: QuickAddTarget

    @State private var target: QuickAddTarget

    init(start: QuickAddTarget) {
        self.start = start
        _target = State(initialValue: start)
    }

    var body: some View {
        content
            .safeAreaInset(edge: .bottom) { escapeHatch }
            .presentationDetents([target.detent])
            .presentationDragIndicator(.visible)
    }

    /// When "+" jumped straight to a form, this is the only way back to the full
    /// menu — a tab bar item can't take a long-press gesture.
    @ViewBuilder
    private var escapeHatch: some View {
        if start != .menu && target == start {
            Button {
                target = .menu
            } label: {
                Text("เพิ่มอย่างอื่น →")
                    .font(Theme.Font.plex(13, .medium))
                    .foregroundStyle(Theme.Colors.primaryDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(.bar)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch target {
        case .menu:
            QuickAddSheet(onSelect: { target = $0 })
        case .task:
            AddTaskSheet()
        case .event:
            EventFormSheet(initialDate: .now)
        case .scheduleEntry:
            AddScheduleEntrySheet(editing: nil, defaultDay: ScheduleConstants.defaultEntryDay)
        case .portfolio:
            PortfolioItemSheet(mode: .create)
        }
    }
}

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Called with the form to show. The flow container owns the switch — this
    /// view never presents anything itself.
    let onSelect: (QuickAddTarget) -> Void

    private let options: [QuickAddOption] = [
        QuickAddOption(icon: "checklist", title: "งาน",
                       color: Theme.Colors.primary, target: .task),
        QuickAddOption(icon: "calendar.badge.plus", title: "กิจกรรมปฏิทิน",
                       color: Theme.Colors.subjectPalette[3], target: .event),
        QuickAddOption(icon: "clock.badge.checkmark", title: "คาบเรียน",
                       color: Theme.Colors.subjectPalette[1], target: .scheduleEntry),
        QuickAddOption(icon: "folder.badge.plus", title: "ผลงาน",
                       color: Theme.Colors.subjectPalette[4], target: .portfolio),
    ]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.xl) {
                    ForEach(options) { option in
                        Button {
                            onSelect(option.target)
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
    }

    private func tile(for option: QuickAddOption) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            IconTile(systemName: option.icon, size: 64, color: option.color, cornerRadius: Theme.Radius.card)
            Text(option.title)
                .font(Theme.Font.plex(13, .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Options

private struct QuickAddOption: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
    let target: QuickAddTarget
}

#Preview {
    QuickAddFlow(start: .menu)
        .modelContainer(for: [Assignment.self, CalendarEvent.self, PortfolioItem.self, Subject.self, ScheduleEntry.self], inMemory: true)
}
