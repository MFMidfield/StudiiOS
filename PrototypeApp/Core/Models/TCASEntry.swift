//
//  TCASEntry.swift
//  TCAS Planner (Free feature): faculties/universities of interest, ระบบ
//  คิดคะแนนย้อนกลับ (TCASScoreWeight) และ SOP (TCASSOP) ต่อคณะ.
//

import Foundation
import SwiftData

@Model
final class TCASEntry {
    var facultyName: String
    var universityName: String
    var notes: String
    var createdAt: Date

    var roundRaw: String = "รอบ 1"
    var sortOrder: Int = 0
    var targetScore: Double = 0
    var admissionURL: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TCASScoreWeight.entry)
    var weights: [TCASScoreWeight] = []

    // SwiftData ยังงอแงกับ to-one optional relationship — เก็บเป็น array
    // แล้วเปิด `sop` เป็น computed property แทน (มีได้ 0 หรือ 1 ตัวเท่านั้น)
    @Relationship(deleteRule: .cascade, inverse: \TCASSOP.entry)
    var sopStore: [TCASSOP] = []

    var sop: TCASSOP? { sopStore.first }

    init(
        facultyName: String,
        universityName: String,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.facultyName = facultyName
        self.universityName = universityName
        self.notes = notes
        self.createdAt = createdAt
    }
}
