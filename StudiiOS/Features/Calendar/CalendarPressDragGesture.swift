//
//  CalendarPressDragGesture.swift
//  กดค้างแล้วลาก — ห่อ UILongPressGestureRecognizer
//
//  ทำไมไม่ใช้ `LongPressGesture.sequenced(before: DragGesture)` ของ SwiftUI:
//  ตัวนั้นจับนิ้วตั้งแต่แตะแรก ScrollView เลยเลื่อนไม่ได้ทั้งผืนตาราง
//  ส่วน recognizer ของ UIKit จะยังไม่แย่งนิ้วจนกว่าจะกดค้างครบเวลา
//  (ขยับเกิน `allowableMovement` ก่อน = ยกเลิกตัวเอง ปล่อยให้ ScrollView เลื่อน)
//  แถม `LongPressGesture` ของ SwiftUI ไม่บอกตำแหน่งนิ้ว ซึ่ง ghost drag ต้องใช้
//

import SwiftUI
import UIKit

struct CalendarPressDragGesture: UIGestureRecognizerRepresentable {
    /// ระบบพิกัดที่ผู้เรียกอยากได้ตำแหน่งนิ้ว — ต้องเป็นชื่อเดียวกับที่ประกาศ
    /// `.coordinateSpace(.named(...))` ไว้บน view ที่ใช้คำนวณช่องวัน
    let space: NamedCoordinateSpace
    var minimumPressDuration: TimeInterval = 0.5
    /// ระยะที่ขยับได้ก่อนกดครบเวลา — เกินกว่านี้ถือว่าผู้ใช้ตั้งใจเลื่อนหน้า
    var allowableMovement: CGFloat = 12

    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    /// `nil` = ยกเลิก/ล้มเหลว (เช่นสายเรียกเข้าตัดจังหวะ) → ฝั่งเรียกใช้ต้อง flyBack
    let onEnded: (CGPoint?) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.allowableMovement = allowableMovement
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        // ห้ามใช้ `recognizer.location(in: recognizer.view)` — view ที่ SwiftUI
        // แปะ recognizer ไว้เป็น host view ก้อนใหญ่ ไม่ใช่ตารางเดือน
        // (เคยทำให้ ghost ลงต่ำกว่านิ้วหนึ่งแถวเต็มๆ) ต้องแปลงผ่าน converter
        let point = context.converter.location(in: space)

        switch recognizer.state {
        case .began:
            onBegan(point)
        case .changed:
            onChanged(point)
        case .ended:
            onEnded(point)
        case .cancelled, .failed:
            onEnded(nil)
        default:
            break
        }
    }
}
