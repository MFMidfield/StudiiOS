//
//  ScheduleConstants.swift
//  Shared constants for the timetable feature, declared once so callers
//  (onboarding's ScheduleSetupView, the Schedule tab) never drift apart.
//

import Foundation
import SwiftData

enum ScheduleConstants {
    /// Only Monday–Friday are shown (weekends hidden) — change here to bring back 7 days.
    static let visibleDays: [Int] = [1, 2, 3, 4, 5]
    static let dayLabels: [Int: String] = [1: "จันทร์", 2: "อังคาร", 3: "พุธ", 4: "พฤหัส", 5: "ศุกร์", 6: "เสาร์", 7: "อาทิตย์"]
    static let dayLabelsFull: [Int: String] = [1: "วันจันทร์", 2: "วันอังคาร", 3: "วันพุธ", 4: "วันพฤหัสบดี", 5: "วันศุกร์", 6: "วันเสาร์", 7: "วันอาทิตย์"]
    static let defaultSubjectIcon = "book.closed.fill"

    /// Today as 1=Mon…7=Sun (Calendar hands back 1=Sun…7=Sat).
    static var todayWeekday: Int {
        let raw = Calendar.current.component(.weekday, from: .now)
        return raw == 1 ? 7 : raw - 1
    }

    /// The day a new period form should open on. Weekends aren't in
    /// `visibleDays`, so on Sat/Sun it falls back to Monday rather than
    /// handing the picker a value it can't show.
    static var defaultEntryDay: Int {
        visibleDays.contains(todayWeekday) ? todayWeekday : 1
    }

    /// Finds a Subject by case-insensitive name match, or creates one (color
    /// rotating through `Theme.Colors.subjectPaletteHex`) and returns it.
    /// Returns nil for a blank name — callers should skip attaching a subject then.
    static func findOrCreateSubject(named: String, in context: ModelContext) -> Subject? {
        let trimmed = named.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }

        let colorHex = Theme.Colors.subjectPaletteHex[existing.count % Theme.Colors.subjectPaletteHex.count]
        let subject = Subject(name: trimmed, colorHex: colorHex, iconName: defaultSubjectIcon)
        context.insert(subject)
        AppLog.action("Subject", "สร้างวิชาอัตโนมัติ: \(trimmed) สี=\(colorHex)")
        return subject
    }

    /// Finds the Subject a hand-edited schedule row means, or creates it. Code
    /// wins over name, matching ScheduleImportCommitter's rule, so a row typed
    /// with a code lands on the same Subject a photo import would have found.
    /// Colour and icon come from ThaiSubjectCatalog so a manually typed subject
    /// looks the same as an imported one.
    ///
    /// `isBreak` is deliberately left false: a break subject is created through
    /// AddSubjectSheet's "เป็นช่วงพัก" toggle or through the import path, never
    /// by typing a name into the period form.
    ///
    /// `strand` is for callers who picked the subject from `ThaiCourseCatalog` and
    /// therefore already know its learning area — a catalog pick carries no code,
    /// so without this the colour would fall back to the generic one.
    ///
    /// Returns nil for a blank name.
    static func resolveSubject(named: String, code: String, strand: ThaiSubjectStrand? = nil, in context: ModelContext) -> Subject? {
        let name = named.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines)

        let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []

        if !code.isEmpty,
           let match = existing.first(where: { !$0.code.isEmpty && $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
            return match
        }
        if let match = existing.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            // Fill in a code the user has now supplied, but never overwrite one.
            if !code.isEmpty, match.code.isEmpty { match.code = code }
            return match
        }

        let resolvedStrand = strand ?? ThaiSubjectCatalog.parse(code)?.strand
        let look = ThaiSubjectCatalog.appearance(strand: resolvedStrand, name: name)
        let subject = Subject(name: name, code: code, colorHex: look.colorHex, iconName: look.iconName)
        context.insert(subject)
        AppLog.action("Subject", "สร้างวิชาจากฟอร์มคาบ: \(name) (\(code))")
        return subject
    }
}
