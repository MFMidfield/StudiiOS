//
//  CalendarView.swift
//  ปฏิทิน — monthly calendar grid + daily event list.
//

import SwiftUI
import SwiftData

// ══════════════════════════════════════════════════════════════
// MARK: - Models
// ══════════════════════════════════════════════════════════════

enum EventAlert: String, Codable, CaseIterable, Identifiable {
    case none, atTime, fiveMin, fifteenMin, thirtyMin, oneHour, oneDay, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:       "ไม่แจ้งเตือน"
        case .atTime:     "ตอนเริ่มกิจกรรม"
        case .fiveMin:    "5 นาทีก่อน"
        case .fifteenMin: "15 นาทีก่อน"
        case .thirtyMin:  "30 นาทีก่อน"
        case .oneHour:    "1 ชั่วโมงก่อน"
        case .oneDay:     "1 วันก่อน"
        case .custom:     "กำหนดเอง"
        }
    }
}

@Model
final class CalendarTag {
    var name: String
    var colorHex: String
    var events: [CalendarEvent] = []

    init(name: String, colorHex: String = "4A7DFF") {
        self.name = name
        self.colorHex = colorHex
    }
}

@Model
final class CalendarAttachmentItem {
    var filename: String
    var urlString: String
    var fileType: String
    var event: CalendarEvent?

    init(filename: String, urlString: String, fileType: String) {
        self.filename = filename
        self.urlString = urlString
        self.fileType = fileType
    }
}

@Model
final class CalendarEvent {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String
    var alertRaw: String
    var customAlertMinutes: Int
    var notes: String
    var urlString: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CalendarAttachmentItem.event)
    var attachments: [CalendarAttachmentItem] = []

    @Relationship(inverse: \CalendarTag.events)
    var tags: [CalendarTag] = []

    var alert: EventAlert {
        get { EventAlert(rawValue: alertRaw) ?? .none }
        set { alertRaw = newValue.rawValue }
    }

    var color: Color { Color(hex: colorHex) }

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = true,
        location: String = "",
        alert: EventAlert = .none,
        customAlertMinutes: Int = 10,
        notes: String = "",
        urlString: String = "",
        colorHex: String = "4A7DFF"
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.alertRaw = alert.rawValue
        self.customAlertMinutes = customAlertMinutes
        self.notes = notes
        self.urlString = urlString
        self.colorHex = colorHex
        self.createdAt = .now
        self.updatedAt = .now
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Sheet routing
// ══════════════════════════════════════════════════════════════

private enum CalendarSheet: Identifiable {
    case add(Date)
    case edit(CalendarEvent)

