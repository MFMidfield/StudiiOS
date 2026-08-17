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

// nonisolated: runs off the main thread inside Vision's completion handler.
nonisolated enum CellFieldValidator {

    /// A teacher label as read off the sheet, after normalization.
    struct TeacherReading {
        /// Normalized label. Thai names always start with "ครู"; a foreign
        /// teacher printed as "T.Kathleen" keeps the form the sheet used,
        /// because forcing a "ครู" onto it would invent a spelling nobody
        /// wrote and split the same person into two canonical names.
        let name: String
        /// True when the label itself is doubtful — a digit where a name
        /// belongs, or nothing left after the prefix.
        let needsReview: Bool
        /// True when the "ครู" prefix had to be restored.
        let wasRepaired: Bool
    }

    /// Prefixes that mark a foreign teacher. Both reference sheets print them:
    /// "T.Kathleen" in the cells, "ครู Kathleen Baldazan Bandao" in the header.
    /// The list stays closed on purpose — an open rule like "starts with a
    /// capital letter" would swallow room codes such as "Com3".
    private static let latinTeacherPrefixes = ["Teacher", "Mrs.", "Mr.", "Ms.", "T."]

    /// Thai timetables prefix every teacher with "ครู", and that prefix is the
    /// only reliable way to tell a teacher line from a subject name. So a
    /// dropped สระ ู has to be repaired rather than rejected — otherwise
    /// "ครวรัญญา" silently becomes the subject of its cell.
    ///
    /// A Latin letter in the body is NOT a defect: a school that employs a
    /// native speaker prints that teacher's name in Latin script on every row
    /// they teach. Flagging those was flagging a correct reading.
    static func teacher(in text: String) -> TeacherReading? {
        let trimmed = strippingTrailingPunctuation(text)
        guard !trimmed.isEmpty else { return nil }
        if let latin = latinTeacher(trimmed) { return latin }

        let body: String
        let wasRepaired: Bool
        if let range = trimmed.range(of: "ครู"), range.lowerBound == trimmed.startIndex {
            body = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            wasRepaired = false
        } else if let range = trimmed.range(of: "คร"), range.lowerBound == trimmed.startIndex,
                  trimmed.count >= 4 {
            body = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            wasRepaired = true
        } else {
            return nil
        }

        // "ครูสมชาย" runs together, "ครู Kathleen" does not — keep the space
        // the sheet printed rather than gluing scripts to each other.
        let separator = (body.first?.isASCII ?? false) ? " " : ""
        let name = "ครู" + separator + body
        guard !body.isEmpty else {
            return TeacherReading(name: "ครู", needsReview: true, wasRepaired: wasRepaired)
        }
        return TeacherReading(
            name: name,
            needsReview: body.contains(where: \.isNumber) || body.count < 2,
            wasRepaired: wasRepaired
        )
    }

    private static func latinTeacher(_ trimmed: String) -> TeacherReading? {
        for prefix in latinTeacherPrefixes where trimmed.hasPrefix(prefix) {
            let body = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            guard body.count >= 2, body.first?.isLetter == true else { return nil }
            return TeacherReading(
                name: trimmed,
                needsReview: body.contains(where: \.isNumber),
                wasRepaired: false
            )
        }
        return nil
    }

    /// Rooms that are named rather than numbered. Matched as a prefix so
    /// "โรงยิม 2" still counts.
    private static let roomKeywords = [
        "โรงยิม", "โรงอาหาร", "หอประชุม", "สนาม", "ลานกีฬา", "สระว่ายน้ำ", "โดม", "ศาลา",
    ]

    /// Rooms are usually a bare 3–4 digit number, but the two reference sheets
    /// between them also print "ห้องดนตรีไทย", "Com3", "โรงยิม" and
    /// "นาฏศิลป์2". Every one of those used to fail this test and fall through
    /// to the free-text path, where it either became the subject name of its
    /// cell or was thrown away next to a code that had already claimed the name.
    ///
    /// Each accepted form still has to be *shaped* like a place — a keyword, a
    /// "ห้อง" prefix, or a name ending in a number. Bare activity words
    /// ("ชุมนุม", "ลูกเสือ", "แนะแนว") match none of them and stay free text,
    /// which is what keeps activity-only cells from losing their label.
    static func isRoom(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 14 else { return false }

        if let range = trimmed.range(of: "ห้อง"), range.lowerBound == trimmed.startIndex {
            return !String(trimmed[range.upperBound...])
                .trimmingCharacters(in: .whitespaces).isEmpty
        }
        if roomKeywords.contains(where: { trimmed.hasPrefix($0) }) { return true }
        if (3...4).contains(trimmed.count), Int(trimmed) != nil { return true }

        // "Com3", "Lab2", "A101" — Latin and digits, no separators, both present.
        if trimmed.count <= 8,
           trimmed.allSatisfy({ ($0.isASCII && $0.isLetter) || isDigit($0) }),
           trimmed.contains(where: { $0.isASCII && $0.isLetter }),
           trimmed.contains(where: isDigit) {
            return true
        }

        // "นาฏศิลป์2" — a Thai name with the room's number stuck on the end.
        // The head must be pure Thai script, so "ม.4" (a class label) and
        // "08.30" (a time) do not qualify.
        let head = trimmed.prefix { !isDigit($0) }
        if head.count >= 2, head.count < trimmed.count,
           head.allSatisfy(isThai),
           trimmed.dropFirst(head.count).allSatisfy(isDigit) {
            return true
        }
        return false
    }

    /// ASCII digit only — `Character.isNumber` also matches Thai digits and
    /// superscripts, which is not what any of these shape tests mean.
    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    /// Every scalar sits in the Thai block. Written over scalars rather than
    /// `isLetter` because a Thai grapheme cluster carries combining vowel and
    /// tone marks that are not letters on their own.
    private static func isThai(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x0E01...0x0E5B).contains($0.value) }
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
