//
//  ScheduleView.swift
//  ตารางเรียน — weekly timetable (Monday–Friday). Shows one day's periods at a
//  time via ScheduleDayPickerBar, with add/edit handled by AddScheduleEntrySheet
//  and an optional per-day period-shift override.
//
//  Toolbar: ⚙︎ on the left holds the occasional jobs (ร่นคาบ · เปลี่ยนเทอม ·
//  จัดการเทอม) — they used to sit behind a sheet that existed only to hold three
//  rows. ＋ on the right adds a period; the tab bar's ＋ opens the app-wide
//  quick-add menu, which deliberately does not offer class periods.
//
//  งาน/การบ้านของวันนั้นไม่อยู่ในหน้านี้แล้ว — แท็บ "งาน" จัดกลุ่มตามวันให้อยู่แล้ว
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var context

    @Query private var allEntries: [ScheduleEntry]
    @Query private var overrides: [DayScheduleOverride]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    @State private var selectedDay: Int = ScheduleConstants.defaultEntryDay
    @State private var editingEntry: ScheduleEntry?
    @State private var isAddingEntry = false
    @State private var isShiftingPeriods = false
    @State private var isManagingTerms = false

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
                }
                .padding(Theme.Spacing.md)
            }
        }
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { titleBlock }
            ToolbarItem(placement: .topBarLeading) { settingsMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingEntry = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("เพิ่มคาบเรียน")
            }
        }
        .navigationDestination(isPresented: $isManagingTerms) {
            TermManagementView()
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
        .sheet(isPresented: $isShiftingPeriods) {
            PeriodShiftSheet(
                day: selectedDay,
                dayEntries: entriesForSelectedDay,
                targetDate: targetDate,
                existing: matchingOverride
            )
        }
    }

    // MARK: - Toolbar

    private var titleBlock: some View {
        VStack(spacing: 2) {
            Text("ตารางเรียน")
                .font(Theme.Font.plex(15, .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            if let activeTerm {
                Text(activeTerm.displayName)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var settingsMenu: some View {
        Menu {
            Button("ร่นคาบวันนี้", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                isShiftingPeriods = true
            }

            // Renders as a submenu with a checkmark on the active term.
            Picker("เปลี่ยนเทอม", selection: termSelection) {
                ForEach(SchoolBand.upper.gradeLevels, id: \.self) { level in
                    ForEach([1, 2], id: \.self) { termNumber in
                        let count = entryCount(gradeLevel: level, termNumber: termNumber)
                        Text(count > 0 ? "ม.\(level) เทอม \(termNumber) (\(count) คาบ)" : "ม.\(level) เทอม \(termNumber)")
                            .tag(Int?(level * 10 + termNumber))
                    }
                }
            }

            Divider()

            // A Button + navigationDestination rather than a NavigationLink:
            // links inside a Menu do not reliably push from a toolbar item.
            Button("จัดการเทอมทั้งหมด", systemImage: "list.bullet.rectangle") {
                isManagingTerms = true
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("ตั้งค่าตารางเรียน")
    }

    // MARK: - Term switching
    //
    // Lifted wholesale out of the deleted ScheduleSettingsSheet — it drives
    // TermStore, which this module must not rewrite.

    /// nil เมื่อเทอมที่ใช้อยู่ไม่ได้อยู่ในเมนูนี้ (เช่น เทอม ม.ต้น ที่เคยสร้างไว้ก่อนหน้า)
    /// — เมนูจะไม่มี tag ตรงกับมัน ต้องคืน nil ให้ Picker แสดง "ยังไม่เลือก"
    /// แทนที่จะยัดค่าเก่าที่ไม่มีอยู่ในเมนูเข้าไป
    private var termSelection: Binding<Int?> {
        Binding(
            get: {
                guard let activeTerm, SchoolBand.upper.gradeLevels.contains(activeTerm.gradeLevel) else { return nil }
                return activeTerm.sortKey
            },
            set: { newSortKey in
                guard let newSortKey else { return }
                let gradeLevel = newSortKey / 10
                let termNumber = newSortKey % 10
                let term = TermStore.findOrCreate(gradeLevel: gradeLevel, termNumber: termNumber, in: context)
                TermStore.setActive(term)
                TermStore.syncTermSubjects(for: term, in: context)
                try? context.save()
            }
        )
    }

    private func entryCount(gradeLevel: Int, termNumber: Int) -> Int {
        guard let term = terms.first(where: { $0.gradeLevel == gradeLevel && $0.termNumber == termNumber }) else {
            return 0
        }
        return allEntries.filter { $0.term?.id == term.id }.count
    }

    // MARK: - Empty state

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
    let math = Subject(name: "คณิตศาสตร์เพิ่มเติม ม.5", colorHex: "C96F4A", iconName: "function")
    let physics = Subject(name: "ฟิสิกส์", code: "ว31201", colorHex: "4CAF50", iconName: "atom")
    let lunch = Subject(name: "พักกลางวัน", colorHex: "FFB347", iconName: "fork.knife", isBreak: true, isBuiltIn: true)
    [math, physics, lunch].forEach { container.mainContext.insert($0) }

    let day = ScheduleConstants.defaultEntryDay
    let entries = [
        ScheduleEntry(dayOfWeek: day, startMinute: 480, endMinute: 530, periodNumber: 1, teacherName: "ครูณัฐวุฒิ อินทร์แก้ว", location: "5201", subjectName: math.name, subject: math),
        ScheduleEntry(dayOfWeek: day, startMinute: 540, endMinute: 590, periodNumber: 2, teacherName: "ครูพีรพล โชคชัย", location: "5304", subjectName: physics.name, subject: physics),
        ScheduleEntry(dayOfWeek: day, startMinute: 720, endMinute: 780, periodNumber: 0, subjectName: lunch.name, subject: lunch),
    ]
    entries.forEach { container.mainContext.insert($0) }

    return NavigationStack { ScheduleView() }
        .modelContainer(container)
}
