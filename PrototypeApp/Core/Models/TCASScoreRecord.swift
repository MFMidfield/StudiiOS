//
//  TCASScoreRecord.swift
//  คะแนนสอบของผู้ใช้ — ชุดเดียวใช้ร่วมทุกคณะ ไม่ผูก relationship กับ TCASEntry.
//  ค้นด้วย examCode: คะแนน TGAT ของผู้ใช้มีชุดเดียว แก้ที่เดียวอัปทุกคณะ.
//

import Foundation
import SwiftData

@Model
final class TCASScoreRecord {
    var examCode: String
    var score: Double
    var hasTaken: Bool = false
    var takenAt: Date = Date.now

    init(
        examCode: String,
        score: Double,
        hasTaken: Bool = false,
        takenAt: Date = .now
    ) {
        self.examCode = examCode
        self.score = score
        self.hasTaken = hasTaken
        self.takenAt = takenAt
    }
}
