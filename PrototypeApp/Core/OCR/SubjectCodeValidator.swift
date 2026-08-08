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

    /// Confusion pairs CONFIRMED on real report photos — every one of these was
    /// observed as an actual misread, not inferred from letter shapes.
    /// An entry with exactly one candidate is repaired automatically; the rest
    /// are handed to the user (see `repair`).
    static let confusionMap: [Character: [Character]] = [
        "2": ["ว"],               // 5 occurrences on the reference sheet
        "W": ["พ"],
        "w": ["พ"],
        "7": ["ว"],               // ม.4/9 #44 730261, #69 730242
        "3": ["ว", "ส"],          // ส on ม.5/9, but ว on ม.4/9 (330261 → ว30261)
        "8": ["อ", "ส"],          // ม.4/9 #25 #51 831102 → อ, #134 831102 → ส
        "4": ["จ", "ง"],          // ม.4/9 #28 431102
        "0": ["ง", "อ"],          // genuinely ambiguous — always flag
        "1": ["ท", "ก", "จ"],     // ท seen twice, the rest are shape-only
    ]

    /// Guesses made from letter shapes alone, never seen in a verified misread.
    /// These are ALWAYS flagged, even the single-candidate ones — repairing on
    /// shape resemblance is exactly the "automatic 100%" the round-2 design
    /// rule rejects: repair what you can prove, flag what you can't.
    static let shapeOnlyConfusionMap: [Character: [Character]] = [
        "6": ["ค"],
        "A": ["ค"],
        "a": ["ส"],
        "N": ["พ"],
        "n": ["ก", "ท"],
        "ด": ["ค"],
    ]

    /// True when `text` is a well-formed subject code.
    static func isValid(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count == 6 else { return false }
        guard let first = t.unicodeScalars.first,
              thaiConsonants.contains(first.value) else { return false }
        return t.dropFirst().allSatisfy(\.isNumber)
    }

    /// True when `text` has the exact SHAPE of a subject code (6 chars, last
    /// five are digits) regardless of what the first character turned out to
    /// be. This is the only shape that gets auto-repaired.
    static func looksLikeCode(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count == 6 else { return false }
        return t.dropFirst().allSatisfy(\.isNumber)
    }

    /// Looser: the cell was *meant* to be a code even though Vision dropped or
    /// invented a character around it. 5–7 characters containing a run of at
    /// least four digits.
    ///
    /// Used only to decide "this belongs to the user", never to repair — the
    /// point is that a dropped consonant surfaces as ⚠️ instead of becoming a
    /// subject literally named "32101".
    static func looksLikeCodeSlot(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (5...7).contains(t.count) else { return false }
        return longestDigitRun(t) >= 4
    }

    /// The five trailing digits of a code-shaped string — the key the
    /// cross-image ledger groups on.
    static func tail(of text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 5 else { return nil }
        let last = String(t.suffix(5))
        guard last.allSatisfy(\.isNumber), Int(last) != nil else { return nil }
        return last
    }

    enum Repair {
        case alreadyValid(String)
        case repaired(String)                    // one unambiguous fix
        case ambiguous(options: [String])        // needs the user
        case unknown                             // no idea — needs the user
    }

    /// Single-character confusion repair. Voting across the whole image is a
    /// separate stage (`SubjectCodeLedger`) — this function looks at one
    /// string, on its own, with no context.
    static func repair(_ text: String) -> Repair {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValid(t) { return .alreadyValid(t) }
        guard looksLikeCode(t), let first = t.first else { return .unknown }
        let tail = t.dropFirst()

        if let options = confusionMap[first] {
            let fixed = options.map { String($0) + tail }
            return fixed.count == 1 ? .repaired(fixed[0]) : .ambiguous(options: fixed)
        }
        if let options = shapeOnlyConfusionMap[first] {
            return .ambiguous(options: options.map { String($0) + tail })
        }
        return .unknown
    }

    /// Longest run of consecutive digits — the signal that a cell was a code
    /// slot even when its length is off by one.
    private static func longestDigitRun(_ text: String) -> Int {
        var best = 0
        var run = 0
        for character in text {
            if character.isNumber {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }
}

/// Agreement between several readings of the same code within one image.
///
/// This is the only thing that can catch Thai→Thai confusion: ค misread as ศ
/// produces a perfectly well-formed code, so the grammar above is blind to it
/// and no per-string rule will ever see the problem.
///
/// Two rules, deliberately narrow:
///
/// * **Unanimity, not majority.** The key is the five trailing digits, and the
///   valid readings sharing that tail must all agree. On the reference sheet
///   the tail "32101" is shared by ท ค พ อ ศ ส — a plain majority vote there
///   would rewrite six correct cells in order to fix none. Unanimity narrows
///   the rule to "in this table that tail belongs to exactly one subject",
///   which is the only case where the evidence actually holds.
/// * **Only unambiguous readings vote.** A reading the parser had to *choose*
///   between — a "0" that is either ง or อ — must never become the proof for
///   the next cell, or one guess propagates across the sheet. A reading with
///   no choice in it does vote: an alternative Vision candidate that parsed
///   cleanly, or a confusion entry with exactly one option, is as good as a
///   first-candidate hit. Restricting the ledger to first-candidate hits
///   starved it — the reference sheet had 6 of those out of 35 codes, so the
///   vote had almost nothing to say and cells that four readings agreed on
///   still came out wrong.
struct SubjectCodeLedger {
    private var byTail: [String: Set<Character>] = [:]
    private var byTeacherAndTail: [String: Set<Character>] = [:]

    /// Field separator that cannot appear in a name or a code.
    private static let keySeparator = "\u{1F}"

    init(observations: [(code: String, teacher: String?)]) {
        for observation in observations {
            let code = observation.code.trimmingCharacters(in: .whitespacesAndNewlines)
            guard SubjectCodeValidator.isValid(code),
                  let tail = SubjectCodeValidator.tail(of: code),
                  let lead = code.first
            else { continue }
            byTail[tail, default: []].insert(lead)
            if let teacher = observation.teacher {
                byTeacherAndTail[Self.key(teacher, tail), default: []].insert(lead)
            }
        }
    }

    /// The leading consonant this tail must have, or nil when the image offers
    /// no unanimous answer.
    ///
    /// Teacher evidence goes first: one teacher teaches one subject, so it
    /// still decides tails that several subjects share — the case where the
    /// sheet-wide vote has to abstain.
    func leadingConsonant(tail: String, teacher: String?) -> Character? {
        if let teacher, let byTeacher = byTeacherAndTail[Self.key(teacher, tail)], byTeacher.count == 1 {
            return byTeacher.first
        }
        if let sheetWide = byTail[tail], sheetWide.count == 1 {
            return sheetWide.first
        }
        return nil
    }

    private static func key(_ teacher: String, _ tail: String) -> String {
        teacher + keySeparator + tail
    }
}
