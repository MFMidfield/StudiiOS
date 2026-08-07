//
//  SubjectCodeValidator.swift
//  Thai school subject codes are always ONE Thai consonant followed by
//  exactly five digits (ว30243, ค32101). Vision frequently misreads the
//  leading consonant as a digit or Latin letter — but never the reverse,
//  because the five trailing digits give the model plenty of context.
//  That asymmetry makes the grammar a reliable 100%-recall error detector.
//
//  NOTE: do NOT use VNRecognizedText.confidence to pick between candidates.
//  Measured on a real timetable, every wrong code had confidence 1.00 while
//  several correct ones had 0.50 — the signal is inverted and useless here.
//

import Foundation

enum SubjectCodeValidator {
    /// Thai consonants ก (U+0E01) … ฮ (U+0E2E)
    private static let thaiConsonants: ClosedRange<UInt32> = 0x0E01...0x0E2E

    /// Confusion pairs observed on real report photos.
    /// Value = every plausible correction, most likely first.
    /// Only entries with EXACTLY ONE candidate get auto-repaired; the rest
    /// are flagged for the user (see `repair`).
    static let confusionMap: [Character: [Character]] = [
        "2": ["ว"],
        "W": ["พ"],
        "w": ["พ"],
        "0": ["ง", "อ"],          // genuinely ambiguous — always flag
        "1": ["ท", "ก", "จ"],     // unconfirmed, flag
    ]

    /// True when `text` is a well-formed subject code.
    static func isValid(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count == 6 else { return false }
        guard let first = t.unicodeScalars.first,
              thaiConsonants.contains(first.value) else { return false }
        return t.dropFirst().allSatisfy(\.isNumber)
    }

    /// True when `text` LOOKS like a subject code slot (6 chars, last five
    /// are digits) regardless of whether the first char is a Thai consonant.
    /// Used to decide "this box was supposed to be a code" before repairing.
    static func looksLikeCode(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count == 6 else { return false }
        return t.dropFirst().allSatisfy(\.isNumber)
    }

    enum Repair {
        case alreadyValid(String)
        case repaired(String)                    // one unambiguous fix
        case ambiguous(options: [String])        // needs the user
        case unknown                             // no idea — needs the user
    }

    /// Single-character confusion repair. Voting across the whole image
    /// (using other codes that share the same five trailing digits) is a
    /// separate, later stage — this function looks at one string only.
    static func repair(_ text: String) -> Repair {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValid(t) { return .alreadyValid(t) }
        guard looksLikeCode(t), let first = t.first else { return .unknown }
        guard let options = confusionMap[first] else { return .unknown }
        let tail = t.dropFirst()
        let fixed = options.map { String($0) + tail }
        return fixed.count == 1 ? .repaired(fixed[0]) : .ambiguous(options: fixed)
    }
}
