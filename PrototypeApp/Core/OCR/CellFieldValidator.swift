//
//  CellFieldValidator.swift
//  Grammar checks for the fields of a timetable cell that are NOT the subject
//  code. Measured on the reference sheet, rooms came back 100% correct and
//  teacher names 93% — but the two failures were invisible without a rule,
//  because "ครวรัญญา" and "ครูA" are perfectly ordinary strings to Vision.
//
//  Same design rule as SubjectCodeValidator: repair only what the grammar
//  proves, flag everything else. Nothing in here guesses at a name.
//
//  A note on counting Thai: Swift's Character is a grapheme cluster, so a
//  vowel sign belongs to the consonant it sits on — "ครู" is TWO characters
//  (ค and รู), not three. Every length and prefix test below relies on that,
//  which is also what makes "คร…" a clean signal that the ู was dropped.
//

import Foundation

enum CellFieldValidator {

    /// A teacher label as read off the sheet, after normalization.
    struct TeacherReading {
        /// Always starts with "ครู".
        let name: String
        /// True when the label itself is doubtful — a Latin letter or a digit
        /// where a Thai name belongs, or nothing left after the prefix.
        let needsReview: Bool
        /// True when the "ครู" prefix had to be restored.
        let wasRepaired: Bool
    }

    /// Thai timetables prefix every teacher with "ครู", and that prefix is the
    /// only reliable way to tell a teacher line from a subject name. So a
    /// dropped สระ ู has to be repaired rather than rejected — otherwise
    /// "ครวรัญญา" silently becomes the subject of its cell.
    static func teacher(in text: String) -> TeacherReading? {
        let trimmed = strippingTrailingPunctuation(text)
        guard !trimmed.isEmpty else { return nil }

        let body: String
        let wasRepaired: Bool
        if let range = trimmed.range(of: "ครู"), range.lowerBound == trimmed.startIndex {
            body = String(trimmed[range.upperBound...])
            wasRepaired = false
        } else if let range = trimmed.range(of: "คร"), range.lowerBound == trimmed.startIndex,
                  trimmed.count >= 4 {
            body = String(trimmed[range.upperBound...])
            wasRepaired = true
        } else {
            return nil
        }

        let name = "ครู" + body
        guard !body.isEmpty else {
            return TeacherReading(name: name, needsReview: true, wasRepaired: wasRepaired)
        }
        let hasLatin = body.contains { $0.isASCII && $0.isLetter }
        let hasDigit = body.contains(where: \.isNumber)
        return TeacherReading(
            name: name,
            needsReview: hasLatin || hasDigit || body.count < 2,
            wasRepaired: wasRepaired
        )
    }

    /// Rooms are printed as a bare 3–4 digit number, occasionally with "ห้อง"
    /// in front. Anything else that shares a cell — "นาฏศิลป์", "คณิต 1" — is
    /// left to the free-text path so it can still name an activity cell.
    static func isRoom(_ text: String) -> Bool {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "ห้อง"), range.lowerBound == trimmed.startIndex {
            trimmed = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        guard (3...4).contains(trimmed.count), Int(trimmed) != nil else { return false }
        return true
    }

    // MARK: - Same person, different spelling

    /// Maps every teacher label onto one canonical spelling: labels within a
    /// single edit are the same person ("ครูจริยา" / "ครูจาริยา" differ only by
    /// a dropped า). The spelling Vision produced most often wins, because
    /// dropping a character is the common failure and it rarely drops the same
    /// one twice.
    ///
    /// This has to run before the subject-code vote — that vote leans on
    /// "one teacher teaches one subject", which two spellings of one teacher
    /// would quietly break.
    static func canonicalTeacherNames(_ names: [String]) -> [String: String] {
        var counts: [String: Int] = [:]
        for name in names { counts[name, default: 0] += 1 }

        let ordered = counts.keys.sorted { lhs, rhs in
            let left = counts[lhs] ?? 0
            let right = counts[rhs] ?? 0
            return left != right ? left > right : lhs < rhs
        }

        var canonical: [String] = []
        var mapping: [String: String] = [:]
        for name in ordered {
            let match = canonical.first { existing in
                // Short labels are excluded: at 3 characters a single edit is
                // most of the name, so "ครูก" and "ครูข" would merge.
                min(existing.count, name.count) >= 5 && editDistance(existing, name) <= 1
            }
            if let match {
                mapping[name] = match
            } else {
                canonical.append(name)
                mapping[name] = name
            }
        }
        return mapping
    }

    /// Levenshtein distance over grapheme clusters, so a Thai vowel sign counts
    /// as part of its consonant rather than as a character of its own.
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        var previous = Array(0...right.count)
        var current = [Int](repeating: 0, count: right.count + 1)
        for i in 1...left.count {
            current[0] = i
            for j in 1...right.count {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[right.count]
    }

    // MARK: - Helpers

    private static func strippingTrailingPunctuation(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = trimmed.last, last == "." || last == "," || last == "·" || last == "ฯ" {
            trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
