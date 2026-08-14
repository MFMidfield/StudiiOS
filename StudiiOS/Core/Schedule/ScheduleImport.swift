//
//  ScheduleImport.swift
//  The in-memory shape of a schedule photo between OCR and SwiftData.
//
//  `ScheduleDraftEntry` is what the parser produces — one cell, read as well as
//  it could be read. `ImportedPeriod` is what the user reviews: the same cell
//  after the code grammar has had a look at it, carrying a *separate* flag for
//  every different reason the row might be wrong, because the review sheet
//  shows a different hint for each and merging them loses that.
//
//  Nothing here is a @Model. The whole import lives in memory until the user
//  taps บันทึก, at which point ScheduleImportCommitter writes it.
//

import Foundation
import UIKit

/// One import session: the photo, and what was read out of it. `Identifiable`
/// so the review sheet is presented with `.sheet(item:)` — the payload arriving
/// *is* the trigger, so "finished analyzing" and "sheet is up" cannot drift
/// apart the way a separate Bool would let them.
struct ImportReviewPayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let periods: [ImportedPeriod]
}

/// One row in the import review sheet.
struct ImportedPeriod: Identifiable {
    let id = UUID()

    var dayOfWeek: Int          // 1 = Monday … 7 = Sunday
    var periodNumber: Int       // as printed on the sheet; index+1 when unreadable
    var startMinute: Int        // minutes from midnight
    var endMinute: Int

    var subjectCode: String     // "ว30203", or "" when the cell held no code
    var subjectName: String     // what will be shown in the timetable
    var teacherName: String     // "" when unknown
    var room: String            // "" when unknown
    var isBreak: Bool           // homeroom / lunch / club / activity

    var codeNeedsReview: Bool   // OCR could not prove the subject code
    var codeOptions: [String]   // enumerable alternatives, may be empty
    var timeIsGuessed: Bool     // the period's time was inferred, not read
    var nameIsGuessed: Bool     // name was derived from the code, not read

    var isUserAdded: Bool = false   // typed by hand in the review sheet

    var needsAttention: Bool { codeNeedsReview || timeIsGuessed || nameIsGuessed }
}

enum ScheduleImportBuilder {

    /// Turns the parser's raw cells into review rows. Every judgement about
    /// what a cell *means* happens here and nowhere else — the parser only
    /// reports what it saw, and the review sheet only displays what it is given.
    static func build(from drafts: [ScheduleDraftEntry]) -> [ImportedPeriod] {
        var periods: [ImportedPeriod] = []

        for draft in drafts {
            let read = draft.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !read.isEmpty else { continue }

            var code = ""
            var name = read
            var isBreak = false
            var nameIsGuessed = false

            if ThaiSubjectCatalog.isBreakLabel(read) {
                isBreak = true
            } else if let parsed = ThaiSubjectCatalog.parse(read) {
                // The cell held a code, so the name shown is a category derived
                // from it — a real guess, and flagged as one.
                code = parsed.raw
                name = ThaiSubjectCatalog.generatedName(for: parsed)
                nameIsGuessed = true
            }
            // Anything else is free text the school printed in full. Left alone.

            periods.append(
                ImportedPeriod(
                    dayOfWeek: draft.dayOfWeek,
                    periodNumber: draft.periodNumber,
                    startMinute: draft.startMinute,
                    endMinute: draft.endMinute,
                    subjectCode: code,
                    subjectName: name,
                    teacherName: draft.teacherName ?? "",
                    room: draft.room ?? "",
                    isBreak: isBreak,
                    // ScheduleDraftEntry.needsReview folds the time flag in for
                    // OCRDebugView's benefit. The two hints are different here,
                    // so the time half has to come back out.
                    codeNeedsReview: !isBreak && draft.needsReview && !draft.timeIsGuessed,
                    codeOptions: draft.reviewOptions,
                    timeIsGuessed: draft.timeIsGuessed,
                    nameIsGuessed: nameIsGuessed
                )
            )
        }

        periods.sort {
            if $0.dayOfWeek != $1.dayOfWeek { return $0.dayOfWeek < $1.dayOfWeek }
            if $0.periodNumber != $1.periodNumber { return $0.periodNumber < $1.periodNumber }
            return $0.startMinute < $1.startMinute
        }
        return periods
    }
}
