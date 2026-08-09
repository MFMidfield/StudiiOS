//
//  TCASScoreEngine.swift
//  สูตรคิดคะแนนย้อนกลับของ TCAS Planner — logic ล้วน ไม่ import SwiftUI/SwiftData
//  (เทียบเคียง GPAXCalculator.swift/RIASECScorer.swift) เทสต์ได้โดยไม่ต้องมี ModelContainer
//  รับ/คืนเป็น struct เปล่า (TCASWeightInput/TCASScoreInput) ไม่ใช่ @Model ตรงๆ — ผู้เรียก
//  (View ใน Features/TCASPlanner) มีหน้าที่แปลง TCASEntry.weights / TCASScoreRecord ก่อนเรียก.
//
//  คะแนนรวม = Σ (คะแนนดิบ ÷ คะแนนเต็ม × 100) × น้ำหนัก% ÷ 100
//  จุดที่คนพลาด: คะแนนเต็มไม่เท่ากัน (TPAT 300 · A-Level 100) ต้องแปลงเป็นสัดส่วนก่อนถ่วงน้ำหนัก
//

import Foundation

struct TCASWeightInput {
    let examCode: String
    let percent: Double       // น้ำหนักรายวิชา (0-100)
    let groupName: String     // "" = โหมดรายวิชา
    let groupPercent: Double  // ใช้เมื่อ groupName ไม่ว่าง

    init(examCode: String, percent: Double, groupName: String = "", groupPercent: Double = 0) {
        self.examCode = examCode
        self.percent = percent
        self.groupName = groupName
        self.groupPercent = groupPercent
    }
}

struct TCASScoreInput {
    let examCode: String
    let score: Double
    let hasTaken: Bool

    init(examCode: String, score: Double, hasTaken: Bool = false) {
        self.examCode = examCode
        self.score = score
        self.hasTaken = hasTaken
    }
}

/// วิชา 1 ตัวหลังผูกน้ำหนักเข้ากับคะแนนที่มี (หรือยังไม่มี) และคะแนนเต็มจาก `TCASExamCatalog`
struct TCASSubjectBreakdown: Identifiable {
    var id: String { examCode }
    let examCode: String
    let displayName: String
    let percent: Double
    let fullScore: Double
    let rawScore: Double?   // nil = ยังไม่ระบุ (ห้ามนับเป็น 0 — §4.4)
    let hasTaken: Bool

    /// 100 × น้ำหนัก(เศษส่วน) ÷ คะแนนเต็ม — ยิ่งสูงยิ่ง "คุ้ม" ต่อ 1 คะแนนดิบที่ทุ่มเพิ่ม
    var leverage: Double {
        guard fullScore > 0 else { return 0 }
        return percent / fullScore
    }

    /// ส่วนที่วิชานี้เติมให้คะแนนรวม ณ ตอนนี้ — nil ถ้ายังไม่ได้กรอกคะแนน
    var currentContribution: Double? {
        guard let rawScore, fullScore > 0 else { return nil }
        return (rawScore / fullScore) * percent
    }

    /// (เต็ม − ที่ได้) × leverage — ที่ยังทุ่มเพิ่มได้ถ้าวิชานี้ยังไม่ล็อก
    var headroom: Double {
        (fullScore - (rawScore ?? 0)) * leverage
    }
}

struct TCASRequiredAverageResult {
    let lockedContribution: Double
    let remainingPercent: Double
    /// อาจเกิน 100 ได้ (เป็นไปไม่ได้ต่อให้ได้เต็ม) — View เป็นคนตัดสินใจแสดงข้อความ/สี (§4.3)
    let requiredAveragePercent: Double
}

enum TCASScoreEngine {
    static func breakdown(weights: [TCASWeightInput], scores: [TCASScoreInput]) -> [TCASSubjectBreakdown] {
        weights.map { weight in
            let matched = scores.first { $0.examCode == weight.examCode }
            let exam = TCASExamCatalog.exam(code: weight.examCode)
            return TCASSubjectBreakdown(
                examCode: weight.examCode,
                displayName: exam?.displayName ?? weight.examCode,
                percent: weight.percent,
                fullScore: exam?.fullScore ?? 100,
                rawScore: matched?.score,
                hasTaken: matched?.hasTaken ?? false
            )
        }
    }

