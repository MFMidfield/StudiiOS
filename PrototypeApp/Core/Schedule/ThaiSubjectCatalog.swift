//
//  ThaiSubjectCatalog.swift
//  The Thai subject-code grammar expressed as data: which strand a code
//  belongs to, what to call it, and how it should look in the timetable.
//
//  A code carries less than it appears to. "ว30203" proves the subject is in
//  the science strand and is an elective, but it cannot tell ฟิสิกส์ from เคมี
//  from ชีววิทยา — every science elective in a school shares that prefix. So
//  `generatedName` deliberately returns the *category*, never a real subject
//  name, and the caller marks the row `nameIsGuessed` so the user is asked.
//  `commonSubjects` is what that question offers as answers.
//
//  Pure logic — no View, no SwiftData, no Vision. Safe to call from anywhere.
//

import Foundation

// MARK: - Strand

/// The leading consonant of a Thai subject code, and everything that follows
/// from it. Letters come from the ministry's own numbering, so they are fixed.
// nonisolated: reachable from the OCR pipeline, which runs off the main thread.
nonisolated enum ThaiSubjectStrand: String, CaseIterable, Identifiable {
    case thai, math, science, social, health, arts, career, activity
    case english, chinese, japanese, french, german

    var id: String { rawValue }

    var letter: Character {
        switch self {
        case .thai: return "ท"
        case .math: return "ค"
        case .science: return "ว"
        case .social: return "ส"
        case .health: return "พ"
        case .arts: return "ศ"
        case .career: return "ง"
        // ก is the ministry's letter for กิจกรรมพัฒนาผู้เรียน (ก20901 แนะแนว,
        // ก20902 ชุมนุม) — not for ภาษาเกาหลี, which schools code differently.
        case .activity: return "ก"
        case .english: return "อ"
        case .chinese: return "จ"
        case .japanese: return "ญ"
        case .french: return "ฝ"
        case .german: return "ย"
        }
    }

    /// Short form. `generatedName` appends พื้นฐาน / เพิ่มเติม to this.
    var displayName: String {
        switch self {
        case .thai: return "ภาษาไทย"
        case .math: return "คณิตศาสตร์"
        case .science: return "วิทยาศาสตร์"
        case .social: return "สังคมศึกษา"
        case .health: return "สุขศึกษาและพลศึกษา"
        case .arts: return "ศิลปะ"
        case .career: return "การงานอาชีพ"
        case .activity: return "กิจกรรมพัฒนาผู้เรียน"
        case .english: return "ภาษาอังกฤษ"
        case .chinese: return "ภาษาจีน"
        case .japanese: return "ภาษาญี่ปุ่น"
        case .french: return "ภาษาฝรั่งเศส"
        case .german: return "ภาษาเยอรมัน"
        }
    }

    var iconName: String {
        switch self {
        case .thai: return "book.closed.fill"
        case .math: return "function"
        case .science: return "atom"
        case .social: return "globe.asia.australia.fill"
        case .health: return "figure.run"
        case .arts: return "paintpalette.fill"
        case .career: return "hammer.fill"
        case .activity: return "person.3.fill"
        case .english: return "textformat.abc"
        case .chinese, .japanese, .french, .german: return "globe"
        }
    }

    /// Always a member of `Theme.Colors.subjectPaletteHex` — an imported
    /// subject must not introduce a colour the manual flow cannot produce.
    var colorHex: String {
        switch self {
        case .thai, .chinese: return "FF6B6B"
        case .math: return "4A7DFF"
        case .science: return "4CAF50"
        case .social: return "FFB347"
        case .health, .german: return "00BCD4"
        case .arts, .japanese: return "E91E63"
        case .career, .activity: return "9C27B0"
        case .english, .french: return "3F51B5"
        }
    }

    /// Suggestions for the review sheet's name dropdown. A convenience list,
    /// never a constraint — the name field is always editable and always wins.
    var commonSubjects: [String] {
        switch self {
        case .thai:
            return ["หลักภาษาไทย", "วรรณคดีและวรรณกรรม", "การอ่านและการเขียน", "การเขียนเชิงสร้างสรรค์"]
        case .math:
            return ["คณิตศาสตร์พื้นฐาน", "คณิตศาสตร์เพิ่มเติม", "สถิติ", "แคลคูลัสเบื้องต้น"]
        case .science:
            return [
                "ฟิสิกส์", "เคมี", "ชีววิทยา", "วิทยาศาสตร์กายภาพ", "วิทยาศาสตร์ชีวภาพ",
                "โลก ดาราศาสตร์ และอวกาศ", "วิทยาการคำนวณ", "การออกแบบและเทคโนโลยี",
            ]
        case .social:
            return ["สังคมศึกษา", "ประวัติศาสตร์", "พระพุทธศาสนา", "หน้าที่พลเมือง", "เศรษฐศาสตร์", "ภูมิศาสตร์"]
        case .health:
            return ["สุขศึกษา", "พลศึกษา"]
        case .arts:
            return ["ทัศนศิลป์", "ดนตรี", "นาฏศิลป์"]
        case .career:
            return ["การงานอาชีพ", "คหกรรม", "งานช่าง", "งานเกษตร", "ธุรกิจและการเป็นผู้ประกอบการ"]
        case .activity:
            return ["แนะแนว", "ชุมนุม", "กิจกรรมในเครื่องแบบ", "ลูกเสือ-เนตรนารี", "ยุวกาชาด", "บำเพ็ญประโยชน์"]
        case .english:
            return ["ภาษาอังกฤษพื้นฐาน", "ภาษาอังกฤษเพิ่มเติม", "ภาษาอังกฤษฟัง-พูด", "ภาษาอังกฤษอ่าน-เขียน"]
        case .chinese, .japanese, .french, .german:
            return [displayName]
        }
    }
}

