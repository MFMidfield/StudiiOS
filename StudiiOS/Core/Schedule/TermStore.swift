//
//  TermStore.swift
//  The only place that knows how to find, create, switch and delete terms.
//  No view is allowed to write activeTermID or insert a Term by itself.
//

import Foundation
import SwiftData

enum TermStore {

    /// The @AppStorage key holding the active term's UUID string.
    /// Views read it with `@AppStorage(TermStore.activeTermKey)`.
    static let activeTermKey = "com.studentos.activeTermID"

    /// All 12 slots the picker can offer, in chronological order.
    /// These are NOT database rows (decision D4) — just the menu.
    static let allSlots: [(gradeLevel: Int, termNumber: Int)] =
        (1...6).flatMap { level in [1, 2].map { (level, $0) } }

    /// The slot a brand-new install starts on.
    static let defaultSlot = (gradeLevel: 4, termNumber: 1)

    // MARK: - Reading

    /// Finds the Term matching the saved id string. Returns nil if nothing matches.
    static func find(idString: String, in terms: [Term]) -> Term? {
        guard let uuid = UUID(uuidString: idString) else { return nil }
        return terms.first { $0.id == uuid }
    }

    static func find(gradeLevel: Int, termNumber: Int, in context: ModelContext) -> Term? {
        let all = (try? context.fetch(FetchDescriptor<Term>())) ?? []
        return all.first { $0.gradeLevel == gradeLevel && $0.termNumber == termNumber }
    }

    // MARK: - Writing

    /// Returns the Term for this slot, inserting it if it does not exist yet (D4).
    @discardableResult
    static func findOrCreate(gradeLevel: Int, termNumber: Int, in context: ModelContext) -> Term {
        if let existing = find(gradeLevel: gradeLevel, termNumber: termNumber, in: context) {
            return existing
        }
        let term = Term(gradeLevel: gradeLevel, termNumber: termNumber)
        context.insert(term)
        AppLog.action("Term", "สร้างเทอมใหม่: \(term.displayName)")
        return term
    }

    /// Makes this term active. Writes the id straight into UserDefaults so it can
    /// be called from non-View code; @AppStorage in views picks the change up.
    static func setActive(_ term: Term) {
        UserDefaults.standard.set(term.id.uuidString, forKey: activeTermKey)
        AppLog.action("Term", "สลับไปเทอม \(term.displayName)")
    }

    /// Called once from RootContainerView.task. Guarantees three things:
    ///   1. an active term always exists (creates the default slot on a fresh install)
    ///   2. every ScheduleEntry / Assignment / GradeComponent with term == nil
    ///      is adopted into the active term (decision D7)
    ///   3. TermSubject rows exist for every subject used by the active term
    /// Safe to call repeatedly.
    static func bootstrap(in context: ModelContext) {
        let terms = (try? context.fetch(FetchDescriptor<Term>())) ?? []
        let savedID = UserDefaults.standard.string(forKey: activeTermKey) ?? ""

        let active: Term
        if let found = find(idString: savedID, in: terms) {
            active = found
        } else if let firstExisting = terms.sorted(by: { $0.sortKey < $1.sortKey }).first {
            active = firstExisting
            setActive(active)
        } else {
            active = findOrCreate(gradeLevel: defaultSlot.gradeLevel,
                                  termNumber: defaultSlot.termNumber,
                                  in: context)
            setActive(active)
        }

        adoptOrphans(into: active, in: context)
        syncTermSubjects(for: active, in: context)
        try? context.save()
    }

    /// D7: anything with no term joins the active term.
    static func adoptOrphans(into term: Term, in context: ModelContext) {
        var adopted = 0
        for e in (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []
            where e.term == nil { e.term = term; adopted += 1 }
        for a in (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
            where a.term == nil { a.term = term; adopted += 1 }
        for g in (try? context.fetch(FetchDescriptor<GradeComponent>())) ?? []
            where g.term == nil { g.term = term; adopted += 1 }
        if adopted > 0 {
            AppLog.action("Term", "ดึงข้อมูลไม่ระบุเทอม \(adopted) รายการเข้า \(term.displayName)")
        }
    }

    /// Makes sure every Subject used by this term's schedule has a TermSubject row.
    /// Never deletes TermSubject rows here — a subject dropped from the timetable
    /// may still hold a grade the student wants to keep.
    static func syncTermSubjects(for term: Term, in context: ModelContext) {
        let entries = ((try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? [])
            .filter { $0.term?.id == term.id }
        let links = ((try? context.fetch(FetchDescriptor<TermSubject>())) ?? [])
            .filter { $0.term?.id == term.id }

        var linkedIDs = Set(links.compactMap { $0.subject?.persistentModelID })

        for entry in entries {
            guard let subject = entry.subject, !subject.isBreak else { continue }
            guard !linkedIDs.contains(subject.persistentModelID) else { continue }
            context.insert(TermSubject(term: term, subject: subject))
            linkedIDs.insert(subject.persistentModelID)
        }
    }

    /// Deletes a term and everything that belongs to it. Subjects are NEVER deleted
    /// (same rule as ScheduleImportCommitter — Assignment.subjectName is a loose lookup).
    static func delete(_ term: Term, in context: ModelContext) {
        let id = term.id
        for e in (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []
            where e.term?.id == id { context.delete(e) }
        for a in (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
            where a.term?.id == id { context.delete(a) }
        for g in (try? context.fetch(FetchDescriptor<GradeComponent>())) ?? []
            where g.term?.id == id { context.delete(g) }
        for ts in (try? context.fetch(FetchDescriptor<TermSubject>())) ?? []
            where ts.term?.id == id { context.delete(ts) }
        for tgs in (try? context.fetch(FetchDescriptor<TermGradeSubject>())) ?? []
            where tgs.term?.id == id { context.delete(tgs) }
        context.delete(term)
        try? context.save()
        AppLog.action("Term", "ลบเทอม \(term.displayName) พร้อมข้อมูลทั้งหมด")
    }
}

// MARK: - Filtering helpers
// Every view uses these two so the filter rule exists in exactly one place.

extension Array where Element == ScheduleEntry {
    /// Rows belonging to this term. A nil term means "show nothing" —
    /// bootstrap() guarantees an active term exists before any view renders.
    func inTerm(_ term: Term?) -> [ScheduleEntry] {
        guard let term else { return [] }
        return filter { $0.term?.id == term.id }
    }
}

extension Array where Element == Assignment {
    /// Note the asymmetry with ScheduleEntry, it is deliberate: a schedule row
    /// with no term is a bug and should not appear; a task with no term should
    /// still be visible (D7) until bootstrap adopts it.
    func inTerm(_ term: Term?) -> [Assignment] {
        guard let term else { return self }   // never hide tasks (D7)
        return filter { $0.term == nil || $0.term?.id == term.id }
    }
}

extension Array where Element == GradeComponent {
    func inTerm(_ term: Term?) -> [GradeComponent] {
        guard let term else { return self }
        return filter { $0.term == nil || $0.term?.id == term.id }
    }
}