    /// รวม % ครบ 100 มั้ย — ไม่ครบแค่เตือน ไม่บล็อกการคำนวณอื่น (§4.4: บางคณะมีสัมภาษณ์/แฟ้มสะสมงานถ่วงด้วย)
    static func totalPercent(weights: [TCASWeightInput]) -> Double {
        weights.reduce(0) { $0 + $1.percent }
    }

    /// คะแนนรวมปัจจุบัน — วิชาที่ยังไม่กรอกคะแนนไม่นับ (ไม่ใช่นับเป็น 0)
    static func currentScore(weights: [TCASWeightInput], scores: [TCASScoreInput]) -> Double {
        breakdown(weights: weights, scores: scores).reduce(0) { $0 + ($1.currentContribution ?? 0) }
    }

    /// เพดานถ้าวิชาที่ยังไม่กรอกคะแนนได้เต็ม (วิชาที่กรอกแล้วคงคะแนนเดิม)
    static func ceilingScore(weights: [TCASWeightInput], scores: [TCASScoreInput]) -> Double {
        breakdown(weights: weights, scores: scores).reduce(0) { sum, subject in
            sum + (subject.currentContribution ?? subject.percent)
        }
    }

    /// เป้า − ปัจจุบัน · nil ถ้าไม่ได้ตั้งเป้า (targetScore == 0)
    static func gap(target: Double, weights: [TCASWeightInput], scores: [TCASScoreInput]) -> Double? {
        guard target > 0 else { return nil }
        return target - currentScore(weights: weights, scores: scores)
    }

    /// เรียงวิชาตาม leverage มากไปน้อย
    static func leverage(weights: [TCASWeightInput], scores: [TCASScoreInput]) -> [TCASSubjectBreakdown] {
        breakdown(weights: weights, scores: scores).sorted { $0.leverage > $1.leverage }
    }

    /// เรียงวิชาตาม headroom มากไปน้อย — ให้ผู้ใช้ตัดสินเอง (ไม่ชี้นิ้วว่า "จงอ่านวิชานี้", §4.2)
    static func headroom(weights: [TCASWeightInput], scores: [TCASScoreInput]) -> [TCASSubjectBreakdown] {
        breakdown(weights: weights, scores: scores).sorted { $0.headroom > $1.headroom }
    }

    /// โหมดล็อก "สอบไปแล้ว" (§4.3) — nil ถ้าไม่ได้ตั้งเป้า หรือทุกวิชาล็อกครบแล้ว (ไม่มีอะไรให้คำนวณ)
    static func requiredAverage(
        target: Double,
        weights: [TCASWeightInput],
        scores: [TCASScoreInput]
    ) -> TCASRequiredAverageResult? {
        guard target > 0 else { return nil }
        let items = breakdown(weights: weights, scores: scores)
        let remaining = items.filter { !$0.hasTaken }
        guard !remaining.isEmpty else { return nil }

        let lockedContribution = items.filter(\.hasTaken).reduce(0) { $0 + ($1.currentContribution ?? 0) }
        let remainingPercent = remaining.reduce(0) { $0 + $1.percent }
        guard remainingPercent > 0 else { return nil }

        let requiredAveragePercent = ((target - lockedContribution) / remainingPercent) * 100
        return TCASRequiredAverageResult(
            lockedContribution: lockedContribution,
            remainingPercent: remainingPercent,
            requiredAveragePercent: requiredAveragePercent
        )
    }

    /// จุดเดียวที่คำนวณ % ต่อวิชาเมื่อแก้ % ของกลุ่ม — หารเท่ากันทุกวิชาที่เลือกในกลุ่ม (§2.2/§7.2)
    /// View ที่เขียนน้ำหนักกลุ่ม (TCASWeightSetupView, รอบ C) ต้องเรียกจุดนี้เสมอ ห้ามคำนวณเอง
    static func setGroupPercent(groupPercent: Double, memberCount: Int) -> Double {
        guard memberCount > 0 else { return 0 }
        return groupPercent / Double(memberCount)
    }
}
