//
//  SOPTarget.swift
//  คณะที่ตั้งใจยื่น 1 แห่ง — มหาวิทยาลัย · คณะ · สาขา และ SOP ของที่นั่น
//
//  แทนที่ `TCASEntry` เดิม (16 ส.ค. 2569): ระบบคิดคะแนน TCAS ทั้งชุดถูกตัดออก
//  (`TCASScoreWeight` · `TCASScoreRecord` · `TCASScoreEngine` · `TCASExamCatalog`)
//  เหลือแค่ "ที่ที่จะยื่น + เรียงความ SOP" เท่านั้น
//

import Foundation
import SwiftData

@Model
final class SOPTarget {
    var universityName: String
    var facultyName: String
    var majorName: String
    var sortOrder: Int
    var createdAt: Date

    // SwiftData ยังงอแงกับ to-one optional relationship — เก็บเป็น array
    // แล้วเปิด `sop` เป็น computed property แทน (มีได้ 0 หรือ 1 ตัวเท่านั้น)
    @Relationship(deleteRule: .cascade, inverse: \SOPDocument.target)
    var sopStore: [SOPDocument] = []

    var sop: SOPDocument? { sopStore.first }

    /// "คณะวิศวกรรมศาสตร์ · คอมพิวเตอร์" — สาขาว่างก็เหลือแค่ชื่อคณะ
    var facultyLine: String {
        [facultyName, majorName].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    init(
        universityName: String,
        facultyName: String,
        majorName: String = "",
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.universityName = universityName
        self.facultyName = facultyName
        self.majorName = majorName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
