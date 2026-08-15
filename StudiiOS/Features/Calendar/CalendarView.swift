//
//  CalendarView.swift
//  ปฏิทิน — monthly calendar grid + daily event list.
//
//  ก้อน G ขั้นที่ 1 (08_Calendar §8): แตกไฟล์ตาม §6 โดย **ไม่เปลี่ยนพฤติกรรม**
//    · ตารางเดือน  → CalendarMonthSection / CalendarWeekRow / CalendarEventBar
//    · การ์ดรายวัน → CalendarDaySheet
//    · ผลค้นหา    → CalendarSearchView
//    · ghost drag → CalendarDragController (ยังเป็น extension ของหน้านี้อยู่)
//  ที่เหลือของหน้า (สถานะ · query · routing) อยู่ในไฟล์นี้
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
    @State private var currentMonth = Date()
    @State var activeSheet: CalendarSheet?
    @State private var searchText = ""

    // Ghost Event drag state — kept at CalendarView level per §4.3, not per-cell.
    @State var ghostPayload: CalendarGhostPayload?
    @State var ghostOrigin: CGPoint = .zero
    @State var ghostCurrentPosition: CGPoint = .zero
    @State var ghostScale: CGFloat = 1.0
    @State var gridSize: CGSize = .zero
    @State var lastHapticCellIndex: Int?
    @State var lastHapticTime: Date = .distantPast
    @State var toastMessage: String?
    @State var toastUndo: (() -> Void)?
    @State var toastDismissTask: Task<Void, Never>?

    let cal = Calendar(identifier: .gregorian)

    // ── Derived ───────────────────────────────────────────

    private var monthTitle: String {
        let m = cal.component(.month, from: currentMonth) - 1
        let y = cal.component(.year, from: currentMonth) + 543
        return "\(CalendarStrings.thaiMonths[m]) \(y)"
    }

    var calendarDays: [CalendarDay] {
        CalendarMonthBuilder.days(of: currentMonth, calendar: cal)
    }

    /// ทุก `CalendarEvent`/`Assignment` (ที่มีวันครบกำหนด) แปลงเป็น `CalendarItem`
    /// ครั้งเดียวแล้ว index ตาม `startOfDay`
    private var itemsByDay: [Date: [CalendarItem]] {
        CalendarItemBuilder.itemsByDay(
            events: allEvents,
            tasks: allAssignments.inTerm(activeTerm),
            calendar: cal,
            color: subjectColor
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

    private var itemsForSelectedDate: [CalendarItem] {
        itemsFor(selectedDate)
    }

    private var selectedDayTitle: String {
        let c = cal.dateComponents([.day, .month, .year], from: selectedDate)
        return "\(c.day!) \(CalendarStrings.thaiMonths[(c.month ?? 1) - 1]) \(c.year! + 543)"
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
                    CalendarDayItemsCard(
                        title: selectedDayTitle,
                        isToday: cal.isDateInToday(selectedDate),
                        items: itemsForSelectedDate,
                        onSelect: openItem
                    )
                }
            }
            .scrollDisabled(ghostPayload != nil)
        } else {
            CalendarSearchView(
                searchText: searchText,
                results: searchResults,
                calendar: cal,
                onSelect: jumpToSearchResult
            )
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

    private func openItem(_ item: CalendarItem) {
        if let event = item.sourceEvent {
            activeSheet = .edit(event)
        } else if let task = item.sourceTask {
            activeSheet = .editTask(task)
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
            CalendarDayHeaderRow()
            CalendarMonthSection(
                days: calendarDays,
                selectedDate: selectedDate,
                calendar: cal,
                itemsFor: itemsFor,
                isBeingDragged: isBeingDragged,
                onSelectDay: { selectedDate = $0 }
            )
            .coordinateSpace(name: "monthGrid")
            .onGeometryChange(for: CGSize.self, of: { $0.size }) { gridSize = $0 }
            .simultaneousGesture(ghostGesture)
            .overlay(ghostOverlay)
            .padding(.horizontal, 6)
            .padding(.bottom, 10)
        }
        .background(Theme.Colors.cardBackground)
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
    }

    private func advanceMonth(by delta: Int) {
        guard let d = cal.date(byAdding: .month, value: delta, to: currentMonth) else { return }
        withAnimation(.spring(response: 0.40, dampingFraction: 0.85)) {
            currentMonth = d
        }
    }

    // ── Search ───────────────────────────────────────────

    private var searchResults: [CalendarItem] {
        CalendarItemBuilder.searchResults(
            query: searchText,
            events: allEvents,
            tasks: allAssignments.inTerm(activeTerm),
            color: subjectColor
        )
    }

    private func jumpToSearchResult(_ item: CalendarItem) {
        searchText = ""
        currentMonth = item.date
        selectedDate = item.date
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
