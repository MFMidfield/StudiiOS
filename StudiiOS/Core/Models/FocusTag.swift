//
//  FocusTag.swift
//  แท็กของรอบโฟกัส (เรียน · ทำงาน · อื่นๆ · ที่ผู้ใช้เพิ่มเอง)
//
//  `FocusSession` **ไม่ได้** ผูก relation กับ model ตัวนี้ — มันเก็บสำเนา
//  (`tagID` / `tagName` / `tagColorHex`) ไว้ในตัวเอง จงใจ เพื่อว่า
//  1. เพิ่มฟิลด์ String ที่มี default = SwiftData migrate ให้เอง ไม่ต้องลบแอป
//  2. ลบแท็กทิ้งแล้วสถิติเก่ายังอ่านออก (ชื่อ/สี ณ ตอนนั้นยังอยู่)
//  การจัดกลุ่มในหน้าสถิติใช้ `tagID` เป็นกุญแจ ไม่ใช่ชื่อ
//

import Foundation
import SwiftData

@Model
final class FocusTag {
    /// รหัสถาวรของแท็ก — `FocusSession.tagID` อ้างค่านี้
    var id: String = UUID().uuidString
    var name: String = ""
    var colorHex: String = ""
    /// ลำดับที่แสดงในแถบแท็ก
    var order: Int = 0
    var createdAt: Date = Date.now

    init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String,
        order: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.order = order
        self.createdAt = createdAt
    }

    var snapshot: FocusTagSnapshot {
        FocusTagSnapshot(id: id, name: name, colorHex: colorHex)
    }

    /// ชื่อ 3 แท็กเริ่มต้น — สีถูกส่งเข้ามาจากฝั่ง View (Theme อยู่ชั้น DesignSystem
    /// ไฟล์ model ไม่ import SwiftUI)
    static let defaultNames = ["เรียน", "ทำงาน", "อื่นๆ"]

    /// สร้าง 3 แท็กเริ่มต้นครั้งแรกที่เปิดหน้าโฟกัส — เรียกซ้ำได้ ไม่สร้างซ้ำ
    @MainActor
    static func seedDefaultsIfNeeded(in context: ModelContext, colors: [String]) {
        let existing = (try? context.fetchCount(FetchDescriptor<FocusTag>())) ?? 0
        guard existing == 0, !colors.isEmpty else { return }
        for (index, name) in defaultNames.enumerated() {
            context.insert(
                FocusTag(name: name, colorHex: colors[index % colors.count], order: index)
            )
        }
        try? context.save()
    }
}

/// สำเนาแท็กแบบไม่พึ่ง SwiftData — ใช้ส่งเข้า `PomodoroEngine`
/// (engine เก็บสถานะลง UserDefaults เพื่อกู้หลัง force-quit จึงต้อง Codable)
struct FocusTagSnapshot: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var colorHex: String
}
