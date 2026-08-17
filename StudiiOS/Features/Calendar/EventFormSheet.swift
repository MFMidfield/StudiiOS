//
//  EventFormSheet.swift
//  Add & edit form for CalendarEvent — split out of CalendarView.swift
//  (10 ส.ค. 2569, ก่อน Round 4 Ghost Event) to keep that file small enough
//  for the type-checker.
//

import SwiftUI
import SwiftData

struct EventFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existingEvent: CalendarEvent?
    /// `true` only for an event the ghost-drag flow just speculatively
    /// created — "ยกเลิก" then deletes it instead of leaving an empty stub.
    private let deleteOnCancel: Bool

    @Query(sort: \CalendarTag.name) private var allTags: [CalendarTag]

    @State private var title: String
    @State private var location: String
    @State private var notes: String
    @State private var subjectName: String
    @State private var isAllDay: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedColorHex: String
    @State private var alert: EventAlert
    @State private var customAlertMinutes: Int
    @State private var selectedTagNames: Set<String>
    @State private var newTagName = ""
    @State private var showDeleteConfirm = false
    @FocusState private var titleFocused: Bool

    private var notifications = NotificationManager.shared

    private let cal = Calendar(identifier: .gregorian)
    private var eventColors: [(hex: String, color: Color)] {
        Array(zip(Theme.Colors.subjectPaletteHex, Theme.Colors.subjectPalette))
    }

    /// Called after a successful save — lets a presenting sheet (QuickAddSheet)
    /// close itself too instead of staying behind the form. `nil` everywhere
    /// else, so existing call sites are untouched.
    private let onSaved: (() -> Void)?

    /// กดปุ่ม "เพิ่มเป็นการบ้าน/งานแทน" — ฟอร์มนี้ปิดตัวเอง แล้วให้ผู้เรียกเปิด
    /// `AddTaskSheet` ต่อ (สั่งเปิด sheet ใหม่ตอนตัวเก่ายังปิดไม่เสร็จ ฟอร์มจะไม่ขึ้น
    /// จึงต้องส่งกลับไปให้ฝั่งที่ present เป็นคนเปิด)
    private let onSwitchToTask: (() -> Void)?

    // ── Add initializer ──
    init(initialDate: Date, onSaved: (() -> Void)? = nil, onSwitchToTask: (() -> Void)? = nil) {
        existingEvent = nil
        deleteOnCancel = false
        self.onSaved = onSaved
        self.onSwitchToTask = onSwitchToTask
        let dayStart = Calendar(identifier: .gregorian).startOfDay(for: initialDate)
        _title            = State(initialValue: "")
        _location         = State(initialValue: "")
        _notes            = State(initialValue: "")
        _subjectName      = State(initialValue: "")
        _isAllDay         = State(initialValue: true)
        _startDate        = State(initialValue: dayStart)
        _endDate          = State(initialValue: Calendar(identifier: .gregorian).date(byAdding: .hour, value: 1, to: dayStart)!)
        _selectedColorHex = State(initialValue: "E1802F")
        _alert            = State(initialValue: .none)
        _customAlertMinutes = State(initialValue: 10)
        _selectedTagNames = State(initialValue: [])
    }

    // ── Edit initializer ──
    init(event: CalendarEvent, deleteOnCancel: Bool = false, onSaved: (() -> Void)? = nil) {
        existingEvent     = event
        self.deleteOnCancel = deleteOnCancel
        self.onSaved      = onSaved
        // แก้กิจกรรมที่มีอยู่แล้วไม่มีปุ่มสลับไปฟอร์มงาน — ของที่สร้างไว้แล้วย้ายประเภทไม่ได้
        self.onSwitchToTask = nil
        _title            = State(initialValue: event.title)
        _location         = State(initialValue: event.location)
        _notes            = State(initialValue: event.notes)
        _subjectName      = State(initialValue: event.subjectName)
        _isAllDay         = State(initialValue: event.isAllDay)
        _startDate        = State(initialValue: event.startDate)
        // กิจกรรมทั้งวันเก็บ `endDate` แบบ**ไม่รวมปลาย** (กิจกรรมวันที่ 4 เก็บ
        // เที่ยงคืนของวันที่ 5) แต่ `save()` บวก +1 วันให้อีกรอบเสมอ —
        // เอาค่าดิบมาโชว์ = กิจกรรมยาวขึ้นวันหนึ่งทุกครั้งที่กดบันทึก
        _endDate          = State(initialValue: Self.displayEndDate(of: event))
        _selectedColorHex = State(initialValue: event.colorHex)
        _alert            = State(initialValue: event.alert)
        _customAlertMinutes = State(initialValue: event.customAlertMinutes)
        _selectedTagNames = State(initialValue: Set(event.tags.map { $0.name }))
    }

    /// วันสิ้นสุดแบบที่ผู้ใช้เข้าใจ (รวมปลาย) — คู่กับการบวก +1 วันใน `save()`
    private static func displayEndDate(of event: CalendarEvent) -> Date {
        guard event.isAllDay else { return event.endDate }
        let cal = Calendar(identifier: .gregorian)
        let inclusive = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: event.endDate))
            ?? event.startDate
        return max(inclusive, cal.startOfDay(for: event.startDate))
    }

    private var isEditing: Bool { existingEvent != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    // ── Body ──────────────────────────────────────────────

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                if onSwitchToTask != nil { switchToTaskSection }
                dateSection
                notesSection
                tagSection
                alertSection
                colorSection
                if isEditing { deleteSection }
            }
            .themedFormBackground()
            .navigationTitle(isEditing ? "แก้ไขกิจกรรม" : "กิจกรรมใหม่")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "ลบ \"\(existingEvent?.title ?? "กิจกรรม")\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("ลบกิจกรรม", role: .destructive, action: delete)
                Button("ยกเลิก", role: .cancel) { }
            } message: {
                Text("การลบจะไม่สามารถกู้คืนได้")
            }
        }
        // เต็มจอเสมอ — ฟอร์มมี 7 section เปิดครึ่งจอแล้วต้องลากขึ้นเองทุกครั้ง
        .presentationDetents([.large])
        .onAppear { titleFocused = true }
    }

    // ── Sections ──────────────────────────────────────────

    private var titleSection: some View {
        Section {
            TextField("ชื่อกิจกรรม", text: $title)
                .submitLabel(.done)
                .focused($titleFocused)
            TextField("สถานที่ (ไม่บังคับ)", text: $location)
        }
    }

    /// ช่อง "วิชา" ถูกเอาออก 16 ส.ค. 2569 — `CalendarEvent.subjectName` ยังอยู่ในโมเดล
    /// (กิจกรรมเก่าที่เคยผูกวิชาไว้ยังโชว์ชื่อวิชาใน pill ได้) แค่ไม่มีที่ให้ตั้งใหม่
    private var switchToTaskSection: some View {
        Section {
            Button {
                onSwitchToTask?()
                dismiss()
            } label: {
                Label("นี่คือการบ้าน/งาน — เปิดฟอร์มงานแทน", systemImage: "checklist")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
        }
    }

    private var notesSection: some View {
        Section("โน้ต") {
            TextEditor(text: $notes)
                .frame(height: 80)
        }
    }

    private var tagSection: some View {
        Section("แท็ก") {
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(allTags) { tag in
                            tagChip(tag)
                        }
                    }
                }
            }
            HStack {
                TextField("แท็กใหม่", text: $newTagName)
                    .onSubmit(addNewTag)
                Button("เพิ่ม", action: addNewTag)
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func tagChip(_ tag: CalendarTag) -> some View {
        let isSelected = selectedTagNames.contains(tag.name)
        return Text(tag.name)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(isSelected ? Theme.Colors.onPrimary : Theme.Colors.textSecondary)
            .background(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.surfaceRaised)
            .clipShape(Capsule())
            .onTapGesture {
                if isSelected {
                    selectedTagNames.remove(tag.name)
                } else {
                    selectedTagNames.insert(tag.name)
                }
            }
    }

    private func addNewTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if !allTags.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            modelContext.insert(CalendarTag(name: trimmed))
        }
        selectedTagNames.insert(trimmed)
        newTagName = ""
    }

    private var dateSection: some View {
        Section {
            Toggle("ทั้งวัน", isOn: $isAllDay.animation(.easeInOut(duration: 0.2)))
                .onChange(of: isAllDay) { _, allDay in
                    if allDay {
                        startDate = cal.startOfDay(for: startDate)
                        endDate   = cal.startOfDay(for: endDate)
                    } else {
                        let now = Date()
                        let h = cal.component(.hour, from: now)
                        let m = cal.component(.minute, from: now)
                        startDate = cal.date(bySettingHour: h, minute: m, second: 0, of: startDate) ?? startDate
                        endDate   = cal.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
                    }
                }

            DatePicker(
                "เริ่มต้น",
                selection: $startDate,
                displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
            )
            .onChange(of: startDate) { _, new in
                if endDate <= new {
                    endDate = cal.date(byAdding: .hour, value: 1, to: new) ?? new
                }
            }

            DatePicker(
                "สิ้นสุด",
                selection: $endDate,
                in: startDate...,
                displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
            )
        }
    }

    private var alertSection: some View {
        Section("แจ้งเตือน") {
            Picker("เตือนล่วงหน้า", selection: $alert) {
                ForEach(EventAlert.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            if alert == .custom {
                Stepper("ก่อน \(customAlertMinutes) นาที", value: $customAlertMinutes, in: 1...1440, step: 5)
            }
            if alert != .none && notifications.authorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("แจ้งเตือนถูกปิดอยู่ — เปิดตั้งค่าเครื่อง", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.warning)
                }
            }
        }
    }

    private var colorSection: some View {
        Section("สี") {
            HStack(spacing: 14) {
                ForEach(eventColors, id: \.hex) { item in
                    ZStack {
                        Circle().fill(item.color).frame(width: 28, height: 28)
                        if selectedColorHex == item.hex {
                            Circle()
                                .strokeBorder(item.color, lineWidth: 2)
                                .frame(width: 36, height: 36)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selectedColorHex = item.hex }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Text("ลบกิจกรรม")
                    Spacer()
                }
            }
        }
    }

    // ── Actions ───────────────────────────────────────────

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let start = isAllDay ? cal.startOfDay(for: startDate) : startDate
        let end: Date = isAllDay
            ? (cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate)
            : (endDate > start ? endDate : (cal.date(byAdding: .hour, value: 1, to: start) ?? start))

        let savedEvent: CalendarEvent
        if let event = existingEvent {
            event.title              = trimmed
            event.startDate          = start
            event.endDate            = end
            event.isAllDay           = isAllDay
            event.location           = location.trimmingCharacters(in: .whitespaces)
            event.notes              = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            event.subjectName        = subjectName
            event.colorHex           = selectedColorHex
            event.alert              = alert
            event.customAlertMinutes = customAlertMinutes
            event.updatedAt          = .now
            savedEvent = event
        } else {
            let newEvent = CalendarEvent(
                title: trimmed, startDate: start, endDate: end,
                isAllDay: isAllDay,
                location: location.trimmingCharacters(in: .whitespaces),
                alert: alert, customAlertMinutes: customAlertMinutes,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: selectedColorHex,
                subjectName: subjectName
            )
            modelContext.insert(newEvent)
            savedEvent = newEvent
        }
        savedEvent.tags = allTags.filter { selectedTagNames.contains($0.name) }
        try? modelContext.save()
        Task { await notifications.schedule(for: savedEvent) }
        dismiss()
        onSaved?()
    }

    private func delete() {
        if let event = existingEvent {
            notifications.cancel(for: event)
            modelContext.delete(event)
        }
        dismiss()
    }

    private func cancel() {
        if deleteOnCancel, let event = existingEvent {
            notifications.cancel(for: event)
            modelContext.delete(event)
        }
        dismiss()
    }
}

#Preview {
    EventFormSheet(initialDate: .now)
        .modelContainer(
            for: [CalendarEvent.self, CalendarTag.self, CalendarAttachmentItem.self, Subject.self, Term.self],
            inMemory: true
        )
}
