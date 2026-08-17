//
//  TaskSearchSheet.swift
//  หน้าค้นหางาน — เปิดจากปุ่มแว่นขยายข้างปุ่ม + ของ AssignmentListView
//
//  แยกเป็น sheet ด้วยเหตุผลเดียวกับ CalendarSearchSheet: `.searchable` ที่แปะบน
//  หน้าในแท็บจะไปโผล่เป็นแท็บค้นหาที่แถบล่างบน iOS 26
//
//  ค้นจากงานทั้งเทอม — ไม่สนชิปตัวกรอง/วิชาที่เลือกค้างไว้ในหน้าหลัก
//

import SwiftUI

struct TaskSearchSheet: View {
    let tasks: [Assignment]
    let subjectFor: (String) -> Subject?
    let onToggleDone: (Assignment) -> Void

    @State private var query = ""
    /// แก้งานจากในหน้าค้นหาเลย — ถ้าปิด sheet นี้แล้วค่อยให้หน้าหลักเปิดฟอร์ม
    /// จะกลายเป็นสั่งเปิด sheet ใหม่ตอนตัวเก่ายังปิดไม่เสร็จ (ฟอร์มไม่ขึ้น)
    @State private var editingTask: Assignment?
    @Environment(\.dismiss) private var dismiss

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Assignment] {
        let needle = trimmedQuery
        guard !needle.isEmpty else { return [] }
        let matching = tasks.filter { task in
            [task.title, task.detail, task.subjectName].contains {
                $0.localizedCaseInsensitiveContains(needle)
            }
        }
        return matching.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        NavigationStack {
            content
                .background(Theme.Colors.background)
                .navigationTitle("ค้นหางาน")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "ค้นหางาน วิชา หรือรายละเอียด"
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("ปิด") { dismiss() }
                    }
                }
                .sheet(item: $editingTask) { task in
                    AddTaskSheet(editing: task)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if trimmedQuery.isEmpty {
            ContentUnavailableView(
                "ค้นหางาน",
                systemImage: "magnifyingglass",
                description: Text("พิมพ์ชื่องาน ชื่อวิชา หรือรายละเอียดที่จำได้")
            )
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(results) { task in
                        TaskRowCard(
                            assignment: task,
                            subject: subjectFor(task.subjectName),
                            onToggleDone: { onToggleDone(task) },
                            onTap: { editingTask = task }
                        )
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }
}
