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
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var activeForm: QuickAddForm?
    /// Set by the form just before it closes. Read in `onDismiss` — by then the
    /// form is fully gone, so dismissing this menu is its own clean transition
    /// instead of two dismissals racing inside one update.
    @State private var didSave = false
    /// ฟอร์มที่ต้องเปิดต่อหลังตัวปัจจุบันปิดสนิท — ใช้ตอนผู้ใช้กด
    /// "นี่คือการบ้าน/งาน" ในฟอร์มกิจกรรม (สั่งเปิดทันทีฟอร์มใหม่จะไม่ขึ้น)
    @State private var pendingForm: QuickAddForm?

    private let options: [QuickAddOption] = [
        QuickAddOption(icon: "checklist", title: "งาน",
                       color: Theme.Colors.primary, form: .task),
        QuickAddOption(icon: "calendar.badge.plus", title: "กิจกรรมปฏิทิน",
                       color: Theme.Colors.subjectPalette[3], form: .event),
        QuickAddOption(icon: "folder.badge.plus", title: "ผลงาน",
                       color: Theme.Colors.subjectPalette[4], form: .portfolio),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                // 3 แถวเรียงลง แถวละตัวเลือก (16 ส.ค. 2569 — เดิมเป็น 3 ช่องเรียงนอน
                // ซึ่งบีบชื่อจนต้องย่อฟอนต์)
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(options) { option in
                        Button {
                            activeForm = option.form
                        } label: {
                            row(for: option)
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
            EventFormSheet(
                initialDate: .now,
                onSaved: { didSave = true },
                onSwitchToTask: { pendingForm = .task }
            )
        case .portfolio:
            PortfolioItemSheet(mode: .create, onSaved: { didSave = true })
        }
    }

    /// ปิดฟอร์มแล้ว 3 ทาง: มีฟอร์มค้างรอเปิด → เปิดต่อ · เพิ่งบันทึก → ปิดเมนูตาม
    /// · ยกเลิกเฉยๆ → อยู่ที่เมนูต่อ
    private func closeIfSaved() {
        if let next = pendingForm {
            pendingForm = nil
            didSave = false
            activeForm = next
            return
        }
        guard didSave else { return }
        didSave = false
        dismiss()
    }

    // MARK: - Tile

    private func row(for option: QuickAddOption) -> some View {
        CardContainer(padding: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                IconTile(systemName: option.icon, size: 44, color: option.color, cornerRadius: Theme.Radius.control)
                Text(option.title)
                    .font(Theme.Font.plex(15, .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
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