    var id: String {
        switch self {
        case .add(let d):  return "add_\(d.timeIntervalSince1970)"
        case .edit(let e): return "edit_\(e.id)"
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - CalendarView
// ══════════════════════════════════════════════════════════════

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var activeSheet: CalendarSheet?

    private let cal = Calendar(identifier: .gregorian)
    private let thaiMonths = [
        "มกราคม","กุมภาพันธ์","มีนาคม","เมษายน",
        "พฤษภาคม","มิถุนายน","กรกฎาคม","สิงหาคม",
        "กันยายน","ตุลาคม","พฤศจิกายน","ธันวาคม"
    ]
    private let thaiDays = ["อา.","จ.","อ.","พ.","พฤ.","ศ.","ส."]

    // ── Derived ───────────────────────────────────────────

    private var monthTitle: String {
        let m = cal.component(.month, from: currentMonth) - 1
        let y = cal.component(.year, from: currentMonth) + 543
        return "\(thaiMonths[m]) \(y)"
    }

    private struct CalDay { let date: Date; let inMonth: Bool }

    private var calendarDays: [CalDay] {
        let comps = cal.dateComponents([.year, .month], from: currentMonth)
        let first = cal.date(from: comps)!
        let firstWeekday = cal.component(.weekday, from: first) - 1 // 0 = Sun

        var days: [CalDay] = []
        for i in stride(from: firstWeekday - 1, through: 0, by: -1) {
            let d = cal.date(byAdding: .day, value: -(i + 1), to: first)!
            days.append(CalDay(date: d, inMonth: false))
        }
        let count = cal.range(of: .day, in: .month, for: currentMonth)!.count
        for i in 0..<count {
            let d = cal.date(byAdding: .day, value: i, to: first)!
            days.append(CalDay(date: d, inMonth: true))
        }
        let trailing = (7 - days.count % 7) % 7
        for i in 0..<trailing {
            let d = cal.date(byAdding: .day, value: i + 1, to: days.last!.date)!
            days.append(CalDay(date: d, inMonth: false))
        }
        return days
    }

    private func eventsFor(_ date: Date) -> [CalendarEvent] {
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        return allEvents.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        eventsFor(selectedDate).sorted { $0.startDate < $1.startDate }
    }

    private var selectedDayTitle: String {
        let c = cal.dateComponents([.day, .month, .year], from: selectedDate)
        return "\(c.day!) \(thaiMonths[(c.month ?? 1) - 1]) \(c.year! + 543)"
    }

    // ── Body ─────────────────────────────────────────────

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                calendarCard
                eventsCard
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            fabButton
        }
        .background(Theme.Colors.background)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add(let date):
                EventFormSheet(initialDate: date)
            case .edit(let event):
                EventFormSheet(event: event)
            }
        }
    }

    // ── Calendar Card ─────────────────────────────────────

    private var calendarCard: some View {
        VStack(spacing: 0) {
            topBar
            dayHeaders
            monthGrid
        }
        .background(Color.white)
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
    }

    private var topBar: some View {
        HStack(spacing: 0) {

            Spacer()

            Button { } label: {
                HStack(spacing: 4) {
                    Text(monthTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button { } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 56)
        .padding(.bottom, 4)
    }

    private var dayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(thaiDays, id: \.self) { d in
                Text(d)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(.systemGray))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private var monthGrid: some View {
        let days = calendarDays
        let rowCount = days.count / 7
        return VStack(spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7) { col in
                        let idx = row * 7 + col
                        if idx < days.count {
                            dayCell(days[idx])
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 10)
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { v in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        advanceMonth(by: v.translation.width < 0 ? 1 : -1)
                    }
                }
        )
    }

    private func dayCell(_ day: CalDay) -> some View {
        let todayFlag = cal.isDateInToday(day.date)
        let selectedFlag = cal.isDate(day.date, inSameDayAs: selectedDate)
        let dayEvents = eventsFor(day.date)

        return VStack(spacing: 3) {
            ZStack {
                if todayFlag {
                    Circle().fill(Theme.Colors.primary).frame(width: 32, height: 32)
                } else if selectedFlag {
                    Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 32, height: 32)
                }
                Text("\(cal.component(.day, from: day.date))")
                    .font(.system(size: 14, weight: todayFlag ? .bold : .regular))
                    .foregroundStyle(
                        todayFlag    ? Color.white :
                        !day.inMonth ? Color(.systemGray3) :
                        selectedFlag ? Theme.Colors.primary :
                        Theme.Colors.textPrimary
                    )
            }

            HStack(spacing: 2) {
                ForEach(dayEvents.prefix(3)) { event in
                    Circle()
                        .fill(todayFlag ? Color.white : event.color)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = day.date
            }
        }
        .onLongPressGesture {
            selectedDate = day.date
            activeSheet = .add(day.date)
        }
    }

    private func advanceMonth(by delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: currentMonth) {
            currentMonth = d
        }
    }

    // ── Events Card ───────────────────────────────────────

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(selectedDayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                if cal.isDateInToday(selectedDate) {
                    Text("วันนี้")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if eventsForSelectedDate.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(Color(.systemGray4))
                    Text("ไม่มีกิจกรรมในวันนี้")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(.systemGray))
                    Text("กดค้างที่วันหรือกดปุ่ม + เพื่อเพิ่ม")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.systemGray3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(eventsForSelectedDate) { event in
                    eventRow(event)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        Button {
            activeSheet = .edit(event)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Group {
                        if event.isAllDay {
                            Text("ทั้งวัน")
                        } else {
                            Text(event.startDate, format: .dateTime.hour().minute())
                        }
                    }
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(.systemGray))
                    .frame(width: 54, alignment: .leading)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(event.color)
                        .frame(width: 4, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        if !event.location.isEmpty {
                            Text(event.location)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(.systemGray))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider().padding(.leading, 82)
            }
        }
        .buttonStyle(.plain)
    }

    // ── FAB ──────────────────────────────────────────────

    private var fabButton: some View {
        Button {
            activeSheet = .add(selectedDate)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.primary)
                .clipShape(Circle())
                .shadow(color: Theme.Colors.primary.opacity(0.4), radius: 10, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - EventFormSheet  (Add & Edit)
// ══════════════════════════════════════════════════════════════

struct EventFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existingEvent: CalendarEvent?

    @State private var title: String
    @State private var isAllDay: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedColorHex: String
    @State private var showDeleteConfirm = false

    private let cal = Calendar(identifier: .gregorian)
    private let eventColors: [(hex: String, color: Color)] = [
        ("4A7DFF", Theme.Colors.primary),
        ("00BCD4", Theme.Colors.info),
        ("FFB347", Theme.Colors.warning),
        ("FF6B6B", Theme.Colors.danger),
        ("4CAF50", Theme.Colors.success),
        ("9C27B0", Theme.Colors.purple),
    ]

    // ── Add initializer ──
    init(initialDate: Date) {
        existingEvent = nil
        let dayStart = Calendar(identifier: .gregorian).startOfDay(for: initialDate)
        _title            = State(initialValue: "")
        _isAllDay         = State(initialValue: true)
        _startDate        = State(initialValue: dayStart)
        _endDate          = State(initialValue: Calendar(identifier: .gregorian).date(byAdding: .hour, value: 1, to: dayStart)!)
        _selectedColorHex = State(initialValue: "4A7DFF")
    }

    // ── Edit initializer ──
    init(event: CalendarEvent) {
        existingEvent     = event
        _title            = State(initialValue: event.title)
        _isAllDay         = State(initialValue: event.isAllDay)
        _startDate        = State(initialValue: event.startDate)
        _endDate          = State(initialValue: event.endDate)
        _selectedColorHex = State(initialValue: event.colorHex)
    }

    private var isEditing: Bool { existingEvent != nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    // ── Body ──────────────────────────────────────────────

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                dateSection
                colorSection
                if isEditing { deleteSection }
            }
            .navigationTitle(isEditing ? "แก้ไขกิจกรรม" : "กิจกรรมใหม่")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
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
    }

    // ── Sections ──────────────────────────────────────────

    private var titleSection: some View {
        Section {
            TextField("ชื่อกิจกรรม", text: $title)
                .submitLabel(.done)
        }
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

        if let event = existingEvent {
            event.title     = trimmed
            event.startDate = start
            event.endDate   = end
            event.isAllDay  = isAllDay
            event.colorHex  = selectedColorHex
            event.updatedAt = .now
        } else {
            modelContext.insert(CalendarEvent(
                title: trimmed, startDate: start, endDate: end,
                isAllDay: isAllDay, colorHex: selectedColorHex
            ))
        }
        dismiss()
    }

    private func delete() {
        if let event = existingEvent {
            modelContext.delete(event)
        }
        dismiss()
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Preview
// ══════════════════════════════════════════════════════════════

#Preview {
    NavigationStack { CalendarView() }
        .modelContainer(
            for: [CalendarEvent.self, CalendarTag.self, CalendarAttachmentItem.self],
            inMemory: true
        )
}
