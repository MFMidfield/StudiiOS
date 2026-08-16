//
//  ThemedForm.swift
//  พื้นหลังของ `Form` / `List` ให้เป็นสีของธีมแอป ไม่ใช่สีเทาของ iOS
//
//  `Form` และ `List` วาดพื้นหลังของตัวเอง (systemGroupedBackground) ทับพื้นที่
//  เราตั้งไว้เสมอ — ต้อง `.scrollContentBackground(.hidden)` ก่อนถึงจะใส่สีเองได้
//  แปะไว้ที่ container เท่านั้น ไม่ต้องแปะรายแถว
//
//  หมายเหตุ: พื้นของ**แถว** (row) ยังเป็นสีของ iOS อยู่ — ถ้าจะให้ตรงธีมเป๊ะ
//  ต้องเติม `.listRowBackground(Theme.Colors.cardBackground)` ราย `Section`
//

import SwiftUI

extension View {
    /// พื้นหลังธีมแอปสำหรับ `Form`/`List` — แปะที่ตัว container
    func themedFormBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
    }
}
