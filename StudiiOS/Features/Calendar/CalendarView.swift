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
    // `internal` ไม่ใช่ `private` เพราะ CalendarDragController.swift
    // เป็น extension ของ struct นี้ อยู่คนละไฟล์ — ขั้นที่ 6 จะย้ายสถานะ ghost
    // ออกไปเป็นตัวควบคุมของตัวเอง แล้วค่อยปิดกลับเป็น private
    @Environment(\.modelContext) var modelContext
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]
    @Query private var allAssignments: [Assignment]
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    @State var selectedDate = Date()
    @State var activeSheet: CalendarSheet?
    @State private var displayedYear = Calendar(identifier: .gregorian).component(.year, from: .now)
    /// id ของเดือนที่อยู่บนสุดของจอ — ผูกกับ `scrollPosition` หัวเดือนอ่านจากตัวนี้
    @State private var visibleMonthID: String?

    // Ghost Event drag state — kept at CalendarView level per §4.3, not per-cell.
    @State var ghostPayload: CalendarGhostPayload?
    @State var ghostOrigin: CGPoint = .zero
    @State var ghostCurrentPosition: CGPoint = .zero
    @State var ghostScale: CGFloat = 1.0
    /// id เดือน → frame ในระบบพิกัดสายเลื่อน · 12 รายการ ไม่ใช่ 365 (§5.1)
    @State var monthFrames: [String: CGRect] = [:]
    @State var lastHapticDay: Date?
    @State var lastHapticTime: Date = .distantPast
    @State var toastMessage: String?
    @State var toastUndo: (() -> Void)?
    @State var toastDismissTask: Task<Void, Never>?

    let cal = Calendar(identifier: .gregorian)

    // ── Derived ───────────────────────────────────────────

    var months: [CalendarMonthInfo] {
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

    var itemsByID: [String: CalendarItem] {
        CalendarItemBuilder.byID(allItems)
    }

    /// ผลจัดเลนของสัปดาห์ที่ขึ้นต้นด้วย `weekStart` — ใช้ทั้งตอนวาดและตอน hit-test
    func weekLayout(weekStart: Date) -> WeekLayout {
        MonthLayoutEngine.layout(
            items: CalendarItemBuilder.layoutItems(allItems, calendar: cal),
            weekStart: weekStart,
            maxLanes: CalendarGeometry.maxLanes,
            calendar: cal
        )
    }

    func itemsFor(_ date: Date) -> [CalendarItem] {
        itemsByDay[cal.startOfDay(for: date)] ?? []
    }

    func subjectColor(for task: Assignment) -> Color {
        guard !task.subjectName.isEmpty,
              let subject = subjects.first(where: { $0.name.caseInsensitiveCompare(task.subjectName) == .orderedSame })
        else { return Theme.Colors.primaryDeep }
        return subject.color
    }

    private func dayTitle(_ date: Date) -> String {
        let c = cal.dateComponents([.day, .month, .year], from: date)
        return "\(c.day!) \(CalendarStrings.thaiMonths[(c.month ?? 1) - 1]) \(c.year! + 543)"
    }

    // ── Body ─────────────────────────────────────────────

    var body: some View {
        VStack(spacing: 0) {
            header
            CalendarDayHeaderRow()
            monthScroll
        }
        .overlay(alignment: .bottom) { moveToast }
        .background(Theme.Colors.background)
        // หัวเดือนอยู่ในหน้าแล้ว nav bar จึงเหลือไว้แค่ปุ่มย้อนกลับ
        // (ห้าม `.navigationBarHidden(true)` — ปุ่มย้อนกลับจะหายไปด้วย เข้ามาแล้วออกไม่ได้)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
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
                        isBeingDragged: isBeingDragged,
                        onSelectDay: selectDay,
                        onFrameChange: { monthFrames[month.id] = $0 }
                    )
                    .id(month.id)
                }
            }
            .scrollTargetLayout()
        }
        .coordinateSpace(.named(Self.gridSpaceName))
        .scrollPosition(id: $visibleMonthID, anchor: .top)
        .scrollDisabled(ghostPayload != nil)
        .gesture(ghostGesture)
        .overlay(ghostOverlay)
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
            CalendarDayItemsCard(
                title: dayTitle(date),
                isToday: cal.isDateInToday(date),
                items: itemsFor(date),
                onSelect: openItem
            )
            .presentationDetents([.medium, .large])
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
            activeSheet = .edit(event)
        } else if let task = item.sourceTask {
            activeSheet = .editTask(task)
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
