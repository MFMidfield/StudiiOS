//
//  FacultyMapping.swift
//  Dimension → Thai faculty (TCAS naming) mapping for the RIASEC result
//  screen. This is an expert-authored mapping, not an empirical study —
//  see PLAN_RIASEC.md §8. Deliberately excludes TCAS popularity stats
//  (single-source, dates instantly, adds nothing to the feature).
//

import Foundation

struct FacultyMapping {
    let faculties: [String]
    let focusSubjects: [String]
}

enum FacultyMappingTable {
    static let all: [RIASECDimension: FacultyMapping] = [
        .R: FacultyMapping(
            faculties: ["วิศวกรรมศาสตร์ (เครื่องกล · โยธา · โลจิสติกส์)", "เกษตรศาสตร์", "สัตวแพทยศาสตร์", "วิทยาศาสตร์การกีฬา", "เทคโนโลยีอุตสาหกรรม"],
            focusSubjects: ["ฟิสิกส์", "คณิตศาสตร์", "ชีววิทยา"]
        ),
        .I: FacultyMapping(
            faculties: ["แพทยศาสตร์", "ทันตแพทยศาสตร์", "เภสัชศาสตร์", "วิทยาศาสตร์ (ฟิสิกส์/เคมี/ชีววิทยา)", "วิทยาการคอมพิวเตอร์", "Data Science"],
            focusSubjects: ["คณิตศาสตร์", "เคมี", "ฟิสิกส์", "วิทยาการคำนวณ"]
        ),
        .A: FacultyMapping(
            faculties: ["สถาปัตยกรรมศาสตร์", "นิเทศศาสตร์ (ภาพยนตร์/สื่อดิจิทัล)", "มัณฑนศิลป์", "ศิลปกรรมศาสตร์", "อักษรศาสตร์"],
            focusSubjects: ["ศิลปะ", "ภาษาไทย", "ภาษาต่างประเทศ"]
        ),
        .S: FacultyMapping(
            faculties: ["ครุศาสตร์ / ศึกษาศาสตร์", "พยาบาลศาสตร์", "สหเวชศาสตร์", "จิตวิทยา", "สังคมสงเคราะห์ศาสตร์", "สาธารณสุขศาสตร์"],
            focusSubjects: ["สังคมศึกษา", "ชีววิทยา", "ภาษาไทย"]
        ),
        .E: FacultyMapping(
            faculties: ["บริหารธุรกิจ (การตลาด/การจัดการ)", "นิติศาสตร์", "รัฐศาสตร์", "การจัดการโรงแรมและการท่องเที่ยว", "นิเทศศาสตร์ (โฆษณา/PR)"],
            focusSubjects: ["คณิตศาสตร์", "สังคมศึกษา", "ภาษาอังกฤษ"]
        ),
        .C: FacultyMapping(
            faculties: ["บัญชี", "บริหารธุรกิจ (การเงิน)", "โลจิสติกส์และซัพพลายเชน", "รัฐประศาสนศาสตร์", "สารสนเทศศาสตร์ / สถิติประยุกต์"],
            focusSubjects: ["คณิตศาสตร์ (สถิติ)", "ภาษาอังกฤษ", "วิทยาการคำนวณ"]
        ),
    ]
}
