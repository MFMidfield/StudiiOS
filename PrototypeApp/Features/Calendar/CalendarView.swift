//
//  CalendarView.swift
//  ปฏิทิน — monthly calendar grid + daily event list.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// ══════════════════════════════════════════════════════════════
// MARK: - Sheet routing
// ══════════════════════════════════════════════════════════════

private enum CalendarSheet: Identifiable {
    case add(Date)
    case edit(CalendarEvent)
    /// Ghost-drag just created this event speculatively — its `EventFormSheet`
    /// deletes it back out if the user cancels instead of leaving a stub.
    case editNewGhost(CalendarEvent)
    case editTask(Assignment)

    var id: String {
        switch self {
        case .add(let d):  return "add_\(d.timeIntervalSince1970)"
        case .edit(let e): return "edit_\(e.id)"
        case .editNewGhost(let e): return "editNewGhost_\(e.id)"
        case .editTask(let a): return "task_\(a.persistentModelID)"
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - CalendarView
// ══════════════════════════════════════════════════════════════

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]
    @Query private var allAssignments: [Assignment]
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var activeSheet: CalendarSheet?
    @State private var searchText = ""

    // Ghost Event drag state — kept at CalendarView level per §4.3, not per-cell.
    @State private var ghostPayload: GhostPayload?
    @State private var ghostOrigin: CGPoint = .zero
    @State private var ghostCurrentPosition: CGPoint = .zero
    @State private var ghostScale: CGFloat = 1.0
    @State private var gridSize: CGSize = .zero
    @State private var lastHapticCellIndex: Int?
    @State private var lastHapticTime: Date = .distantPast
    @State private var toastMessage: String?
    @State private var toastUndo: (() -> Void)?
    @State private var toastDismissTask: Task<Void, Never>?

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

    /// ทุก `CalendarEvent`/`Assignment` (ที่มีวันครบกำหนด) แปลงเป็น `CalendarItem`
    /// ครั้งเดียวแล้ว index ตาม `startOfDay` — กัน `itemsFor` วน array ทั้งก้อนใหม่
    /// ทุกครั้งที่ช่องวันแต่ละช่อง (42 ช่อง) render
    private var itemsByDay: [Date: [CalendarItem]] {
        var dict: [Date: [CalendarItem]] = [:]

        for event in allEvents {
            let item = CalendarItem(
                id: "event_\(event.id)",
                kind: .event,
                title: event.title,
                shortLabel: event.subjectName.isEmpty ? event.title : event.subjectName,
                date: event.startDate,
                isAllDay: event.isAllDay,
                color: event.color,
                isDone: false,
                sourceEvent: event,
                sourceTask: nil
            )
            dict[cal.startOfDay(for: event.startDate), default: []].append(item)
        }

        for task in allAssignments.inTerm(activeTerm) {
            guard let due = task.resolvedDueDate else { continue }
            let kind: CalendarItemKind = task.kind == .exam ? .exam : task.kind == .personal ? .personal : .homework
            let item = CalendarItem(
                id: "task_\(task.persistentModelID)",
                kind: kind,
                title: task.title,
                shortLabel: task.subjectName.isEmpty ? task.title : task.subjectName,
                date: due,
                isAllDay: true,
                color: subjectColor(for: task),
                isDone: task.isDone,
                sourceEvent: nil,
                sourceTask: task
            )
            dict[cal.startOfDay(for: due), default: []].append(item)
        }

        for key in dict.keys {
            dict[key]?.sort { lhs, rhs in
                lhs.sortRank != rhs.sortRank ? lhs.sortRank < rhs.sortRank : lhs.date < rhs.date
            }
        }
        return dict
    }

    private func itemsFor(_ date: Date) -> [CalendarItem] {
        itemsByDay[cal.startOfDay(for: date)] ?? []
    }

    private func subjectColor(for task: Assignment) -> Color {
        guard !task.subjectName.isEmpty,
              let subject = subjects.first(where: { $0.name.caseInsensitiveCompare(task.subjectName) == .orderedSame })
        else { return Theme.Colors.primaryDeep }
        return subject.color
    }

    private var itemsForSelectedDate: [CalendarItem] {
        itemsFor(selectedDate)
    }

    private var selectedDayTitle: String {
        let c = cal.dateComponents([.day, .month, .year], from: selectedDate)
        return "\(c.day!) \(thaiMonths[(c.month ?? 1) - 1]) \(c.year! + 543)"
    }

    private var isOnCurrentMonthAndToday: Bool {
        cal.isDate(currentMonth, equalTo: .now, toGranularity: .month) && cal.isDateInToday(selectedDate)
    }

    // ── Body ─────────────────────────────────────────────

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
            if searchText.isEmpty { fabButton }
        }
        .overlay(alignment: .bottom) { moveToast }
        .background(Theme.Colors.background)
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { calendarToolbar }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "ค้นหากิจกรรม การบ้าน วิชา")
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if searchText.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    calendarCard
                    eventsCard
                }
            }
            .scrollDisabled(ghostPayload != nil)
        } else {
            searchResultsList
        }
    }

    @ToolbarContentBuilder
    private var calendarToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 4) {
                Button { advanceMonth(by: -1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                Button { advanceMonth(by: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("วันนี้", action: jumpToToday)
                .disabled(isOnCurrentMonthAndToday)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: CalendarSheet) -> some View {
        switch sheet {
        case .add(let date):
            EventFormSheet(initialDate: date)
        case .edit(let event):
            EventFormSheet(event: event)
        case .editNewGhost(let event):
            EventFormSheet(event: event, deleteOnCancel: true)
        case .editTask(let task):
            AddTaskSheet(editing: task)
        }
    }

    private func jumpToToday() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentMonth = .now
            selectedDate = .now
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // ── Calendar Card ─────────────────────────────────────

    private var calendarCard: some View {
        VStack(spacing: 0) {
            dayHeaders
            monthGrid
        }
        .background(Theme.Colors.cardBackground)
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
    }

    private var dayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(thaiDays, id: \.self) { d in
                Text(d)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
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
        .coordinateSpace(name: "monthGrid")
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { gridSize = $0 }
        .simultaneousGesture(ghostGesture)
        .overlay(ghostOverlay)
        .padding(.horizontal, 6)
        .padding(.bottom, 10)
    }

    private func dayCell(_ day: CalDay) -> some View {
        let todayFlag = cal.isDateInToday(day.date)
        let selectedFlag = cal.isDate(day.date, inSameDayAs: selectedDate)
        let dayItems = day.inMonth ? itemsFor(day.date) : []

        return VStack(spacing: 3) {
            ZStack {
                if todayFlag {
                    Circle().fill(Theme.Colors.primaryDeep).frame(width: 32, height: 32)
                } else if selectedFlag {
                    Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 32, height: 32)
                }
                Text("\(cal.component(.day, from: day.date))")
                    .font(.system(size: 14, weight: todayFlag ? .bold : .regular))
                    .foregroundStyle(
                        todayFlag    ? Theme.Colors.onPrimary :
                        !day.inMonth ? Theme.Colors.textSecondary.opacity(0.5) :
                        selectedFlag ? Theme.Colors.primaryDeep :
                        Theme.Colors.textPrimary
                    )
            }
            .frame(height: 24)

            dayPills(dayItems)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = day.date
            }
        }
    }

    @ViewBuilder
    private func dayPills(_ items: [CalendarItem]) -> some View {
        let visible = items.prefix(2)
        let overflow = items.count - visible.count
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(visible)) { item in
                dayPill(item)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.leading, 3)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 3)
    }

    private func dayPill(_ item: CalendarItem) -> some View {
        HStack(spacing: 3) {
            Circle().fill(item.color).frame(width: 5, height: 5)
            Text(item.shortLabel)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 14)
        .opacity(isBeingDragged(item) ? 0.3 : 1)
    }

    private func advanceMonth(by delta: Int) {
        guard let d = cal.date(byAdding: .month, value: delta, to: currentMonth) else { return }
        withAnimation(.spring(response: 0.40, dampingFraction: 0.85)) {
            currentMonth = d
        }
    }

    // ── Ghost Event ────────────────────────────────────────

    private enum GhostPayload {
        case newEvent
        case existingEvent(CalendarEvent)
        case existingTask(Assignment)
    }

    private func isBeingDragged(_ item: CalendarItem) -> Bool {
        switch ghostPayload {
        case .existingEvent(let e): return item.sourceEvent === e
        case .existingTask(let t): return item.sourceTask === t
        default: return false
        }
    }

    /// เลขคณิตอย่างเดียว ไม่ใช้ GeometryReader ต่อช่อง (42 ช่องจะกิน CPU) —
    /// วัดขนาดกริดครั้งเดียวผ่าน `.onGeometryChange` แล้วหารเอาเอง
    private var cellSize: CGSize {
        let rowCount = max(calendarDays.count / 7, 1)
        return CGSize(width: gridSize.width / 7, height: gridSize.height / CGFloat(rowCount))
    }

    private func cellIndex(at point: CGPoint) -> Int? {
        let size = cellSize
        guard size.width > 0, size.height > 0, point.x >= 0, point.y >= 0 else { return nil }
        let days = calendarDays
        let rowCount = days.count / 7
        let col = Int(point.x / size.width)
        let row = Int(point.y / size.height)
        guard col >= 0, col < 7, row >= 0, row < rowCount else { return nil }
        let idx = row * 7 + col
        return idx < days.count ? idx : nil
    }

    private func cellCenter(for index: Int) -> CGPoint {
        let size = cellSize
        let col = index % 7
        let row = index / 7
        return CGPoint(x: size.width * (CGFloat(col) + 0.5), y: size.height * (CGFloat(row) + 0.5))
    }

    /// ตำแหน่งนิ้วในช่อง → pill ไหน ต้องตรงกับ layout จริงใน `dayCell`/`dayPills`
    /// (เลขวันสูง 24 + spacing 3 = 27, แต่ละ pill สูง 14 + spacing 2 = 16)
    private func hitTestItem(at point: CGPoint, cellIndex idx: Int) -> CalendarItem? {
        let days = calendarDays
        guard idx < days.count, days[idx].inMonth else { return nil }
        let items = itemsFor(days[idx].date)
        guard !items.isEmpty else { return nil }

        let size = cellSize
        guard size.height > 0 else { return nil }
        let row = idx / 7
        let localY = point.y - CGFloat(row) * size.height
        let numberRowHeight: CGFloat = 27
        let pillRowHeight: CGFloat = 16
        guard localY >= numberRowHeight else { return nil }
        let pillIndex = Int((localY - numberRowHeight) / pillRowHeight)
        let visibleCount = min(items.count, 2)
        guard pillIndex >= 0, pillIndex < visibleCount else { return nil }
        return items[pillIndex]
    }

    private var ghostGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("monthGrid")))
            .onChanged { value in
                guard case .second(true, let drag) = value, let drag else { return }
                if ghostPayload == nil {
                    beginGhost(at: drag.startLocation)
                }
                moveGhost(to: drag.location)
            }
            .onEnded { value in
                guard case .second(true, let drag) = value else {
                    cancelGhostIfNeeded()
                    return
                }
                endGhost(at: drag?.location)
            }
    }

    private func beginGhost(at point: CGPoint) {
        guard let idx = cellIndex(at: point) else { return }
        if let item = hitTestItem(at: point, cellIndex: idx) {
            if let event = item.sourceEvent {
                ghostPayload = .existingEvent(event)
            } else if let task = item.sourceTask {
                ghostPayload = .existingTask(task)
            } else {
                return
            }
        } else {
            ghostPayload = .newEvent
        }

        ghostOrigin = point
        ghostCurrentPosition = point
        ghostScale = 1.0
        lastHapticCellIndex = idx
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
            ghostScale = 1.08
        }
    }

    private func moveGhost(to point: CGPoint) {
        ghostCurrentPosition = point
        guard let idx = cellIndex(at: point), idx != lastHapticCellIndex else { return }
        lastHapticCellIndex = idx
        let now = Date()
        guard now.timeIntervalSince(lastHapticTime) >= 0.06 else { return }
        lastHapticTime = now
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func endGhost(at point: CGPoint?) {
        guard ghostPayload != nil else { return }
        guard let point, let idx = cellIndex(at: point) else {
            flyBack()
            return
        }
        let targetDay = calendarDays[idx]
        let targetCenter = cellCenter(for: idx)

        func settle(_ commit: @escaping () -> Void) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                ghostCurrentPosition = targetCenter
                ghostScale = 1.0
            } completion: {
                commit()
                resetGhostState()
            }
        }

        switch ghostPayload {
        case .newEvent:
            settle { createEvent(on: targetDay.date) }
        case .existingEvent(let event):
            if cal.isDate(event.startDate, inSameDayAs: targetDay.date) {
                flyBack()
            } else {
                settle { moveEvent(event, to: targetDay.date) }
            }
        case .existingTask(let task):
            if let due = task.resolvedDueDate, cal.isDate(due, inSameDayAs: targetDay.date) {
                flyBack()
            } else {
                settle { moveTask(task, to: targetDay.date) }
            }
        case nil:
            break
        }
    }

    private func flyBack() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
            ghostCurrentPosition = ghostOrigin
            ghostScale = 1.0
        } completion: {
            resetGhostState()
        }
    }

    private func cancelGhostIfNeeded() {
        if ghostPayload != nil { flyBack() }
    }

    private func resetGhostState() {
        ghostPayload = nil
        lastHapticCellIndex = nil
    }

    private func createEvent(on date: Date) {
        let dayStart = cal.startOfDay(for: date)
        let newEvent = CalendarEvent(
            title: "กิจกรรมใหม่",
            startDate: dayStart,
            endDate: cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart,
            isAllDay: true
        )
        modelContext.insert(newEvent)
        try? modelContext.save()
        selectedDate = date
        activeSheet = .editNewGhost(newEvent)
    }

    private func moveEvent(_ event: CalendarEvent, to date: Date) {
        let originalStart = event.startDate
        let originalEnd = event.endDate
        let duration = originalEnd.timeIntervalSince(originalStart)

        let newStart: Date
        if event.isAllDay {
            newStart = cal.startOfDay(for: date)
        } else {
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            let time = cal.dateComponents([.hour, .minute, .second], from: originalStart)
            comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second
            newStart = cal.date(from: comps) ?? originalStart
        }

        event.startDate = newStart
        event.endDate = newStart.addingTimeInterval(duration)
        event.updatedAt = .now
        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: event) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        showMoveToast(dateLabel: newStart.thaiShortNoYearString) {
            event.startDate = originalStart
            event.endDate = originalEnd
            event.updatedAt = .now
            try? modelContext.save()
            Task { await NotificationManager.shared.schedule(for: event) }
        }
    }

    private func moveTask(_ task: Assignment, to date: Date) {
        guard let originalDue = task.resolvedDueDate else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let time = cal.dateComponents([.hour, .minute, .second], from: originalDue)
        comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second
        let newDue = cal.date(from: comps) ?? originalDue

        task.dueDate = newDue
        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        showMoveToast(dateLabel: newDue.thaiShortNoYearString) {
            task.dueDate = originalDue
            try? modelContext.save()
            Task { await NotificationManager.shared.schedule(for: task) }
        }
    }

    @ViewBuilder
    private var ghostOverlay: some View {
        if let payload = ghostPayload {
            GhostPillView(
                label: ghostLabel(for: payload),
                color: ghostColor(for: payload),
                scale: ghostScale,
                position: ghostCurrentPosition
            )
        }
    }

    private func ghostLabel(for payload: GhostPayload) -> String {
        switch payload {
        case .newEvent: return "กิจกรรมใหม่"
        case .existingEvent(let e): return e.subjectName.isEmpty ? e.title : e.subjectName
        case .existingTask(let t): return t.subjectName.isEmpty ? t.title : t.subjectName
        }
    }

    private func ghostColor(for payload: GhostPayload) -> Color {
        switch payload {
        case .newEvent: return Theme.Colors.primary
        case .existingEvent(let e): return e.color
        case .existingTask(let t): return subjectColor(for: t)
        }
    }

    // ── Move toast ("เลื่อนไป... เลิกทำ") ───────────────────

    private func showMoveToast(dateLabel: String, undo: @escaping () -> Void) {
        toastDismissTask?.cancel()
        withAnimation { toastMessage = "ย้ายไป \(dateLabel) แล้ว" }
        toastUndo = undo
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { toastMessage = nil }
            toastUndo = nil
        }
    }

    private func dismissToast(runUndo: Bool) {
        toastDismissTask?.cancel()
        if runUndo { toastUndo?() }
        withAnimation { toastMessage = nil }
        toastUndo = nil
    }

    @ViewBuilder
    private var moveToast: some View {
        if let message = toastMessage {
            HStack {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button("เลิกทำ") { dismissToast(runUndo: true) }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
                        .foregroundStyle(Theme.Colors.primaryDeep)
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

            if itemsForSelectedDate.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                    Text("ไม่มีกิจกรรมในวันนี้")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("กดค้างที่วันหรือกดปุ่ม + เพื่อเพิ่ม")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(itemsForSelectedDate) { item in
                    itemRow(item)
                }
            }
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }

    private func itemRow(_ item: CalendarItem) -> some View {
        Button {
            if let event = item.sourceEvent {
                activeSheet = .edit(event)
            } else if let task = item.sourceTask {
                activeSheet = .editTask(task)
            }
        } label: {
            itemRowContent(item)
        }
        .buttonStyle(.plain)
    }

    /// Shared row layout — used by `itemRow` (tap = open editor) and
    /// `searchResultRow` (tap = jump to that date) so the two never drift.
    private func itemRowContent(_ item: CalendarItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                itemLeadingMark(item)
                    .frame(width: 54, alignment: .leading)

                RoundedRectangle(cornerRadius: 2)
                    .fill(item.color)
                    .frame(width: 4, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(item.isDone ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                            .strikethrough(item.isDone)
                            .lineLimit(1)
                        if let event = item.sourceEvent, event.alert != .none {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    if let subtitle = itemSubtitle(item) {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.leading, 82)
        }
    }

    // ── Search ───────────────────────────────────────────

    private var searchResults: [CalendarItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var results: [CalendarItem] = []

        for event in allEvents {
            let matches = event.title.lowercased().contains(q)
                || event.location.lowercased().contains(q)
                || event.notes.lowercased().contains(q)
                || event.subjectName.lowercased().contains(q)
                || event.tags.contains { $0.name.lowercased().contains(q) }
            guard matches else { continue }
            results.append(CalendarItem(
                id: "event_\(event.id)",
                kind: .event,
                title: event.title,
                shortLabel: event.subjectName.isEmpty ? event.title : event.subjectName,
                date: event.startDate,
                isAllDay: event.isAllDay,
                color: event.color,
                isDone: false,
                sourceEvent: event,
                sourceTask: nil
            ))
        }

        for task in allAssignments.inTerm(activeTerm) {
            guard let due = task.resolvedDueDate else { continue }
            let matches = task.title.lowercased().contains(q)
                || task.detail.lowercased().contains(q)
                || task.subjectName.lowercased().contains(q)
            guard matches else { continue }
            let kind: CalendarItemKind = task.kind == .exam ? .exam : task.kind == .personal ? .personal : .homework
            results.append(CalendarItem(
                id: "task_\(task.persistentModelID)",
                kind: kind,
                title: task.title,
                shortLabel: task.subjectName.isEmpty ? task.title : task.subjectName,
                date: due,
                isAllDay: true,
                color: subjectColor(for: task),
                isDone: task.isDone,
                sourceEvent: nil,
                sourceTask: task
            ))
        }

        return results.sorted { $0.date < $1.date }
    }

    private var groupedSearchResults: [(month: String, items: [CalendarItem])] {
        let groups = Dictionary(grouping: searchResults) { item -> Int in
            let c = cal.dateComponents([.year, .month], from: item.date)
            return (c.year ?? 0) * 12 + (c.month ?? 0)
        }
        return groups.keys.sorted().compactMap { key in
            guard let items = groups[key], let first = items.first else { return nil }
            let c = cal.dateComponents([.month, .year], from: first.date)
            let label = "\(thaiMonths[(c.month ?? 1) - 1]) \(c.year! + 543)"
            return (month: label, items: items)
        }
    }

    @ViewBuilder
    private var searchResultsList: some View {
        if searchResults.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(groupedSearchResults, id: \.month) { group in
                        Text(group.month)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 0) {
                            ForEach(group.items) { item in
                                searchResultRow(item)
                            }
                        }
                        .background(Theme.Colors.cardBackground)
                    }
                }
            }
        }
    }

    private func searchResultRow(_ item: CalendarItem) -> some View {
        Button {
            jumpToSearchResult(item)
        } label: {
            itemRowContent(item)
        }
        .buttonStyle(.plain)
    }

    private func jumpToSearchResult(_ item: CalendarItem) {
        searchText = ""
        currentMonth = item.date
        selectedDate = item.date
    }

    @ViewBuilder
    private func itemLeadingMark(_ item: CalendarItem) -> some View {
        if item.kind == .event {
            Group {
                if item.isAllDay {
                    Text("ทั้งวัน")
                } else {
                    Text(item.date, format: .dateTime.hour().minute())
                }
            }
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.Colors.textSecondary)
        } else {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(item.isDone ? Theme.Colors.success : item.color)
        }
    }

    private func itemSubtitle(_ item: CalendarItem) -> String? {
        switch item.kind {
        case .event:
            guard let event = item.sourceEvent else { return nil }
            let parts = [event.subjectName, event.location].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .exam:
            guard let task = item.sourceTask else { return nil }
            let parts = [task.examScope?.label, task.subjectName.isEmpty ? nil : task.subjectName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .homework, .personal:
            guard let task = item.sourceTask, !task.subjectName.isEmpty else { return nil }
            return task.subjectName
        }
    }

    // ── FAB ──────────────────────────────────────────────

    private var fabButton: some View {
        Button {
            activeSheet = .add(selectedDate)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.onPrimary)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.primaryDeep)
                .clipShape(Circle())
                .shadow(color: Theme.Colors.primaryDeep.opacity(0.4), radius: 10, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - Preview
// ══════════════════════════════════════════════════════════════

#Preview {
    NavigationStack { CalendarView() }
        .modelContainer(
            for: [CalendarEvent.self, CalendarTag.self, CalendarAttachmentItem.self, Assignment.self, Subject.self, Term.self],
            inMemory: true
        )
}
