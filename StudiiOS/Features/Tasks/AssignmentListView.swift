//
//  AssignmentListView.swift
//  หน้า "งาน / การบ้าน" — การบ้านและงานส่วนตัวรวมกันในรายการเดียว
//  ประกอบจาก TaskFilterChips · TaskRowCard · หัวข้อกลุ่มตามวัน (TaskDayGroup)
//
//  Uses List (not ScrollView) so swipe-to-delete works; separators and row
//  backgrounds are hidden so the rows still read as floating cards.
//
//  เพิ่มงาน = ปุ่ม + มุมขวาบน (TaskAddMenu) — ไม่มี FAB มุมขวาล่างแล้ว
//

import SwiftUI
import SwiftData

struct AssignmentListView: View {
    @Query private var assignments: [Assignment]
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Environment(\.modelContext) private var context

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }
    private var scopedAssignments: [Assignment] { assignments.inTerm(activeTerm) }

    /// เปิดหน้ามาเห็นงานที่ยังไม่เสร็จก่อน — ไม่ใช่กองรวมทุกใบ
    @State private var scope: TaskScope = .notDone
    @State private var searchText = ""
    @State private var kindFilter: TaskKindFilter = .all
    @State private var subjectFilter = ""

    @State private var editingTask: Assignment?
    @State private var isAddingTask = false
    @State private var isDoneGroupExpanded = false

    var body: some View {
        List {
            chipSection
            ForEach(dayGroups) { entry in
                Section {
                    ForEach(entry.tasks) { task in
                        row(for: task)
                    }
                } header: {
                    groupHeader(entry.group)
                }
            }
            if !doneTasks.isEmpty { doneSection }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("งาน / การบ้าน")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "ค้นหางาน วิชา หรือรายละเอียด")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TaskAddMenu(
                    kindFilter: $kindFilter,
                    subjectFilter: $subjectFilter,
                    subjectNames: subjectNames,
                    onAdd: { isAddingTask = true }
                )
            }
        }
        .overlay { emptyState }
        .sheet(isPresented: $isAddingTask) { AddTaskSheet() }
        .sheet(item: $editingTask) { task in AddTaskSheet(editing: task) }
    }

    // MARK: - Sections

    private var chipSection: some View {
        Section {
            TaskFilterChips(selection: $scope, counts: counts)
                .plainRow()
                .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private var doneSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isDoneGroupExpanded) {
                ForEach(doneTasks) { task in
                    row(for: task)
                        .padding(.top, Theme.Spacing.sm)
                }
            } label: {
                Text("เสร็จแล้ว (\(doneTasks.count))")
                    .font(Theme.Font.plex(13, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .plainRow()
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
        }
    }

    // MARK: - Row

    private func row(for task: Assignment) -> some View {
        TaskRowCard(
            assignment: task,
            subject: subject(named: task.subjectName),
            onToggleDone: { toggleDone(task) },
            onTap: { editingTask = task }
        )
        .plainRow()
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.md)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(task)
            } label: {
                Label("ลบ", systemImage: "trash")
            }
        }
    }

    /// Compact header — SectionHeader's 19pt is meant for card sections, and
    /// five of them stacked in a list would outweigh the rows themselves.
    private func groupHeader(_ group: TaskDayGroup) -> some View {
        Text(group.title())
            .font(Theme.Font.plex(13, .semibold))
            .foregroundStyle(group.isAlarming ? Theme.Colors.danger : Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
            .listRowInsets(EdgeInsets())
    }

    @ViewBuilder
    private var emptyState: some View {
        if scopedAssignments.isEmpty {
            ContentUnavailableView(
                "ยังไม่มีงาน",
                systemImage: "checkmark.square",
                description: Text("กดปุ่ม + มุมขวาบนเพื่อเพิ่มงานชิ้นแรก")
            )
        } else if visibleTasks.isEmpty && doneTasks.isEmpty {
            ContentUnavailableView(
                "ไม่พบงานที่ตรงเงื่อนไข",
                systemImage: "line.3.horizontal.decrease",
                description: Text("ลองเปลี่ยนคำค้นหา หรือกดค้างที่ปุ่ม + มุมขวาบนเพื่อล้างตัวกรอง")
            )
        }
    }

    // MARK: - Data

    /// Filters that apply on top of the selected chip.
    private func passesSecondaryFilters(_ task: Assignment) -> Bool {
        guard kindFilter.matches(task) else { return false }
        if !subjectFilter.isEmpty && task.subjectName != subjectFilter { return false }
        return matchesSearch(task)
    }

    private func matchesSearch(_ task: Assignment) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [task.title, task.detail, task.subjectName].contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    /// Everything matching the secondary filters, before the chip narrows it.
    private var filteredPool: [Assignment] {
        scopedAssignments.filter(passesSecondaryFilters)
    }

    /// The main list — chip applied. Finished tasks live in their own collapsed
    /// group unless the user explicitly picked the "เสร็จ" chip.
    private var visibleTasks: [Assignment] {
        let base = filteredPool.filter { scope.matches($0) }
        let withoutDone = scope == .done ? base : base.filter { !$0.isDone }
        return sorted(withoutDone)
    }

    /// Day buckets in `TaskDayGroup.allCases` order, empty ones dropped.
    private var dayGroups: [TaskDaySection] {
        let tasks = visibleTasks
        return TaskDayGroup.allCases.compactMap { group in
            let matching = tasks.filter { TaskDayGroup.group(for: $0) == group }
            return matching.isEmpty ? nil : TaskDaySection(group: group, tasks: matching)
        }
    }

    private var doneTasks: [Assignment] {
        guard scope != .done else { return [] }
        return sorted(filteredPool.filter { $0.isDone })
    }

    private var counts: [TaskScope: Int] {
        var result: [TaskScope: Int] = [:]
        for chip in TaskScope.chips where chip.showsCount {
            result[chip] = scopedAssignments.filter { chip.matches($0) }.count
        }
        return result
    }

    private var subjectNames: [String] {
        Array(Set(scopedAssignments.map(\.subjectName).filter { !$0.isEmpty })).sorted()
    }

    private func subject(named name: String) -> Subject? {
        guard !name.isEmpty else { return nil }
        return subjects.first { $0.name == name }
    }

    /// กำหนดส่งใกล้สุดขึ้นก่อน · ไม่มีกำหนดไปท้ายสุด · เท่ากันแล้วเอาที่เพิ่งเพิ่ม
    private func sorted(_ tasks: [Assignment]) -> [Assignment] {
        tasks.sorted { lhs, rhs in
            switch (lhs.resolvedDueDate, rhs.resolvedDueDate) {
            case (nil, .some): return false
            case (.some, nil): return true
            case (.some(let l), .some(let r)) where l != r: return l < r
            default: return lhs.createdAt > rhs.createdAt
            }
        }
    }

    // MARK: - Actions

    private func toggleDone(_ task: Assignment) {
        task.isDone.toggle()
        try? context.save()
        // เสร็จแล้ว → schedule() จะยกเลิกให้เอง · กดกลับเป็นยังไม่เสร็จ → ตั้งใหม่
        Task { await NotificationManager.shared.schedule(for: task) }
        AppLog.action("Assignment", "\(task.isDone ? "ทำเสร็จ" : "ยกเลิกเสร็จ"): \(task.title)")
    }

    private func delete(_ task: Assignment) {
        let title = task.title
        NotificationManager.shared.cancel(for: task)
        context.delete(task)
        try? context.save()
        AppLog.action("Assignment", "ลบงาน: \(title)")
    }
}

// MARK: - Day section

/// One rendered day bucket. A plain tuple can't be used here — `ForEach` needs
/// an identity and Swift has no key paths into tuples.
private struct TaskDaySection: Identifiable {
    let group: TaskDayGroup
    let tasks: [Assignment]

    var id: String { group.rawValue }
}

// MARK: - Row styling helper

private extension View {
    /// Strips List's own chrome so a card can float on the page background.
    func plainRow() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }
}

#Preview {
    NavigationStack { AssignmentListView() }
        .modelContainer(for: [Assignment.self, Subject.self, Term.self, TermSubject.self], inMemory: true)
}
