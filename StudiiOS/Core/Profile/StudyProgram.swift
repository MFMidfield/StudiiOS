//
//  StudyProgram.swift
//  แผนการเรียนของนักเรียน ม.ปลาย — a fixed list, not free text.
//
//  It used to be a TextField, on the grounds that Thai schools name their
//  programmes however they like. In practice everything a student picks lands in
//  one of three buckets, and a typed string can never be compared or counted. The
//  odd programme that fits none of them gets `.unspecified` — better an honest
//  blank than a spelling nobody can match.
//
//  Display only for now: nothing computes from it. Keep `rawValue` stable, it is
//  what UserDefaults holds.
//

import Foundation

enum StudyProgram: String, CaseIterable, Identifiable {
    case scienceMath = "sci-math"
    case artsCalculation = "arts-calc"
    case artsLanguage = "arts-lang"
    case unspecified = ""

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scienceMath:     return "วิทย์-คณิต"
        case .artsCalculation: return "ศิลป์-คำนวณ"
        case .artsLanguage:    return "ศิลป์-ภาษา"
        case .unspecified:     return "อื่นๆ / ไม่ระบุ"
        }
    }

    /// The three real programmes, in the order a school prospectus lists them.
    /// `.unspecified` is deliberately last everywhere, so it is appended, never sorted in.
    static var selectable: [StudyProgram] { [.scienceMath, .artsCalculation, .artsLanguage, .unspecified] }
}
