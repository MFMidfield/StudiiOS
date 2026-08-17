//
//  SOPDocument.swift
//  ฉบับ SOP ของคณะหนึ่ง — **ก้อนเดียวเท่านั้น**
//
//  แทนที่ `TCASSOP` เดิม (16 ส.ค. 2569): โหมดเขียนทีละส่วน 6 ช่อง (`s1Intro`…`s6Conclusion`
//  · `modeRaw` · `isMerged`) ถูกตัดออกทั้งหมด เหลือ `fullText` ช่องเดียว
//

import Foundation
import SwiftData

@Model
final class SOPDocument {
    var fullText: String
    var updatedAt: Date
    var target: SOPTarget?

    var characterCount: Int { fullText.count }

    init(fullText: String = "", updatedAt: Date = .now, target: SOPTarget? = nil) {
        self.fullText = fullText
        self.updatedAt = updatedAt
        self.target = target
    }
}
