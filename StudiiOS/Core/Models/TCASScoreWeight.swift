//
//  TCASScoreWeight.swift
//  น้ำหนัก % ของ 1 วิชา ในคณะ 1 อัน — ผู้ใช้กรอกเองจากระเบียบการ.
//  groupName ว่าง = โหมดรายวิชา · มีค่า = อยู่ในกลุ่ม (groupPercent เก็บซ้ำทุกแถวในกลุ่ม)
//

import Foundation
import SwiftData

@Model
final class TCASScoreWeight {
    var examCode: String
    var percent: Double
    var groupName: String = ""
    var groupPercent: Double = 0
    var entry: TCASEntry?

    init(
        examCode: String,
        percent: Double,
        groupName: String = "",
        groupPercent: Double = 0,
        entry: TCASEntry? = nil
    ) {
        self.examCode = examCode
        self.percent = percent
        self.groupName = groupName
        self.groupPercent = groupPercent
        self.entry = entry
    }
}
