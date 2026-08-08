//
//  ScheduleImportCommitter.swift
//  Writes a reviewed import into SwiftData. The only destructive step in the
//  whole feature, so it is deliberately blunt and easy to reason about:
//
//    every day the photo covers loses ALL its existing periods, then gets the
//    reviewed rows — and days the photo did not cover are never touched.
//
//  Per-row merging was rejected: a timetable photo is the authoritative view of
//  those days, and half-merged rows leave duplicates that look exactly like the
//  import ran twice. The caller confirms with the user first, naming the days.
//
//  Subjects are NEVER deleted here. `Assignment.subjectName` is a loose string
//  lookup and DayScheduleOverride keys on a date, so dropping only ScheduleEntry
//  rows is safe — removing a Subject would silently orphan homework.
//

import Foundation
import SwiftData

enum ScheduleImportCommitter {

    struct Summary {
        var deletedEntries = 0
        var insertedEntries = 0
        var createdSubjects = 0
        var days: [Int] = []

        var firstDay: Int? { days.min() }
    }

    @discardableResult
    static func commit(_ periods: [ImportedPeriod], in context: ModelContext) -> Summary {
        let days = Set(periods.map(\.dayOfWeek))
        guard !days.isEmpty else { return Summary() }

        var summary = Summary()
        summary.days = days.sorted()

        // 1. Wipe the days this import covers.
        let existingEntries = (try? context.fetch(FetchDescriptor<ScheduleEntry>())) ?? []
        for entry in existingEntries where days.contains(entry.dayOfWeek) {
            context.delete(entry)
            summary.deletedEntries += 1
        }

        // 2. Resolve subjects against ONE fetch, appending as we create — a
        //    re-fetch inside the loop would not see the unsaved inserts and
        //    would create the same subject once per period.
        var subjects = (try? context.fetch(FetchDescriptor<Subject>())) ?? []

        for period in periods {
            let subject = resolveSubject(for: period, in: &subjects, context: context, summary: &summary)
            context.insert(
                ScheduleEntry(
                    dayOfWeek: period.dayOfWeek,
                    startMinute: period.startMinute,
                    endMinute: period.endMinute,
                    periodNumber: period.periodNumber,
                    teacherName: period.teacherName,
                    location: period.room,
                    subjectName: subject.name,
                    subject: subject
                )
            )
            summary.insertedEntries += 1
        }

        do {
            try context.save()
        } catch {
            AppLog.error("ScheduleImport", "บันทึกตารางล้มเหลว: \(error.localizedDescription)")
            summary.insertedEntries = 0
            return summary
        }

        AppLog.action(
            "ScheduleImport",
            "บันทึก \(summary.insertedEntries) คาบ · ลบของเดิม \(summary.deletedEntries) คาบ"
                + " · สร้างวิชาใหม่ \(summary.createdSubjects) รายการ · วัน \(summary.days)"
        )
        return summary
    }

    /// Code first, then name (contract D2). Matching on the code is what lets a
    /// school that prints "ว30202" in one cell and nothing in another still land
    /// on the same subject the user already had.
    private static func resolveSubject(
        for period: ImportedPeriod,
        in subjects: inout [Subject],
        context: ModelContext,
        summary: inout Summary
    ) -> Subject {
        let code = period.subjectCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = period.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !code.isEmpty,
           let match = subjects.first(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
            return match
        }
        if let match = subjects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match
        }

        let look = period.isBreak
            ? ThaiSubjectCatalog.breakAppearance(for: name)
            : ThaiSubjectCatalog.appearance(
                strand: ThaiSubjectCatalog.parse(code)?.strand,
                name: name
            )
        let subject = Subject(
            name: name,
            code: code,
            colorHex: look.colorHex,
            iconName: look.iconName,
            isBreak: period.isBreak
        )
        context.insert(subject)
        subjects.append(subject)
        summary.createdSubjects += 1
        return subject
    }
}
