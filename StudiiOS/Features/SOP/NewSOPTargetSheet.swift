//
//  NewSOPTargetSheet.swift
//  เพิ่มคณะที่ตั้งใจยื่น — มหาวิทยาลัย · คณะ · สาขา
//
//  แทนที่ `NewTCASEntrySheet` (16 ส.ค. 2569): ตัด "รอบที่ตั้งใจยื่น" ออก และ
//  **บันทึกแล้วปิด sheet กลับหน้าลิสต์เลย** ไม่พาไปหน้าตั้งน้ำหนักคะแนนต่อ (ไม่มีแล้ว)
//

import SwiftUI
import SwiftData

struct NewSOPTargetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var targets: [SOPTarget]

    @State private var university = ""
    @State private var faculty = ""
    @State private var major = ""

    private var canSave: Bool {
        !university.trimmingCharacters(in: .whitespaces).isEmpty
            && !faculty.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("มหาวิทยาลัย", text: $university)
                    TextField("คณะ", text: $faculty)
                    TextField("สาขา (ไม่บังคับ)", text: $major)
                } footer: {
                    Text("ใส่ได้หลายที่ — เขียน SOP แยกกันได้ทีละที่")
                }
            }
            .themedFormBackground()
            .navigationTitle("เพิ่มคณะที่อยากยื่น")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let target = SOPTarget(
            universityName: university.trimmingCharacters(in: .whitespaces),
            facultyName: faculty.trimmingCharacters(in: .whitespaces),
            majorName: major.trimmingCharacters(in: .whitespaces),
            sortOrder: targets.count
        )
        context.insert(target)
        try? context.save()
        AppLog.action("SOP", "เพิ่มคณะ: \(target.universityName) · \(target.facultyLine)")
        dismiss()
    }
}

#Preview {
    NewSOPTargetSheet()
        .modelContainer(for: [SOPTarget.self, SOPDocument.self], inMemory: true)
}
