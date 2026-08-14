//
//  TaskFilterMenu.swift
//  The toolbar's filter menu — ประเภท + วิชา. Replaces the old TaskFilterSheet:
//  two pickers never justified a whole sheet.
//
//  Split out of AssignmentListView to keep that file under the ~250-line mark;
//  the List's own sections stay in place there so swipe-to-delete is untouched.
//

import SwiftUI

struct TaskFilterMenu: View {
    @Binding var kindFilter: TaskKindFilter
    @Binding var subjectFilter: String
    /// Subject names present in the current term, already sorted.
    let subjectNames: [String]

    private var hasActiveFilters: Bool {
        kindFilter != .all || !subjectFilter.isEmpty
    }

    var body: some View {
        Menu {
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
        } label: {
            Image(systemName: hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("กรองงาน")
    }
}
