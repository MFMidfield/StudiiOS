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

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    @State private var selectedDay: Int
    @State private var editingEntry: ScheduleEntry?
    @State private var isAddingEntry = false
    @State private var isShowingScheduleSettings = false

    init() {
        let raw = Calendar.current.component(.weekday, from: .now) // 1=Sun...7=Sat
        let mapped = raw == 1 ? 7 : raw - 1 // 1=Mon...7=Sun
        _selectedDay = State(initialValue: ScheduleConstants.visibleDays.contains(mapped) ? mapped : 1)
    }

    private var entriesForSelectedDay: [ScheduleEntry] {
        allEntries
            .inTerm(activeTerm)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("ตารางเรียน")
                        .font(.headline)
                    if let activeTerm {
                        Text(activeTerm.displayName)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isShowingScheduleSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }

                Button {
                    isAddingEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingEntry) {
            // Only add mode offers the photo import, so only this presentation
            // needs the "jump to the first imported day" callback.
            AddScheduleEntrySheet(editing: nil, defaultDay: selectedDay) { day in
                // The picker bar only holds จ–ศ, so a Saturday import must not
                // move the selection somewhere the bar cannot show.
                if ScheduleConstants.visibleDays.contains(day) { selectedDay = day }
            }
        }
        .sheet(item: $editingEntry) { entry in
            AddScheduleEntrySheet(editing: entry, defaultDay: selectedDay)
        }
        .sheet(isPresented: $isShowingScheduleSettings) {
            ScheduleSettingsSheet(
                day: selectedDay,
                dayEntries: entriesForSelectedDay,
                targetDate: targetDate,
                existingOverride: matchingOverride
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("ยังไม่มีคาบเรียนในวัน\(ScheduleConstants.dayLabelsFull[selectedDay] ?? "") (\(activeTerm?.displayName ?? ""))", systemImage: "calendar.badge.plus")
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
        Term.self, TermSubject.self,
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
