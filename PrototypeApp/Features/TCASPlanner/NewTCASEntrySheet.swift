//
//  NewTCASEntrySheet.swift
//  กรอกคณะ/มหาลัย/รอบ → บันทึก → ต่อด้วยหน้าตั้งน้ำหนักทันที (มีปุ่ม "ข้ามก่อน") ตาม §7.1
//

import SwiftUI
import SwiftData

struct NewTCASEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var entries: [TCASEntry]

    @State private var faculty = ""
    @State private var university = ""
    @State private var round = "รอบ 1"
    @State private var createdEntry: TCASEntry?
    @State private var showWeightSetup = false

    private let rounds = ["รอบ 1", "รอบ 2", "รอบ 3", "รอบ 4"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("คณะ", text: $faculty)
                TextField("มหาวิทยาลัย", text: $university)
                Picker("รอบที่ตั้งใจยื่น", selection: $round) {
                    ForEach(rounds, id: \.self) { Text($0).tag($0) }
                }
            }
            .navigationTitle("เพิ่มคณะเป้าหมาย")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("ยกเลิก") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") { save() }
                        .disabled(faculty.isEmpty || university.isEmpty)
                }
            }
            .navigationDestination(isPresented: $showWeightSetup) {
                if let createdEntry {
                    TCASWeightSetupView(entry: createdEntry, showsSkipButton: true) { dismiss() }
                }
            }
        }
    }

    private func save() {
        let entry = TCASEntry(facultyName: faculty, universityName: university)
        entry.roundRaw = round
        entry.sortOrder = entries.count
        context.insert(entry)
        createdEntry = entry
        showWeightSetup = true
    }
}
