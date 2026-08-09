//
//  TCASExamCatalog.swift
//  รายชื่อวิชาสอบ TCAS ทั้งระบบ — logic ล้วน ไม่มี View ไม่มี SwiftData
//  (เทียบเคียง ThaiSubjectCatalog.swift). ห้ามใส่เกณฑ์คะแนน/รายชื่อคณะ (PLAN_TCASPlanner §0.3)
//
//  ⚠️ รายชื่อ/รหัส/คะแนนเต็มเขียนจากความรู้ทั่วไป Few ต้องตรวจกับ mytcas.com ก่อน merge
//

import Foundation

enum TCASExamGroup: String, CaseIterable {
    case tgat = "TGAT"
    case tpat = "TPAT"
    case aLevel = "A-Level"

    var thaiName: String {
        switch self {
        case .tgat: return "TGAT — ความถนัดทั่วไป"
        case .tpat: return "TPAT — ความถนัดวิชาชีพ"
        case .aLevel: return "A-Level — วิชาการ"
        }
    }
}

struct TCASExam: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let displayName: String
    let group: TCASExamGroup
    let fullScore: Double
}

enum TCASExamCatalog {
    static let all: [TCASExam] = [
        // TGAT — เต็ม 100/วิชา
        TCASExam(code: "TGAT1", displayName: "TGAT1 การสื่อสารภาษาอังกฤษ", group: .tgat, fullScore: 100),
        TCASExam(code: "TGAT2", displayName: "TGAT2 การคิดอย่างมีเหตุผล", group: .tgat, fullScore: 100),
        TCASExam(code: "TGAT3", displayName: "TGAT3 สมรรถนะการทำงาน", group: .tgat, fullScore: 100),

        // TPAT — เต็ม 300/วิชา
        TCASExam(code: "TPAT1", displayName: "TPAT1 ความถนัดแพทย์ (กสพท)", group: .tpat, fullScore: 300),
        TCASExam(code: "TPAT21", displayName: "TPAT21 ทัศนศิลป์", group: .tpat, fullScore: 300),
        TCASExam(code: "TPAT22", displayName: "TPAT22 ดนตรี", group: .tpat, fullScore: 300),
        TCASExam(code: "TPAT23", displayName: "TPAT23 นาฏศิลป์", group: .tpat, fullScore: 300),
        TCASExam(code: "TPAT3", displayName: "TPAT3 วิทยาศาสตร์ เทคโนโลยี วิศวกรรมศาสตร์", group: .tpat, fullScore: 300),
        TCASExam(code: "TPAT4", displayName: "TPAT4 สถาปัตยกรรมศาสตร์", group: .tpat, fullScore: 300),
        TCASExam(code: "TPAT5", displayName: "TPAT5 ครุศาสตร์/ศึกษาศาสตร์", group: .tpat, fullScore: 300),

        // A-Level — เต็ม 100/วิชา
        TCASExam(code: "61", displayName: "A-Level คณิตศาสตร์ประยุกต์ 1", group: .aLevel, fullScore: 100),
        TCASExam(code: "62", displayName: "A-Level คณิตศาสตร์ประยุกต์ 2", group: .aLevel, fullScore: 100),
        TCASExam(code: "63", displayName: "A-Level วิทยาศาสตร์ประยุกต์", group: .aLevel, fullScore: 100),
        TCASExam(code: "64", displayName: "A-Level ฟิสิกส์", group: .aLevel, fullScore: 100),
        TCASExam(code: "65", displayName: "A-Level เคมี", group: .aLevel, fullScore: 100),
        TCASExam(code: "66", displayName: "A-Level ชีววิทยา", group: .aLevel, fullScore: 100),
        TCASExam(code: "70", displayName: "A-Level สังคมศึกษา", group: .aLevel, fullScore: 100),
        TCASExam(code: "81", displayName: "A-Level ภาษาไทย", group: .aLevel, fullScore: 100),
        TCASExam(code: "82", displayName: "A-Level ภาษาอังกฤษ", group: .aLevel, fullScore: 100),
        TCASExam(code: "83", displayName: "A-Level ภาษาฝรั่งเศส", group: .aLevel, fullScore: 100),
        TCASExam(code: "84", displayName: "A-Level ภาษาเยอรมัน", group: .aLevel, fullScore: 100),
        TCASExam(code: "85", displayName: "A-Level ภาษาญี่ปุ่น", group: .aLevel, fullScore: 100),
        TCASExam(code: "86", displayName: "A-Level ภาษาเกาหลี", group: .aLevel, fullScore: 100),
        TCASExam(code: "87", displayName: "A-Level ภาษาจีน", group: .aLevel, fullScore: 100),
        TCASExam(code: "88", displayName: "A-Level ภาษาบาลี", group: .aLevel, fullScore: 100),
        TCASExam(code: "89", displayName: "A-Level ภาษาสเปน", group: .aLevel, fullScore: 100),
    ]

    /// จัดกลุ่มตาม TCASExamGroup สำหรับ Picker 2 ชั้น — เรียงตามลำดับ TCASExamGroup.allCases
    static var grouped: [(group: TCASExamGroup, exams: [TCASExam])] {
        TCASExamGroup.allCases.map { group in
            (group: group, exams: all.filter { $0.group == group })
        }
    }

    static func exam(code: String) -> TCASExam? {
        all.first { $0.code == code }
    }
}
