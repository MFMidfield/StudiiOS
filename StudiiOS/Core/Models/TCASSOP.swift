//
//  TCASSOP.swift
//  ฉบับ SOP ของ 1 คณะ — โหมด "single" ก้อนเดียว หรือ "sections" 6 ช่องตามโครงสร้าง.
//  isMerged = true แล้ว กลับไปแก้ทีละส่วนไม่ได้อีก (fullText คือปลายทางเสมอ).
//

import Foundation
import SwiftData

@Model
final class TCASSOP {
    var modeRaw: String = "single"
    var isMerged: Bool = false
    var fullText: String = ""
    var s1Intro: String = ""
    var s2Academic: String = ""
    var s3Projects: String = ""
    var s4WhyHere: String = ""
    var s5Future: String = ""
    var s6Conclusion: String = ""
    var updatedAt: Date = Date.now
    var entry: TCASEntry?

    init(
        modeRaw: String = "single",
        isMerged: Bool = false,
        fullText: String = "",
        s1Intro: String = "",
        s2Academic: String = "",
        s3Projects: String = "",
        s4WhyHere: String = "",
        s5Future: String = "",
        s6Conclusion: String = "",
        updatedAt: Date = .now,
        entry: TCASEntry? = nil
    ) {
        self.modeRaw = modeRaw
        self.isMerged = isMerged
        self.fullText = fullText
        self.s1Intro = s1Intro
        self.s2Academic = s2Academic
        self.s3Projects = s3Projects
        self.s4WhyHere = s4WhyHere
        self.s5Future = s5Future
        self.s6Conclusion = s6Conclusion
        self.updatedAt = updatedAt
        self.entry = entry
    }
}
