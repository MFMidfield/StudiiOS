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
}
