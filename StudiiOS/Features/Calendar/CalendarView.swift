//
//  CalendarView.swift
//  ปฏิทิน — สายเลื่อนแนวตั้ง 12 เดือนภายในปีเดียว
//
//  ก้อน G (08_Calendar §8) — ขั้นที่ 1 แตกไฟล์ · 2 MonthLayoutEngine
//  · 3 แถบพาดข้ามช่อง · 4 สายเลื่อน 12 เดือน + หัวเดือน/ปีในหน้า
//  ไฟล์ที่แยกออกไป: CalendarMonthSection · CalendarWeekRow · CalendarEventBar
//  · CalendarDaySheet · CalendarSearchView · CalendarDragController
//  · CalendarItemBuilder · CalendarPressDragGesture
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

// ══════════════════════════════════════════════════════════════
// MARK: - Sheet routing
// ══════════════════════════════════════════════════════════════

enum CalendarSheet: Identifiable {
    case add(Date)
    case edit(CalendarEvent)
    /// Ghost-drag just created this event speculatively — its `EventFormSheet`
    /// deletes it back out if the user cancels instead of leaving a stub.
    case editNewGhost(CalendarEvent)
    case editTask(Assignment)
    case day(Date)
    case search

    var id: String {
        switch self {
        case .add(let d):  return "add_\(d.timeIntervalSince1970)"
        case .edit(let e): return "edit_\(e.id)"
        case .editNewGhost(let e): return "editNewGhost_\(e.id)"
        case .editTask(let a): return "task_\(a.persistentModelID)"
        case .day(let d): return "day_\(d.timeIntervalSince1970)"
        case .search: return "search"
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - CalendarView
// ══════════════════════════════════════════════════════════════

struct CalendarView: View {
    /// ชื่อระบบพิกัดของสายเลื่อน — `CalendarMonthSection` รายงาน frame เข้ามาในระบบนี้
    /// และ ghost drag อ่านตำแหน่งนิ้วในระบบเดียวกัน
    static let gridSpaceName = "calScroll"

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]
    @Query private var allAssignments: [Assignment]
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    @State private var selectedDate = Date()
    @State private var activeSheet: CalendarSheet?
    /// sheet ที่รอเปิดต่อหลัง sheet ปัจจุบันปิด (แตะแถวใน sheet รายวัน)
    @State private var pendingSheet: CalendarSheet?
    @State private var displayedYear = Calendar(identifier: .gregorian).component(.year, from: .now)
    /// id ของเดือนที่อยู่บนสุดของจอ — ผูกกับ `scrollPosition` หัวเดือนอ่านจากตัวนี้
    @State private var visibleMonthID: String?

    /// สถานะการลาก + toast อยู่ในตัวควบคุมของมันเอง ไม่กระจายใน view (ขั้นที่ 6)
    @State private var drag = CalendarDragController()

    private let cal = Calendar(identifier: .gregorian)

    // ── Derived ───────────────────────────────────────────

    private var months: [CalendarMonthInfo] {
        CalendarMonthBuilder.months(inYear: displayedYear, calendar: cal)
    }

    private var currentMonthTitle: String {
        guard let id = visibleMonthID, let month = months.first(where: { $0.id == id }) else {
            return months.first?.title ?? ""
        }
        return month.title
    }

    /// ปีปัจจุบัน −1 ถึง +2 (§3.2)
    private var selectableYears: [Int] {
        let thisYear = cal.component(.year, from: .now)
        return Array((thisYear - 1)...(thisYear + 2))
    }

    private var isOnTodayAlready: Bool {
        displayedYear == cal.component(.year, from: .now)
            && visibleMonthID == CalendarMonthBuilder.key(for: .now, calendar: cal)
            && cal.isDateInToday(selectedDate)
    }

    /// ทุก `CalendarEvent`/`Assignment` (ที่มีวันครบกำหนด) แปลงเป็น `CalendarItem` ชุดเดียว
    private var allItems: [CalendarItem] {
        CalendarItemBuilder.items(
            events: allEvents,
            tasks: allAssignments.inTerm(activeTerm),
            color: subjectColor
        )
    }

    private var itemsByDay: [Date: [CalendarItem]] {
        CalendarItemBuilder.itemsByDay(allItems, calendar: cal)
    }

    private var itemsByID: [String: CalendarItem] {
        CalendarItemBuilder.byID(allItems)
    }

    /// ผลจัดเลนของสัปดาห์ที่ขึ้นต้นด้วย `weekStart` — ใช้ทั้งตอนวาดและตอน hit-test
    private func weekLayout(weekStart: Date) -> WeekLayout {
        MonthLayoutEngine.layout(
            items: CalendarItemBuilder.layoutItems(allItems, calendar: cal),
            weekStart: weekStart,
            maxLanes: CalendarGeometry.maxLanes,
            calendar: cal
        )
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

    /// ทุกอย่างที่ตัวควบคุมการลากต้องรู้ในจังหวะนี้
    private var dragEnvironment: CalendarDragController.Environment {
        .init(
            calendar: cal,
            months: months,
            itemsByID: itemsByID,
            weekLayout: weekLayout(weekStart:),
            modelContext: modelContext,
            subjectColor: subjectColor,
            onCreatedEvent: { present(.editNewGhost($0)) },
            onSelectDate: { selectedDate = $0 }
        )
    }

    // ── Body ─────────────────────────────────────────────

    var body: some View {
        VStack(spacing: 0) {
            header
            CalendarDayHeaderRow()
            monthScroll
        }
        .overlay(alignment: .bottom) { CalendarMoveToast(controller: drag) }
        .background(Theme.Colors.background)
        // หัวเดือนอยู่ในหน้าแล้ว nav bar จึงเหลือไว้แค่ปุ่มย้อนกลับ
        // (ห้าม `.navigationBarHidden(true)` — ปุ่มย้อนกลับจะหายไปด้วย เข้ามาแล้วออกไม่ได้)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet, onDismiss: {
            if let next = pendingSheet {
                pendingSheet = nil
                activeSheet = next
            }
        }) { sheet in
            sheetContent(sheet)
        }
        .onAppear {
            if visibleMonthID == nil {
                visibleMonthID = CalendarMonthBuilder.key(for: .now, calendar: cal)
            }
        }
    }

    // ── หัวเดือน / ปี (§3.2) ───────────────────────────────

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(currentMonthTitle)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .contentTransition(.numericText())

                Menu {
                    ForEach(selectableYears, id: \.self) { year in
                        Button("\(year + 543)") { jumpToYear(year) }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("\(displayedYear + 543)")
                        Image(systemName: "chevron.down")
                            .font(Theme.Font.caption)
                    }
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.primaryDeep)
                }
            }

            Spacer()

            Button("วันนี้", action: jumpToToday)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.primaryDeep)
                .disabled(isOnTodayAlready)

            Button {
                activeSheet = .search
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.primaryDeep)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
    }

    // ── สายเลื่อน 12 เดือน ─────────────────────────────────

    private var monthScroll: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                ForEach(months) { month in
                    CalendarMonthSection(
                        month: month,
                        selectedDate: selectedDate,
                        calendar: cal,
                        itemsByID: itemsByID,
                        weekLayout: weekLayout(weekStart:),
                        isBeingDragged: drag.isBeingDragged,
                        onSelectDay: selectDay,
                        onSelectItem: openItem,
                        onFrameChange: { drag.monthFrames[month.id] = $0 }
                    )
                    .id(month.id)
                }
            }
            .scrollTargetLayout()
        }
        .coordinateSpace(.named(Self.gridSpaceName))
        .scrollPosition(id: $visibleMonthID, anchor: .top)
        .scrollDisabled(drag.isDragging)
        .gesture(ghostGesture)
        .overlay(CalendarGhostOverlay(controller: drag, env: dragEnvironment))
    }

    /// กดค้างแล้วลาก — ห้ามใช้ gesture ของ SwiftUI ตรงนี้ ScrollView จะเลื่อนไม่ได้
    private var ghostGesture: some UIGestureRecognizerRepresentable {
        CalendarPressDragGesture(
            space: .named(Self.gridSpaceName),
            onBegan: { drag.begin(at: $0, env: dragEnvironment) },
            onChanged: { drag.move(to: $0, env: dragEnvironment) },
            onEnded: { drag.end(at: $0, env: dragEnvironment) }
        )
    }

    // ── Sheet ────────────────────────────────────────────

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
        case .day(let date):
            CalendarDaySheet(
                date: date,
                isToday: cal.isDateInToday(date),
                items: itemsFor(date),
                onSelect: openItem,
                onAddEvent: { present(.add($0)) }
            )
            // เต็มจอไปเลย — Few ว่าเปิดครึ่งจอแล้วต้องลากขึ้นเองมันเกินจำเป็น
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        case .search:
            CalendarSearchSheet(
                calendar: cal,
                results: searchResults(for:),
                onSelect: jumpToSearchResult
            )
        }
    }

    private func openItem(_ item: CalendarItem) {
        if let event = item.sourceEvent {
            present(.edit(event))
        } else if let task = item.sourceTask {
            present(.editTask(task))
        }
    }

    /// เปิด sheet ใหม่ทับของเดิมไม่ได้ — ถ้ามี sheet ค้างอยู่ (เช่น sheet รายวัน)
    /// ต้องปิดก่อนแล้วค่อยเปิดตัวใหม่ตอน `onDismiss`
    private func present(_ sheet: CalendarSheet) {
        if activeSheet == nil {
            activeSheet = sheet
        } else {
            pendingSheet = sheet
            activeSheet = nil
        }
    }

    // ── การเลื่อน ─────────────────────────────────────────

    private func selectDay(_ date: Date) {
        selectedDate = date
        activeSheet = .day(date)
    }

    private func jumpToToday() {
        displayedYear = cal.component(.year, from: .now)
        selectedDate = .now
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            visibleMonthID = CalendarMonthBuilder.key(for: .now, calendar: cal)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func jumpToYear(_ year: Int) {
        guard year != displayedYear else { return }
        displayedYear = year
        visibleMonthID = String(format: "%04d-01", year)
    }

    // ── Search ───────────────────────────────────────────

    private func searchResults(for query: String) -> [CalendarItem] {
        CalendarItemBuilder.searchResults(
            query: query,
            events: allEvents,
            tasks: allAssignments.inTerm(activeTerm),
            color: subjectColor
        )
    }

    private func jumpToSearchResult(_ item: CalendarItem) {
        displayedYear = cal.component(.year, from: item.date)
        selectedDate = item.date
        visibleMonthID = CalendarMonthBuilder.key(for: item.date, calendar: cal)
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
