//
//  TCASScoreEngineTests.swift
//  Fixture ยืมตัวเลขจาก "claude plan/PLAN_TCASPlanner.md" §4.2 (leverage) และ §4.3
//  (โหมดล็อก) ตรงๆ — ถ้าตัวอย่างในแผนเปลี่ยน ให้แก้คู่กัน
//

import Testing
@testable import PrototypeApp

struct TCASScoreEngineTests {

    // MARK: - §4.2 fixture: น้ำหนักรวม 100% พอดี (TGAT1 20 · TPAT3 30 · A-Level61 25 · A-Level64 25)

    private func fixtureWeights() -> [TCASWeightInput] {
        [
            .init(examCode: "TGAT1", percent: 20),
            .init(examCode: "TPAT3", percent: 30),
            .init(examCode: "61", percent: 25),
            .init(examCode: "64", percent: 25),
        ]
    }

    // MARK: 1. คะแนนปกติ

    @Test func normalScoreComputesCurrentAndCeiling() {
        let weights = fixtureWeights()
        let scores: [TCASScoreInput] = [
            .init(examCode: "TGAT1", score: 80),   // 80/100*20 = 16
            .init(examCode: "TPAT3", score: 150),  // 150/300*30 = 15
            // 61, 64 ยังไม่กรอก
        ]

        let current = TCASScoreEngine.currentScore(weights: weights, scores: scores)
        let ceiling = TCASScoreEngine.ceilingScore(weights: weights, scores: scores)

        #expect(current == 31.0)          // 16 + 15
        #expect(ceiling == 31.0 + 25 + 25) // + เต็มของ 2 วิชาที่ยังไม่กรอก
    }

    @Test func gapUsesTargetMinusCurrent() {
        let weights = fixtureWeights()
        let scores: [TCASScoreInput] = [.init(examCode: "TGAT1", score: 80)] // 16

        #expect(TCASScoreEngine.gap(target: 0, weights: weights, scores: scores) == nil)
        #expect(TCASScoreEngine.gap(target: 60, weights: weights, scores: scores) == 44.0)
    }

    // MARK: 2. น้ำหนักไม่ครบ 100 — เตือนได้ แต่คำนวณต่อได้ปกติ ไม่บล็อก

    @Test func incompleteWeightsStillComputes() {
        let weights: [TCASWeightInput] = [
            .init(examCode: "TGAT1", percent: 20),
            .init(examCode: "TPAT3", percent: 30),
        ]
        #expect(TCASScoreEngine.totalPercent(weights: weights) == 50)

        let scores: [TCASScoreInput] = [.init(examCode: "TGAT1", score: 100)] // 100/100*20 = 20
        #expect(TCASScoreEngine.currentScore(weights: weights, scores: scores) == 20.0)
    }

    // MARK: 3. โหมดกลุ่ม — หารเท่ากันตาม §7.2 (A-Level 70% ÷ 3 วิชา)

    @Test func setGroupPercentSplitsEvenly() {
        let perSubject = TCASScoreEngine.setGroupPercent(groupPercent: 70, memberCount: 3)
        #expect(abs(perSubject - 23.333333333333332) < 0.0000001)

        // 3 แถวที่ผลลัพธ์ถูกเขียนกลับ ต้องรวมกันได้ใกล้เคียงกับ groupPercent เดิม
        let total = perSubject * 3
        #expect(abs(total - 70) < 0.0001)
    }

    @Test func setGroupPercentZeroMembersReturnsZero() {
        #expect(TCASScoreEngine.setGroupPercent(groupPercent: 70, memberCount: 0) == 0)
    }

    // MARK: 4. โหมดล็อก — ตัวเลขตรงกับตัวอย่างใน §4.3 เป๊ะ

    @Test func requiredAverageMatchesPlanWorkedExample() {
        let weights = fixtureWeights() // รวม 100%
        let scores: [TCASScoreInput] = [
            .init(examCode: "TGAT1", score: 80, hasTaken: true),  // 80/100*20 = 16
            .init(examCode: "TPAT3", score: 95, hasTaken: true),  // 95/300*30 = 9.5
            // 61, 64 ยังไม่สอบ (hasTaken: false) — น้ำหนักรวม 50%
        ]

        let result = TCASScoreEngine.requiredAverage(target: 62.0, weights: weights, scores: scores)

        #expect(result != nil)
        #expect(abs(result!.lockedContribution - 25.5) < 0.0001)       // ล็อกแล้ว = 25.50
        #expect(abs(result!.neededFromRemaining - 36.5) < 0.0001)      // ที่เหลือต้องช่วยอีก = 36.50
        #expect(result!.remainingPercent == 50)                        // น้ำหนักรวมที่ยังไม่สอบ = 50%
        #expect(abs(result!.requiredAveragePercent - 73.0) < 0.0001)   // ต้องได้เฉลี่ย 73.0%
        #expect(result!.lockedExamCodes.sorted() == ["TGAT1", "TPAT3"])
    }

    @Test func requiredAverageNilWhenNoTarget() {
        let result = TCASScoreEngine.requiredAverage(target: 0, weights: fixtureWeights(), scores: [])
        #expect(result == nil)
    }

    @Test func requiredAverageNilWhenEverySubjectLocked() {
        let weights = fixtureWeights()
        let scores = weights.map { TCASScoreInput(examCode: $0.examCode, score: 50, hasTaken: true) }
        let result = TCASScoreEngine.requiredAverage(target: 80, weights: weights, scores: scores)
        #expect(result == nil)
    }

    // MARK: 5. required > 100% — เป็นไปไม่ได้ต่อให้ได้เต็ม แต่ engine ไม่เซ็นเซอร์ค่า ให้ View ตัดสินใจแสดงผล

    @Test func requiredAverageCanExceed100() {
        let weights = fixtureWeights()
        let scores: [TCASScoreInput] = [
            .init(examCode: "TGAT1", score: 80, hasTaken: true),
            .init(examCode: "TPAT3", score: 95, hasTaken: true),
        ]
        let result = TCASScoreEngine.requiredAverage(target: 90.0, weights: weights, scores: scores)
        #expect(result != nil)
        #expect(result!.requiredAveragePercent > 100)
    }

    // MARK: 6. ไม่มีคะแนนเลย — currentScore เป็น 0 (ไม่ใช่ "ผิด"), ceiling = totalPercent เต็ม

    @Test func noScoresAtAllGivesZeroCurrentFullCeiling() {
        let weights = fixtureWeights()
        let scores: [TCASScoreInput] = []

        #expect(TCASScoreEngine.currentScore(weights: weights, scores: scores) == 0)
        #expect(TCASScoreEngine.ceilingScore(weights: weights, scores: scores) == TCASScoreEngine.totalPercent(weights: weights))

        let breakdown = TCASScoreEngine.breakdown(weights: weights, scores: scores)
        #expect(breakdown.allSatisfy { $0.rawScore == nil })
    }
}
