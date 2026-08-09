//
//  RIASECItem.swift
//  The 18-item RIASEC screening inventory. Presentation order = id order,
//  interleaved R,I,A,S,E,C so a student cannot pattern-answer by dimension.
//  Weights are balanced so every dimension receives exactly 1.0 of
//  secondary weight (see PLAN_RIASEC.md §2.2 — RIASECScorerTests asserts
//  this invariant; do not edit this table without re-checking §2.3).
//

import Foundation

struct RIASECItem {
    let id: Int
    let text: String
    let primary: RIASECDimension
    let primaryWeight: Double
    let secondary: RIASECDimension
    let secondaryWeight: Double

    static let all: [RIASECItem] = [
        RIASECItem(id: 1, text: "ซ่อมแซมสิ่งของเครื่องใช้ที่พังให้กลับมาใช้งานได้", primary: .R, primaryWeight: 1.0, secondary: .I, secondaryWeight: 0.4),
        RIASECItem(id: 2, text: "ทำการทดลองวิทยาศาสตร์เพื่อหาสาเหตุของปรากฏการณ์ต่างๆ", primary: .I, primaryWeight: 1.0, secondary: .R, secondaryWeight: 0.4),
        RIASECItem(id: 3, text: "ออกแบบป้ายประกาศหรือภาพกราฟิกให้สวยงาม", primary: .A, primaryWeight: 1.0, secondary: .R, secondaryWeight: 0.3),
        RIASECItem(id: 4, text: "เป็นพี่เลี้ยงอาสาคอยดูแลรุ่นน้องในค่ายของโรงเรียน", primary: .S, primaryWeight: 1.0, secondary: .E, secondaryWeight: 0.3),
        RIASECItem(id: 5, text: "เป็นผู้นำแบ่งงานในกลุ่ม และกระตุ้นให้เพื่อนทำงานจนสำเร็จ", primary: .E, primaryWeight: 1.0, secondary: .S, secondaryWeight: 0.4),
        RIASECItem(id: 6, text: "จัดทำบัญชีรายรับรายจ่ายของห้องเรียนให้ครบถ้วนแม่นยำ", primary: .C, primaryWeight: 1.0, secondary: .E, secondaryWeight: 0.4),
        RIASECItem(id: 7, text: "ช่วยติดตั้งและควบคุมเครื่องเสียงในงานกิจกรรมของโรงเรียน", primary: .R, primaryWeight: 1.0, secondary: .S, secondaryWeight: 0.3),
        RIASECItem(id: 8, text: "เขียนโค้ดเพื่อสร้างโปรแกรมคอมพิวเตอร์เบื้องต้น", primary: .I, primaryWeight: 1.0, secondary: .C, secondaryWeight: 0.4),
        RIASECItem(id: 9, text: "แต่งเรื่องสั้นหรือคิดพล็อตสำหรับการแสดงละคร", primary: .A, primaryWeight: 1.0, secondary: .S, secondaryWeight: 0.3),
        RIASECItem(id: 10, text: "ติวหรืออธิบายเนื้อหาที่ยากให้เพื่อนเข้าใจ", primary: .S, primaryWeight: 1.0, secondary: .I, secondaryWeight: 0.3),
        RIASECItem(id: 11, text: "คิดแคมเปญเชิญชวนให้คนมาเข้าร่วมกิจกรรมของชมรม", primary: .E, primaryWeight: 1.0, secondary: .A, secondaryWeight: 0.3),
        RIASECItem(id: 12, text: "ตรวจสอบความถูกต้องของข้อมูลในรายงานก่อนส่งครู", primary: .C, primaryWeight: 1.0, secondary: .I, secondaryWeight: 0.3),
        RIASECItem(id: 13, text: "ดูแลแปลงเกษตรหรือปลูกต้นไม้ในโครงการของโรงเรียน", primary: .R, primaryWeight: 1.0, secondary: .C, secondaryWeight: 0.3),
        RIASECItem(id: 14, text: "ค้นหาข้อมูลจากหลายแหล่งเพื่อทำรายงานเชิงลึกในหัวข้อที่สนใจ", primary: .I, primaryWeight: 1.0, secondary: .A, secondaryWeight: 0.4),
        RIASECItem(id: 15, text: "ตัดต่อคลิปวิดีโอเพื่อเล่าเรื่องราวที่อยากสื่อสาร", primary: .A, primaryWeight: 1.0, secondary: .E, secondaryWeight: 0.3),
        RIASECItem(id: 16, text: "รับฟังปัญหาของเพื่อนและช่วยให้กำลังใจเมื่อเพื่อนท้อ", primary: .S, primaryWeight: 1.0, secondary: .A, secondaryWeight: 0.3),
        RIASECItem(id: 17, text: "เป็นตัวแทนพูดโน้มน้าวหรือเจรจาเพื่อรักษาสิทธิ์ของนักเรียน", primary: .E, primaryWeight: 1.0, secondary: .C, secondaryWeight: 0.3),
        RIASECItem(id: 18, text: "จัดหมวดหมู่เอกสารหรือไฟล์ให้เป็นระเบียบค้นหาง่าย", primary: .C, primaryWeight: 1.0, secondary: .R, secondaryWeight: 0.3),
    ]

    static let likertLabels: [Int: String] = [
        1: "ไม่ชอบเลย",
        2: "ไม่ค่อยชอบ",
        3: "เฉยๆ",
        4: "ค่อนข้างชอบ",
        5: "ชอบมาก",
    ]
}
