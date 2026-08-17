//
//  TaskAddMenu.swift
//  The Todo screen's only toolbar item: tap "+" to add a task, press and hold
//  for the type/subject filters.
//
//  Replaces both the old FAB and the old TaskFilterSheet — two pickers never
//  justified a whole sheet, and two "add" buttons on one screen (FAB + tab bar)
//  never justified themselves either.
//
//  Split out of AssignmentListView to keep that file under the ~250-line mark;
//  the List's own sections stay there so swipe-to-delete is untouched.
//

import SwiftUI

struct TaskAddMenu: View {
    @Binding var kindFilter: TaskKindFilter
    @Binding var subjectFilter: String
    /// Subject names present in the current term, already sorted.
    let subjectNames: [String]
    let onAdd: () -> Void

    private var hasActiveFilters: Bool {
        kindFilter != .all || !subjectFilter.isEmpty
    }

    var body: some View {
        Menu {
            Button("เพิ่มงาน", systemImage: "plus") { onAdd() }

            Section("ตัวกรอง") {
                Picker("ประเภท", selection: $kindFilter) {
                    ForEach(TaskKindFilter.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }

                Picker("วิชา", selection: $subjectFilter) {
                    Text("ทุกวิชา").tag("")
                    ForEach(subjectNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                if hasActiveFilters {
                    Button("ล้างตัวกรอง", role: .destructive) {
                        kindFilter = .all
                        subjectFilter = ""
                    }
                }
            }
        } label: {
            label
        } primaryAction: {
            onAdd()
        }
        .accessibilityLabel("เพิ่มงาน")
        .accessibilityHint("กดค้างเพื่อกรองตามประเภทหรือวิชา")
    }

    /// A dot on the "+" is the only sign a filter is on — without it the user
    /// can hide half the list behind a long-press menu and never find out why.
    private var label: some View {
        Image(systemName: "plus")
            .overlay(alignment: .topTrailing) {
                if hasActiveFilters {
                    Circle()
                        .fill(Theme.Colors.primary)
                        .frame(width: 6, height: 6)
                        .offset(x: 5, y: -4)
                }
            }
    }
}
