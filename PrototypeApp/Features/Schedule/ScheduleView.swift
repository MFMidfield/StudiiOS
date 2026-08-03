//
//  ScheduleView.swift
//  ตารางเรียน — weekly timetable (Monday–Friday). Shows one day's periods
//  at a time via ScheduleDayPickerBar, with add/edit handled by
//  AddScheduleEntrySheet, an optional per-day period-shift override, and
//  a card listing assignments due that day.
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Query private var allEntries: [ScheduleEntry]
    @Query private var overrides: [DayScheduleOverride]

    @State private var selectedDay: Int
    @State private var editingEntry: ScheduleEntry?
    @State private var isAddingEntry = false
    @State private var isShiftingPeriods = false

    init() {
        let raw = Calendar.current.component(.weekday, from: .now) // 1=Sun...7=Sat
        let mapped = raw == 1 ? 7 : raw - 1 // 1=Mon...7=Sun
        _selectedDay = State(initialValue: ScheduleConstants.visibleDays.contains(mapped) ? mapped : 1)
    }

    private var entriesForSelectedDay: [ScheduleEntry] {
        allEntries
            .filter { $0.dayOfWeek == selectedDay }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private var targetDate: Date {
        PeriodShiftCalculator.date(forDay: selectedDay, in: .now)
    }

    private var matchingOverride: DayScheduleOverride? {
        let normalized = DayScheduleOverride.normalizedDate(targetDate)
        return overrides.first { $0.date == normalized }
    }

    private var resolvedPeriods: [ResolvedPeriod] {
        PeriodShiftCalculator.apply(override: matchingOverride, to: entriesForSelectedDay)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScheduleDayPickerBar(selectedDay: $selectedDay)

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let matchingOverride {
                        PeriodShiftBanner(override: matchingOverride)
                    }

                    if entriesForSelectedDay.isEmpty {
                        emptyState
                    } else {
                        ScheduleTimetableSection(
                            day: selectedDay,
                            periods: resolvedPeriods,
                            onTapEntry: { editingEntry = $0 }
                        )
                    }

                    ScheduleTodayTasksSection(selectedDay: selectedDay, targetDate: targetDate)
                }
                .padding(Theme.Spacing.md)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("ตารางเรียน")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isShiftingPeriods = true
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }

                Button {
                    isAddingEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingEntry) {
            AddScheduleEntrySheet(editing: nil, defaultDay: selectedDay)
        }
        .sheet(item: $editingEntry) { entry in
            AddScheduleEntrySheet(editing: entry, defaultDay: selectedDay)
        }
        .sheet(isPresented: $isShiftingPeriods) {
            PeriodShiftSheet(
                day: selectedDay,
                dayEntries: entriesForSelectedDay,
                targetDate: targetDate,
                existing: matchingOverride
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("ยังไม่มีคาบเรียนในวัน\(ScheduleConstants.dayLabelsFull[selectedDay] ?? "")", systemImage: "calendar.badge.plus")
        } actions: {
            Button {
                isAddingEntry = true
            } label: {
                Label("เพิ่มคาบเรียน", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.primary)
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Subject.self, ScheduleEntry.self, DayScheduleOverride.self, Assignment.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let math = Subject(name: "คณิตศาสตร์เพิ่มเติม ม.5", colorHex: "4A7DFF", iconName: "function")
    let physics = Subject(name: "ฟิสิกส์", code: "ว31201", colorHex: "4CAF50", iconName: "atom")
    let lunch = Subject(name: "พักกลางวัน", colorHex: "FFB347", iconName: "fork.knife", isBreak: true, isBuiltIn: true)
    [math, physics, lunch].forEach { container.mainContext.insert($0) }

    let today = Calendar.current.component(.weekday, from: .now)
    let day = today == 1 ? 7 : today - 1
    let entries = [
        ScheduleEntry(dayOfWeek: day, startMinute: 480, endMinute: 530, periodNumber: 1, teacherName: "ครูณัฐวุฒิ อินทร์แก้ว", location: "5201", subjectName: math.name, subject: math),
        ScheduleEntry(dayOfWeek: day, startMinute: 540, endMinute: 590, periodNumber: 2, teacherName: "ครูพีรพล โชคชัย", location: "5304", subjectName: physics.name, subject: physics),
        ScheduleEntry(dayOfWeek: day, startMinute: 720, endMinute: 780, periodNumber: 0, subjectName: lunch.name, subject: lunch),
    ]
    entries.forEach { container.mainContext.insert($0) }

    let task = Assignment(title: "แบบฝึกหัด 2.1 ข้อ 1-20", dueDate: .now, subjectName: math.name)
    container.mainContext.insert(task)

    return NavigationStack { ScheduleView() }
        .modelContainer(container)
}
