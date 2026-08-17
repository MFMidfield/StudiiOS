//
//  MonthLayoutEngine.swift
//  จัดเลนแถบกิจกรรมในหนึ่งแถวสัปดาห์ของปฏิทินเดือน
//
//  ฟังก์ชันบริสุทธิ์ ไม่ import SwiftUI / SwiftData — เทสต์ได้โดยไม่ต้องมี
//  ModelContainer แบบเดียวกับ GPAXCalculator และ RIASECScorer
//  สเปค: docs/redesign/08_Calendar.md §4
//

import Foundation

// ══════════════════════════════════════════════════════════════
// MARK: - ขาเข้า
// ══════════════════════════════════════════════════════════════

/// รายการหนึ่งชิ้นที่รอจัดเลน — เก็บแค่ "ช่วงวัน + ลำดับ" ไม่มีสี ไม่มีชื่อ
/// ฝั่ง View เอา `id` ไปเปิดตาราง `CalendarItem` ของตัวเองต่อเอง
///
/// - `startDay` / `endDay` เป็น **วันแบบรวมปลาย (inclusive)** ทั้งคู่
///   กิจกรรมทั้งวันของ `CalendarEvent` เก็บ `endDate` แบบ *ไม่รวมปลาย*
///   (เที่ยงคืนของวันถัดไป) → ฝั่งที่แปลงข้อมูลต้องลบออกหนึ่งวันก่อนส่งเข้ามา
struct MonthLayoutItem: Equatable {
    let id: String
    let startDay: Date
    let endDay: Date
    /// สอบ → การบ้าน → กิจกรรม (ใช้ `CalendarItem.sortRank` ได้ตรงๆ)
    let sortRank: Int
    /// ตัวตัดสินสุดท้ายตอน span และคอลัมน์เริ่มเท่ากัน
    let createdAt: Date

    init(id: String, startDay: Date, endDay: Date, sortRank: Int = 0, createdAt: Date = .distantPast) {
        self.id = id
        self.startDay = startDay
        self.endDay = endDay
        self.sortRank = sortRank
        self.createdAt = createdAt
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - ขาออก
// ══════════════════════════════════════════════════════════════

struct LaidOutBar: Equatable {
    let itemID: String
    let lane: Int          // 0...maxLanes-1
    let startColumn: Int   // 0...6
    let columnSpan: Int    // 1...7
    /// วันเริ่มจริงอยู่ก่อนวันแรกของสัปดาห์นี้ → ชิปต้องเติมคำว่า " (ต่อ)"
    let isContinuation: Bool
}

struct WeekLayout: Equatable {
    let bars: [LaidOutBar]
    /// column → จำนวนที่ซ่อน · **นับต่อคอลัมน์ ไม่ใช่ต่อสัปดาห์**
    /// ไม่งั้นวันที่ว่างจะขึ้น `+3` ทั้งที่ไม่มีอะไรซ่อนอยู่
    let overflowByColumn: [Int: Int]

    static let empty = WeekLayout(bars: [], overflowByColumn: [:])
}

// ══════════════════════════════════════════════════════════════
// MARK: - Engine
// ══════════════════════════════════════════════════════════════

enum MonthLayoutEngine {

    /// - Parameters:
    ///   - items: รายการทั้งหมดที่ *อาจ* ทับสัปดาห์นี้ (ส่งเกินมาได้ ตัวที่ไม่ทับถูกทิ้งเอง)
    ///   - weekStart: วันอาทิตย์ของสัปดาห์นั้น (จะเป็นเวลาไหนของวันก็ได้)
    ///   - maxLanes: เลนสูงสุดที่วาดได้ เกินจากนี้ยุบเป็น `+N`
    static func layout(
        items: [MonthLayoutItem],
        weekStart: Date,
        maxLanes: Int = 4,
        calendar: Calendar
    ) -> WeekLayout {
        guard maxLanes > 0 else { return .empty }

        let firstDay = calendar.startOfDay(for: weekStart)

        // 1. ตัดทุกรายการให้เหลือเฉพาะช่วงที่ทับกับสัปดาห์นี้
        struct Clipped {
            let item: MonthLayoutItem
            let startColumn: Int
            let endColumn: Int
            let isContinuation: Bool
            var span: Int { endColumn - startColumn + 1 }
        }

        let clipped: [Clipped] = items.compactMap { item in
            guard let rawStart = dayOffset(from: firstDay, to: item.startDay, calendar: calendar),
                  let rawEnd = dayOffset(from: firstDay, to: item.endDay, calendar: calendar),
                  rawEnd >= rawStart          // ช่วงกลับหัว = ข้อมูลเพี้ยน ทิ้ง
            else { return nil }
            guard rawEnd >= 0, rawStart <= 6 else { return nil }  // ไม่ทับสัปดาห์นี้เลย
            return Clipped(
                item: item,
                startColumn: max(rawStart, 0),
                endColumn: min(rawEnd, 6),
                isContinuation: rawStart < 0
            )
        }

        // 2. span มากก่อน (แถบยาวควรได้เลนบน ไม่งั้นโดนแถบสั้นแทรกจนขาดวิ่น)
        //    → คอลัมน์เริ่มน้อยก่อน → sortRank → createdAt → id (กันลำดับแกว่ง)
        let ordered = clipped.sorted { lhs, rhs in
            if lhs.span != rhs.span { return lhs.span > rhs.span }
            if lhs.startColumn != rhs.startColumn { return lhs.startColumn < rhs.startColumn }
            if lhs.item.sortRank != rhs.item.sortRank { return lhs.item.sortRank < rhs.item.sortRank }
            if lhs.item.createdAt != rhs.item.createdAt { return lhs.item.createdAt < rhs.item.createdAt }
            return lhs.item.id < rhs.item.id
        }

        // 3-4. ไล่จองเลนแรกที่ว่างตลอด span · ไม่มีที่ → นับ overflow ทุกคอลัมน์ที่มันกิน
        var occupied = [[Bool]](repeating: [Bool](repeating: false, count: 7), count: maxLanes)
        var bars: [LaidOutBar] = []
        var overflow: [Int: Int] = [:]

        for entry in ordered {
            let columns = entry.startColumn...entry.endColumn

            let lane = (0..<maxLanes).first { lane in
                columns.allSatisfy { !occupied[lane][$0] }
            }

            guard let lane else {
                for column in columns { overflow[column, default: 0] += 1 }
                continue
            }

            for column in columns { occupied[lane][column] = true }
            bars.append(LaidOutBar(
                itemID: entry.item.id,
                lane: lane,
                startColumn: entry.startColumn,
                columnSpan: entry.span,
                isContinuation: entry.isContinuation
            ))
        }

        return WeekLayout(bars: bars, overflowByColumn: overflow)
    }

    /// จำนวนวันเต็มระหว่างสองวัน — คิดจาก `startOfDay` ทั้งคู่ เวลาในวันไม่มีผล
    private static func dayOffset(from origin: Date, to date: Date, calendar: Calendar) -> Int? {
        calendar.dateComponents([.day], from: origin, to: calendar.startOfDay(for: date)).day
    }
}
