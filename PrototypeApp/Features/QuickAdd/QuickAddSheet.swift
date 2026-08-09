//
//  QuickAddSheet.swift
//  Half-sheet menu shown by the tab bar's "+" button. Lets the user pick what
//  to add before any form appears. "งาน" opens AddTaskSheet; the rest open
//  CaptureDetailSheet below.
//
//  Adding a new kind later = one more entry in `options`.
//

import SwiftUI
import SwiftData

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var detailMode: CaptureMode?
    @State private var showAddTask = false

    private let options: [QuickAddOption] = [
        QuickAddOption(icon: "checklist", title: "งาน", color: Theme.Colors.primary, action: .task),
        QuickAddOption(icon: "calendar.badge.plus", title: "ปฏิทิน", color: Theme.Colors.warning, action: .capture(.calendar)),
        QuickAddOption(icon: "note.text", title: "โน๊ต", color: Theme.Colors.success, action: .capture(.note)),
        QuickAddOption(icon: "folder.badge.plus", title: "Portfolio", color: Theme.Colors.danger, action: .capture(.portfolio)),
    ]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                    ForEach(options) { option in
                        Button {
                            select(option)
                        } label: {
                            tile(for: option)
                        }
                        .buttonStyle(.plain)
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
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(onSaved: { dismiss() })
        }
        .sheet(item: $detailMode) { mode in
            CaptureDetailSheet(mode: mode) { dismiss() }
        }
    }

    private func tile(for option: QuickAddOption) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(option.color.opacity(0.12))
                    .frame(height: 72)
                Image(systemName: option.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(option.color)
            }
            Text(option.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
        }
    }

    private func select(_ option: QuickAddOption) {
        switch option.action {
        case .task: showAddTask = true
        case .capture(let mode): detailMode = mode
        }
    }
}

// MARK: - Options

private struct QuickAddOption: Identifiable {
    enum Action {
        case task
        case capture(CaptureMode)
    }

    let id = UUID()
    let icon: String
    let title: String
    let color: Color
    let action: Action
}

/// Kinds still handled by the generic capture form. งาน is not here — it has
/// its own dedicated form (`AddTaskSheet`).
private enum CaptureMode: String, Identifiable {
    case calendar, note, portfolio

    var id: String { rawValue }
}

// MARK: - Detail form (ปฏิทิน / โน๊ต / Portfolio)

private struct CaptureDetailSheet: View {
    let mode: CaptureMode
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var noteBody = ""

    @State private var startDate = Date.now
    @State private var endDate = Date.now.addingTimeInterval(3600)
    @State private var isAllDay = true
    @State private var repeatOption: RepeatOption = .none
    @State private var location = ""
    @State private var tags = ""
    @State private var alertOption: AlertOption = .none
    @State private var calendarNote = ""

    @State private var portfolioCreatedAt = Date.now
    @State private var portfolioCategory: PortfolioCategory = .activity
    @State private var saveError: String?

    private enum RepeatOption: String, CaseIterable, Identifiable {
        case none, daily, weekly, monthly

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return "ไม่ทำซ้ำ"
            case .daily: return "ทุกวัน"
            case .weekly: return "ทุกสัปดาห์"
            case .monthly: return "ทุกเดือน"
            }
        }
    }

    fileprivate enum AlertOption: String, CaseIterable, Identifiable {
        case none, atTime, fiveMinutes, oneHour, oneDay

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return "ไม่แจ้งเตือน"
            case .atTime: return "ตอนเริ่มกิจกรรม"
            case .fiveMinutes: return "ก่อน 5 นาที"
            case .oneHour: return "ก่อน 1 ชั่วโมง"
            case .oneDay: return "ก่อน 1 วัน"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch mode {
                case .calendar:
                    calendarFields
                case .note:
                    noteFields
                case .portfolio:
                    portfolioFields
                }
            }
            .navigationTitle(title(for: mode))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") { save() }
                        .disabled(!canSave)
                }
            }
            .alert("บันทึกข้อมูลไม่สำเร็จ", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("ตกลง", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var calendarFields: some View {
        Group {
            Section("กิจกรรมปฏิทิน") {
                DatePicker("วันที่เริ่ม", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                DatePicker("วันที่จบ", selection: $endDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                Toggle("All day", isOn: $isAllDay)
            }
            Section("รายละเอียด") {
                Picker("Repeat", selection: $repeatOption) {
                    ForEach(RepeatOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                TextField("Location", text: $location)
                TextField("Tags", text: $tags)
                Picker("Alert", selection: $alertOption) {
                    ForEach(AlertOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                TextField("Note", text: $calendarNote, axis: .vertical)
                TextField("Detail", text: $detail, axis: .vertical)
            }
        }
    }

    private var noteFields: some View {
        Group {
            Section("โน๊ต") {
                TextField("ชื่อ", text: $title)
                TextEditor(text: $noteBody).frame(minHeight: 150)
            }
        }
    }

    private var portfolioFields: some View {
        Group {
            Section("Portfolio") {
                DatePicker("วันที่สร้าง", selection: $portfolioCreatedAt, displayedComponents: .date)
                    .disabled(true)
                TextField("ชื่อ", text: $title)
                Picker("หมวดหมู่", selection: $portfolioCategory) {
                    ForEach(PortfolioCategory.allCases, id: \.self) { category in
                        Text(category.label).tag(category)
                    }
                }
                TextField("รายละเอียด", text: $detail, axis: .vertical)
            }
        }
    }

    private var canSave: Bool {
        switch mode {
        case .calendar:
            return !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .note, .portfolio:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func title(for mode: CaptureMode) -> String {
        switch mode {
        case .calendar: return "กิจกรรมปฏิทิน"
        case .note: return "โน๊ต"
        case .portfolio: return "Portfolio"
        }
    }

    private func save() {
        var scheduledEvent: CalendarEvent?
        do {
            switch mode {
            case .calendar:
                let event = CalendarEvent(
                    title: detailTitle,
                    startDate: startDate,
                    endDate: endDate,
                    isAllDay: isAllDay,
                    location: location,
                    alert: alertOption.toEventAlert(),
                    customAlertMinutes: 10,
                    notes: [calendarNote, detail].filter { !$0.isEmpty }.joined(separator: "\n"),
                    urlString: "",
                    colorHex: "4A7DFF"
                )
                context.insert(event)
                scheduledEvent = event
            case .note:
                context.insert(Note(title: title, content: noteBody))
            case .portfolio:
                context.insert(PortfolioItem(title: title, detail: detail, category: portfolioCategory, startDate: portfolioCreatedAt))
            }
            try context.save()
            if let scheduledEvent {
                Task { await NotificationManager.shared.schedule(for: scheduledEvent) }
            }
            dismiss()
            onSaved()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var detailTitle: String {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDetail.isEmpty ? title(for: mode) : trimmedDetail
    }
}

// ──────────────────────────────────────────
// MARK: - AlertOption to EventAlert Converter
// ──────────────────────────────────────────

extension CaptureDetailSheet.AlertOption {
    fileprivate func toEventAlert() -> EventAlert {
        switch self {
        case .none:
            return .none
        case .atTime:
            return .atTime
        case .fiveMinutes:
            return .fiveMin
        case .oneHour:
            return .oneHour
        case .oneDay:
            return .oneDay
        }
    }
}

#Preview {
    QuickAddSheet()
        .modelContainer(for: [Assignment.self, Note.self, CalendarEvent.self, PortfolioItem.self, Subject.self], inMemory: true)
}
