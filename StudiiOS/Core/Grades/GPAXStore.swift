//
//  GPAXStore.swift
//  ตัวส่งสัญญาณ "ค่า GPAX ใน UserDefaults เพิ่งเปลี่ยน" ให้ View วาดใหม่
//
//  ทำไมต้องมี: `GPAXSettings` เป็น `enum` ที่มีแต่ static — View อ่านค่าผ่านมันแล้ว
//  SwiftUI ไม่มีทางรู้ว่าค่าเปลี่ยน ของเดิมใช้ "ping pattern" คือประกาศ `@AppStorage`
//  ที่ไม่ได้อ่านค่าไว้ในหน้า ซึ่ง**พึ่งไม่ได้** — ตั้งเป้า GPAX แล้วหน้าเกรดไม่อัปเดต
//  จนกว่าจะออกแล้วเข้าใหม่ (บั๊กที่ Few เจอ 16 ส.ค. 2569)
//
//  วิธีใช้: View ที่แสดงตัวเลข GPAX ประกาศ `@State private var gpaxStore = GPAXStore.shared`
//  แล้ว **อ่าน `gpaxStore.revision` ใน body** (อ่านเฉยๆ ก็พอ) — ทุกครั้งที่ `GPAXSettings`
//  เขียนค่า มันจะ `bump()` ให้เอง
//

import Foundation

@Observable
final class GPAXStore {
    static let shared = GPAXStore()
    private init() {}

    /// เพิ่มทีละ 1 ทุกครั้งที่ค่าใน `GPAXSettings` ถูกเขียน
    private(set) var revision = 0

    func bump() { revision &+= 1 }
}
