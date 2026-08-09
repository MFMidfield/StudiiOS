//
//  Term.swift
//  One school term: a grade level (ม.1–ม.6) plus a term number (1 or 2).
//  Every timetable, task and score sheet hangs off exactly one of these.
//
//  There is no academic-year field on purpose: a student passes through each
//  of the 12 slots exactly once, so gradeLevel + termNumber is already unique
//  for one student. Terms are created lazily — see TermStore.findOrCreate.
//
//  Trap: do not add @Relationship arrays (e.g. var entries: [ScheduleEntry])
//  here. Children point up to the term (var term: Term?) and deletion is
//  done manually in TermStore.delete.
//

import Foundation
import SwiftData

/// Which half of Thai secondary school a grade level belongs to.
/// Used only to split the term picker into two dropdowns.
enum SchoolBand: String, CaseIterable, Identifiable {
    case lower   // ม.ต้น — ม.1, ม.2, ม.3
    case upper   // ม.ปลาย — ม.4, ม.5, ม.6

    var id: String { rawValue }
    var label: String { self == .lower ? "ม.ต้น" : "ม.ปลาย" }
    var gradeLevels: [Int] { self == .lower ? [1, 2, 3] : [4, 5, 6] }

    static func containing(gradeLevel: Int) -> SchoolBand {
        gradeLevel <= 3 ? .lower : .upper
    }
}

@Model
final class Term {
    /// Stable id. Stored (as a string) in @AppStorage to remember the active
    /// term. SwiftData's PersistentIdentifier is not safe to persist in
    /// UserDefaults, so we carry our own UUID.
    var id: UUID = UUID()

    /// 1...6 → ม.1 ... ม.6
    var gradeLevel: Int = 4
    /// 1 or 2
    var termNumber: Int = 1
    var createdAt: Date = Date.now

    init(gradeLevel: Int, termNumber: Int, id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        self.gradeLevel = gradeLevel
        self.termNumber = termNumber
        self.createdAt = createdAt
    }

    /// "ม.4 เทอม 1"
    var displayName: String { "ม.\(gradeLevel) เทอม \(termNumber)" }

    var band: SchoolBand { SchoolBand.containing(gradeLevel: gradeLevel) }

    /// Chronological order: ม.1เทอม1 = 11 … ม.6เทอม2 = 62.
    /// Use this for every `sort:` on Term. It is a stored-value computation,
    /// so it CANNOT be used inside a #Predicate — sort in Swift instead.
    var sortKey: Int { gradeLevel * 10 + termNumber }
}
