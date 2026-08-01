//
//  SmartCaptureView.swift
//  Smart Capture: quick entry points for homework, calendar items, notes,
//  and portfolio records.
//

import SwiftUI
import SwiftData

struct SmartCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var mode: CaptureMode?

    fileprivate enum CaptureMode: String, Identifiable {
        case assignment, calendar, note, portfolio

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("เพิ่มข้อมูล") {
                    CaptureRow(icon: "checklist", title: "งาน / การบ้าน", subtitle: "วันส่งงาน และรายละเอียด", color: Theme.Colors.primary) {
                        mode = .assignment
                    }
                    CaptureRow(icon: "calendar.badge.plus", title: "กิจกรรมปฏิทิน", subtitle: "วัน เวลา สถานที่ แจ้งเตือน และโน้ต", color: Theme.Colors.warning) {
                        mode = .calendar
                    }
                    CaptureRow(icon: "note.text", title: "โน๊ต", subtitle: "ชื่อ และเนื้อหา", color: Theme.Colors.success) {
                        mode = .note
                    }
                    CaptureRow(icon: "folder.badge.plus", title: "Portfolio", subtitle: "ชื่อ และรายละเอียด", color: Theme.Colors.danger) {
                        mode = .portfolio
                    }
                }
            }
            .navigationTitle("เพิ่มอย่างรวดเร็ว")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
            .sheet(item: $mode) { mode in
                CaptureDetailSheet(mode: mode) { dismiss() }
            }
        }
    }
}

private struct CaptureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CaptureDetailSheet: View {
    let mode: SmartCaptureView.CaptureMode
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var noteBody = ""

    @State private var dueDate = Date.now

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
                case .assignment:
                    assignmentFields
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

    private var assignmentFields: some View {
        Group {
            Section("งาน / การบ้าน") {
                DatePicker("วันส่งงาน", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                TextField("รายละเอียด", text: $detail, axis: .vertical)
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
        case .assignment, .calendar:
            return !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .note, .portfolio:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func title(for mode: SmartCaptureView.CaptureMode) -> String {
        switch mode {
        case .assignment: return "งาน / การบ้าน"
        case .calendar: return "กิจกรรมปฏิทิน"
        case .note: return "โน๊ต"
        case .portfolio: return "Portfolio"
        }
    }

    private func save() {
        do {
            switch mode {
            case .assignment:
                context.insert(Assignment(title: detailTitle, detail: detail, dueDate: dueDate))
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
            case .note:
                context.insert(Note(title: title, content: noteBody))
            case .portfolio:
                context.insert(PortfolioItem(title: title, detail: detail, category: portfolioCategory, date: portfolioCreatedAt))
            }
            try context.save()
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
    SmartCaptureView()
        .modelContainer(for: [Assignment.self, Note.self, CalendarEvent.self, PortfolioItem.self], inMemory: true)
}
