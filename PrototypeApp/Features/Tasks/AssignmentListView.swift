//
//  AssignmentListView.swift
//  หน้า "งาน / การบ้าน" — การบ้านและงานส่วนตัวรวมกันในรายการเดียว
//  ประกอบจาก TaskFilterChips · TaskStatsRow · TaskRowCard · TaskFilterSheet
//
//  Uses List (not ScrollView) so swipe-to-delete works; separators and row
//  backgrounds are hidden so the rows still read as floating cards.
//

import SwiftUI
import SwiftData

struct AssignmentListView: View {
    @Query private var assignments: [Assignment]
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Environment(\.modelContext) private var context

    @State private var scope: TaskScope = .all
    @State private var searchText = ""
    @State private var kindFilter: TaskKindFilter = .all
    @State private var subjectFilter = ""
    @State private var overdueOnly = false
    @State private var sortOrder: TaskSortOrder = .dueDate

    @State private var showFilterSheet = false
    @State private var showAddTask = false
    @State private var editingTask: Assignment?
    @State private var isDoneGroupExpanded = false

    var body: some View {
        List {
            controlsSection
            if !dueSoonHighlights.isEmpty { dueSoonSection }
            mainSection
            if !doneTasks.isEmpty { doneSection }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("งาน / การบ้าน")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "ค้นหางาน วิชา หรือรายละเอียด")
        .overlay(alignment: .bottomTrailing) { addButton }
        .overlay { emptyState }
        .sheet(isPresented: $showFilterSheet) {
            TaskFilterSheet(
                kindFilter: $kindFilter,
                subjectFilter: $subjectFilter,
                overdueOnly: $overdueOnly,
                sortOrder: $sortOrder
            )
        }
        .sheet(isPresented: $showAddTask) { AddTaskSheet() }
        .sheet(item: $editingTask) { task in AddTaskSheet(editing: task) }
    }

    // MARK: - Sections

    private var controlsSection: some View {
        Section {
            TaskFilterChips(
                selection: $scope,
                hasActiveFilters: hasActiveFilters,
                onOpenFilters: { showFilterSheet = true }
            )
            .plainRow()

            TaskStatsRow(counts: counts, onSelect: select(stat:))
                .plainRow()
                .padding(.bottom, Theme.Spacing.sm)
        }
    }

    private var dueSoonSection: some View {
        Section {
            ForEach(dueSoonHighlights) { task in
                row(for: task)
            }
        } header: {
            sectionHeader(title: TaskScope.dueSoon.label) {
                Button("ดูทั้งหมด ›") { scope = .dueSoon }
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.primary)
            }
        }
    }

    private var mainSection: some View {
        Section {
            ForEach(visibleTasks) { task in
                row(for: task)
            }
        } header: {
            sectionHeader(title: scope == .all ? "รายการทั้งหมด" : scope.label) {
                Button {
                    showFilterSheet = true
                } label: {
                    Text("เรียงตาม: \(sortOrder.label) ↓")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
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
                    .font(.subheadline)
                    .fontWeight(.semibold)
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

    private func sectionHeader<Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.background)
        .listRowInsets(EdgeInsets())
    }

    private var addButton: some View {
        Button {
            showAddTask = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.primary)
                .clipShape(Circle())
                .shadow(color: Theme.Colors.primary.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.xl)
        .accessibilityLabel("เพิ่มงาน")
    }

    @ViewBuilder
    private var emptyState: some View {
        if assignments.isEmpty {
            ContentUnavailableView(
                "ยังไม่มีงาน",
                systemImage: "checkmark.square",
                description: Text("กดปุ่ม + มุมขวาล่างเพื่อเพิ่มงานชิ้นแรก")
            )
        } else if visibleTasks.isEmpty && dueSoonHighlights.isEmpty && doneTasks.isEmpty {
            ContentUnavailableView(
                "ไม่พบงานที่ตรงเงื่อนไข",
                systemImage: "line.3.horizontal.decrease",
                description: Text("ลองเปลี่ยนตัวกรองหรือคำค้นหา")
            )
        }
    }

    // MARK: - Data

    /// Filters that apply on top of the selected chip.
    private func passesSecondaryFilters(_ task: Assignment) -> Bool {
        guard kindFilter.matches(task) else { return false }
        if !subjectFilter.isEmpty && task.subjectName != subjectFilter { return false }
        if overdueOnly && !task.isOverdue { return false }
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
        assignments.filter(passesSecondaryFilters)
    }

    /// The main list — chip applied. Finished tasks live in their own collapsed
    /// group unless the user explicitly picked the "เสร็จแล้ว" chip.
    private var visibleTasks: [Assignment] {
        let base = filteredPool.filter { scope.matches($0) }
        let withoutDone = scope == .done ? base : base.filter { !$0.isDone }
        return sorted(withoutDone)
    }

    private var doneTasks: [Assignment] {
        guard scope != .done else { return [] }
        return sorted(filteredPool.filter { $0.isDone })
    }

    /// Shown above the main list when the user hasn't narrowed to a specific chip.
    private var dueSoonHighlights: [Assignment] {
        guard scope == .all || scope == .notDone else { return [] }
        return sorted(filteredPool.filter { TaskScope.dueSoon.matches($0) })
    }

    private var counts: [TaskScope: Int] {
        var result: [TaskScope: Int] = [:]
        for stat in TaskScope.stats {
            result[stat] = assignments.filter { stat.matches($0) }.count
        }
        return result
    }

    private var hasActiveFilters: Bool {
        kindFilter != .all || !subjectFilter.isEmpty || overdueOnly || sortOrder != .dueDate
    }

    private func subject(named name: String) -> Subject? {
        guard !name.isEmpty else { return nil }
        return subjects.first { $0.name == name }
    }

    /// Tasks with no due date always sort last, whichever order is picked.
    private func sorted(_ tasks: [Assignment]) -> [Assignment] {
        tasks.sorted { lhs, rhs in
            switch (lhs.resolvedDueDate, rhs.resolvedDueDate) {
            case (nil, .some): return false
            case (.some, nil): return true
            default: break
            }

            switch sortOrder {
            case .dueDate:
                if let l = lhs.resolvedDueDate, let r = rhs.resolvedDueDate, l != r { return l < r }
            case .priority:
                let lp = rank(lhs.effectivePriority)
                let rp = rank(rhs.effectivePriority)
                if lp != rp { return lp > rp }
            case .recent:
                break
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func rank(_ priority: AssignmentPriority) -> Int {
        switch priority {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }

    // MARK: - Actions

    private func select(stat: TaskScope) {
        scope = stat.chipTarget
        overdueOnly = (stat == .overdue)
        if stat == .overdue { isDoneGroupExpanded = false }
    }

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
        .modelContainer(for: [Assignment.self, Subject.self], inMemory: true)
}
