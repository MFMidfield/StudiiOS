//
//  TCASPlannerView.swift
//  TCAS Planner: บันทึกคณะ/มหาวิทยาลัยที่สนใจ, readiness checklist,
//  roadmap ม.4–ม.6. Free feature.
//

import SwiftUI
import SwiftData

struct TCASPlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TCASEntry.createdAt) private var entries: [TCASEntry]
    @State private var isPresentingNew = false

    var body: some View {
        unlockedContent
            .navigationTitle("TCAS Planner")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var unlockedContent: some View {
        List {
            Section("Roadmap ม.4–ม.6") {
                RoadmapRow(grade: "ม.4", tasks: "สำรวจความสนใจ / เริ่มสะสม Portfolio")
                RoadmapRow(grade: "ม.5", tasks: "เลือกคณะเป้าหมาย / เตรียมสอบวัดระดับ")
                RoadmapRow(grade: "ม.6", tasks: "ยื่น TCAS รอบต่างๆ / เตรียมสัมภาษณ์")
            }
            Section("คณะ/มหาวิทยาลัยที่สนใจ") {
                ForEach(entries) { entry in
                    NavigationLink {
                        TCASEntryDetailView(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(entry.facultyName) — \(entry.universityName)")
                                .font(.system(size: 14, weight: .medium))
                            ProgressView(value: entry.readinessPercent)
                                .tint(Theme.Colors.primary)
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(entries[i]) }
                }
            }
        }
        .overlay { if entries.isEmpty { ContentUnavailableView("ยังไม่มีคณะที่บันทึก", systemImage: "target") } }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isPresentingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            NewTCASEntrySheet()
        }
    }
}

private struct RoadmapRow: View {
    let grade: String
    let tasks: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(grade).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.info).frame(width: 40, alignment: .leading)
            Text(tasks).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct NewTCASEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var faculty = ""
    @State private var university = ""

    private let defaultChecklist = ["ตรวจสอบเกณฑ์การรับสมัคร", "เตรียมคะแนนสอบที่ต้องใช้", "เตรียม Portfolio", "ซ้อมสัมภาษณ์"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("คณะ", text: $faculty)
                TextField("มหาวิทยาลัย", text: $university)
            }
            .navigationTitle("เพิ่มคณะ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ยกเลิก") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let entry = TCASEntry(facultyName: faculty, universityName: university)
                        context.insert(entry)
                        for item in defaultChecklist {
                            context.insert(TCASChecklistItem(title: item, entry: entry))
                        }
                        dismiss()
                    }
                    .disabled(faculty.isEmpty || university.isEmpty)
                }
            }
        }
    }
}

private struct TCASEntryDetailView: View {
    @Bindable var entry: TCASEntry

    var body: some View {
        List {
            Section("เช็กลิสต์การเตรียมตัว") {
                ForEach(entry.checklist) { item in
                    ChecklistRow(item: item)
                }
            }
            Section("โน้ต") {
                TextEditor(text: $entry.notes).frame(minHeight: 100)
            }
        }
        .navigationTitle("\(entry.facultyName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChecklistRow: View {
    @Bindable var item: TCASChecklistItem
    var body: some View {
        Button {
            item.isDone.toggle()
        } label: {
            HStack {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? Theme.Colors.success : .secondary)
                Text(item.title).strikethrough(item.isDone)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { TCASPlannerView() }
        .modelContainer(for: [TCASEntry.self, TCASChecklistItem.self], inMemory: true)
}
