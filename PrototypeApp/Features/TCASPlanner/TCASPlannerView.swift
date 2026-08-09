//
//  TCASPlannerView.swift
//  TCAS Planner (Free feature): บันทึกคณะ/มหาวิทยาลัยที่สนใจ + ระบบคิดคะแนนย้อนกลับ
//  + SOP ต่อคณะ (SOP ยังไม่ทำ — รอ "รอบ D") ทุกจุดคะแนน/เกณฑ์การรับจริงเปิด mytcas.com
//  แทนเก็บเอง (§0.3 กฎเหล็ก) — ดู PLAN_TCASPlanner.md
//

import SwiftUI
import SwiftData

struct TCASPlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TCASEntry.sortOrder) private var entries: [TCASEntry]
    @State private var isPresentingNew = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    MyScoresView()
                } label: {
                    Label("คะแนนสอบของฉัน", systemImage: "chart.bar.doc.horizontal")
                }
            }

            Section("คณะเป้าหมาย") {
                ForEach(entries) { entry in
                    NavigationLink {
                        TCASEntryDetailView(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.facultyName) — \(entry.universityName)")
                                .font(.system(size: 14, weight: .medium))
                            Text(entry.roundRaw)
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(entries[i]) }
                }

                Button {
                    isPresentingNew = true
                } label: {
                    Label("เพิ่มคณะเป้าหมาย", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("TCAS Planner")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingNew) {
            NewTCASEntrySheet()
        }
    }
}

#Preview {
    NavigationStack { TCASPlannerView() }
        .modelContainer(for: [TCASEntry.self, TCASScoreWeight.self, TCASScoreRecord.self, TCASSOP.self], inMemory: true)
}
