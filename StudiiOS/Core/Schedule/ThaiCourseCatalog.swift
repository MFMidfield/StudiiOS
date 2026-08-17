//
//  ThaiCourseCatalog.swift
//  The fixed subject list the app offers instead of a free-text field:
//  8 learning areas (กลุ่มสาระการเรียนรู้) + กิจกรรมพัฒนาผู้เรียน, each with the
//  courses a Thai upper-secondary student actually sits.
//
//  This is the ONE place course names are listed. `ThaiSubjectStrand.commonSubjects`
//  reads from here too, so the OCR review dropdown and the manual pickers can never
//  drift apart. Add a course = add it here, nowhere else.
//
//  Groups are not the same thing as strands: the ministry counts every foreign
//  language as ONE area (ภาษาต่างประเทศ), while ThaiSubjectStrand keeps them apart
//  because each has its own code letter, icon and colour. So a group owns a list
//  of strands, and `strand(forCourse:)` maps back down to the exact one.
//
//  Pure logic — no View, no SwiftData. Safe to call from anywhere.
//

import Foundation

// MARK: - Group

/// One row in the "เลือกกลุ่มสาระ" list.
nonisolated struct ThaiCourseGroup: Identifiable, Hashable {
    let id: String
    let name: String
    /// Ordered — the first strand supplies the group's icon and colour.
    let strands: [ThaiSubjectStrand]

    var iconName: String { strands[0].iconName }
    var colorHex: String { strands[0].colorHex }

    /// Every course in the group, strand by strand, in declaration order.
    var courses: [String] {
        strands.flatMap { ThaiCourseCatalog.courses(for: $0) }
    }
}

// MARK: - Catalog

nonisolated enum ThaiCourseCatalog {

    /// The 8 learning areas plus กิจกรรมพัฒนาผู้เรียน, in the ministry's order.
    static let groups: [ThaiCourseGroup] = [
        ThaiCourseGroup(id: "thai", name: "ภาษาไทย", strands: [.thai]),
        ThaiCourseGroup(id: "math", name: "คณิตศาสตร์", strands: [.math]),
        ThaiCourseGroup(id: "science", name: "วิทยาศาสตร์และเทคโนโลยี", strands: [.science]),
        ThaiCourseGroup(id: "social", name: "สังคมศึกษา ศาสนา และวัฒนธรรม", strands: [.social]),
        ThaiCourseGroup(id: "health", name: "สุขศึกษาและพลศึกษา", strands: [.health]),
        ThaiCourseGroup(id: "arts", name: "ศิลปะ", strands: [.arts]),
        ThaiCourseGroup(id: "career", name: "การงานอาชีพ", strands: [.career]),
        ThaiCourseGroup(id: "language", name: "ภาษาต่างประเทศ",
                        strands: [.english, .chinese, .japanese, .french, .german]),
        ThaiCourseGroup(id: "activity", name: "กิจกรรมพัฒนาผู้เรียน", strands: [.activity]),
    ]

    /// The courses offered under one strand. Kept identical to what the OCR
    /// review dropdown used to hold — this list IS that list now.
    static func courses(for strand: ThaiSubjectStrand) -> [String] {
        switch strand {
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
            return [strand.displayName]
        }
    }

    /// Every course in the catalog paired with the strand it came from.
    static let allCourses: [(name: String, strand: ThaiSubjectStrand)] =
        ThaiSubjectStrand.allCases.flatMap { strand in
            courses(for: strand).map { (name: $0, strand: strand) }
        }

    private static let strandsByCourse: [String: ThaiSubjectStrand] = {
        var map: [String: ThaiSubjectStrand] = [:]
        // First writer wins so a name shared by two strands keeps the earlier
        // (more specific) one — declaration order in ThaiSubjectStrand is the rule.
        for course in allCourses where map[course.name] == nil {
            map[course.name] = course.strand
        }
        return map
    }()

    /// nil = a name the student typed themselves. The caller decides the colour
    /// (see `ThaiSubjectCatalog.appearance`), it is never guessed here.
    static func strand(forCourse name: String) -> ThaiSubjectStrand? {
        strandsByCourse[name.trimmingCharacters(in: .whitespaces)]
    }

    static func group(id: String) -> ThaiCourseGroup? {
        groups.first { $0.id == id }
    }

    /// The group a course belongs to, via its strand.
    static func group(forCourse name: String) -> ThaiCourseGroup? {
        guard let strand = strand(forCourse: name) else { return nil }
        return groups.first { $0.strands.contains(strand) }
    }
}