/// A code that passed the grammar check and belongs to a strand we know.
// nonisolated: reachable from the OCR pipeline, which runs off the main thread.
nonisolated struct ParsedSubjectCode {
    let raw: String
    let strand: ThaiSubjectStrand
    /// Digit 3 of the five: 1 = พื้นฐาน, 2 = เพิ่มเติม.
    let isAdditional: Bool
}

// MARK: - Catalog

// nonisolated: reachable from the OCR pipeline, which runs off the main thread.
nonisolated enum ThaiSubjectCatalog {

    private static let strandsByLetter: [Character: ThaiSubjectStrand] = {
        var map: [Character: ThaiSubjectStrand] = [:]
        for strand in ThaiSubjectStrand.allCases { map[strand.letter] = strand }
        return map
    }()

    /// nil when `code` is not a well-formed Thai subject code, or its leading
    /// consonant is not a strand we know. The grammar itself lives in
    /// `SubjectCodeValidator` and is not re-implemented here.
    static func parse(_ code: String) -> ParsedSubjectCode? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SubjectCodeValidator.isValid(trimmed),
              let letter = trimmed.first,
              let strand = strandsByLetter[letter]
        else { return nil }
        // isValid guarantees exactly five digits follow.
        let digits = Array(trimmed.dropFirst())
        return ParsedSubjectCode(raw: trimmed, strand: strand, isAdditional: digits[2] == "2")
    }

    /// "ว30203" → "วิทยาศาสตร์เพิ่มเติม" · "ค32101" → "คณิตศาสตร์พื้นฐาน".
    /// A category, not a subject name — see the file header for why.
    ///
    /// กิจกรรมพัฒนาผู้เรียน is the exception: it has no พื้นฐาน/เพิ่มเติม split,
    /// so appending one would invent a category that does not exist.
    static func generatedName(for parsed: ParsedSubjectCode) -> String {
        guard parsed.strand != .activity else { return parsed.strand.displayName }
        return parsed.strand.displayName + (parsed.isAdditional ? "เพิ่มเติม" : "พื้นฐาน")
    }

    /// Icon and colour for a subject. A name the user actually chose beats the
    /// strand's generic icon; the colour stays the strand's either way, so one
    /// strand still reads as one colour family down the timetable.
    static func appearance(
        strand: ThaiSubjectStrand?, name: String
    ) -> (iconName: String, colorHex: String) {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let override = nameOverrides[key] {
            return (override.iconName, (strand ?? override.strand).colorHex)
        }
        if let strand { return (strand.iconName, strand.colorHex) }
        return (fallbackIcon, fallbackColorHex)
    }

    /// Icon overrides for names from `commonSubjects`. Each carries its own
    /// strand so a hand-typed name with no code still gets a sensible colour.
    private static let nameOverrides: [String: (iconName: String, strand: ThaiSubjectStrand)] = [
        "ฟิสิกส์": ("atom", .science),
        "เคมี": ("flask.fill", .science),
        "ชีววิทยา": ("leaf.fill", .science),
        "วิทยาการคำนวณ": ("desktopcomputer", .science),
        "การออกแบบและเทคโนโลยี": ("hammer.fill", .science),
        "ประวัติศาสตร์": ("flag.fill", .social),
        "หน้าที่พลเมือง": ("person.3.fill", .social),
        "ดนตรี": ("music.note", .arts),
        "ทัศนศิลป์": ("paintpalette.fill", .arts),
        "คหกรรม": ("fork.knife", .career),
        "สุขศึกษา": ("heart.fill", .health),
        "พลศึกษา": ("figure.run", .health),
        "แนะแนว": ("signpost.right.fill", .activity),
        "ชุมนุม": ("person.3.fill", .activity),
        "กิจกรรมในเครื่องแบบ": ("figure.hiking", .activity),
        "ลูกเสือ-เนตรนารี": ("figure.hiking", .activity),
        "ยุวกาชาด": ("cross.case.fill", .activity),
    ]

    private static let fallbackIcon = "book.closed.fill"
    private static let fallbackColorHex = "4A7DFF"

    // MARK: Breaks and activities

    // Only the slots where no class happens. แนะแนว / ชุมนุม / กิจกรรมในเครื่องแบบ
    // / ลูกเสือ are real periods with a period number and a teacher — they get
    // shifted like any other subject, so they must not land here.
    private static let breakKeywords = ["พัก", "กลางวัน", "โฮมรูม"]

    /// True for the cells that are not a subject at all. Substring match,
    /// because OCR delivers these with the school's own wording attached
    /// ("พักกลางวัน", "โฮมรูม (ครูประจำชั้น)").
    static func isBreakLabel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return breakKeywords.contains { trimmed.localizedCaseInsensitiveContains($0) }
    }

    /// Breaks all share one colour so they read as a single band across the
    /// week; only lunch gets its own icon.
    static func breakAppearance(for name: String) -> (iconName: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMeal = trimmed.localizedCaseInsensitiveContains("พัก")
            || trimmed.localizedCaseInsensitiveContains("กลางวัน")
        return (isMeal ? "fork.knife" : "person.3.fill", "FFB347")
    }
}
