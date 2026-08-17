//
//  MonthLayoutEngineTests.swift
//  เทสต์ที่สเปคสั่งไว้ครบ 5 ข้อ ("docs/redesign/08_Calendar.md" §4) + เคสขอบ
//  สัปดาห์ตัวอย่าง: อา 2 ส.ค. 2026 – ส 8 ส.ค. 2026 (คอลัมน์ 0…6)
//

import Foundation
import Testing
@testable import StudiiOS

struct MonthLayoutEngineTests {

    private let calendar = Calendar(identifier: .gregorian)
    /// วันอาทิตย์ที่ 2 ส.ค. 2026
    private var weekStart: Date { day(2) }

    private func day(_ d: Int, month: Int = 8, hour: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = month; comps.day = d; comps.hour = hour
        return calendar.date(from: comps)!
    }

    private func item(_ id: String, _ start: Date, _ end: Date? = nil, rank: Int = 0, created: Date = .distantPast) -> MonthLayoutItem {
        MonthLayoutItem(id: id, startDay: start, endDay: end ?? start, sortRank: rank, createdAt: created)
    }

    private func layout(_ items: [MonthLayoutItem], maxLanes: Int = 4) -> WeekLayout {
        MonthLayoutEngine.layout(items: items, weekStart: weekStart, maxLanes: maxLanes, calendar: calendar)
    }

    // MARK: - §4 เทสต์ที่ต้องมี

    @Test func singleDayEventTakesLaneZeroSpanOne() {
        let result = layout([item("a", day(4))])

        #expect(result.bars.count == 1)
        #expect(result.bars[0] == LaidOutBar(itemID: "a", lane: 0, startColumn: 2, columnSpan: 1, isContinuation: false))
        #expect(result.overflowByColumn.isEmpty)
    }

    @Test func threeDayEventAloneSpansThreeColumns() {
        let result = layout([item("camp", day(3), day(5))])

        #expect(result.bars[0].lane == 0)
        #expect(result.bars[0].startColumn == 1)
        #expect(result.bars[0].columnSpan == 3)
        #expect(result.bars[0].isContinuation == false)
    }

    /// อีเวนต์ 31 ก.ค. – 4 ส.ค. → สัปดาห์นี้เห็นแค่ท่อนหลัง เริ่มคอลัมน์ 0 และเป็นท่อนต่อ
    @Test func eventCrossingIntoThisWeekIsContinuationFromColumnZero() {
        let result = layout([item("midterm", day(31, month: 7), day(4))])

        #expect(result.bars.count == 1)
        #expect(result.bars[0].startColumn == 0)
        #expect(result.bars[0].columnSpan == 3)   // 2,3,4 ส.ค.
        #expect(result.bars[0].isContinuation == true)
    }

    @Test func sixItemsOnSameDayFillFourLanesAndOverflowTwo() {
        let items = (0..<6).map { item("e\($0)", day(5), created: day(1, hour: $0)) }
        let result = layout(items)

        #expect(result.bars.count == 4)
        #expect(Set(result.bars.map(\.lane)) == [0, 1, 2, 3])
        #expect(result.bars.allSatisfy { $0.startColumn == 3 && $0.columnSpan == 1 })
        #expect(result.overflowByColumn[3] == 2)
        #expect(result.overflowByColumn.count == 1)   // วันข้างๆ ต้องไม่ขึ้น +N
    }

    /// แถบยาวที่หาเลนไม่ได้ → ทุกคอลัมน์ที่มันกินต้อง `+1` เท่ากันหมด
    @Test func overflowingLongBarCountsEveryColumnItCovers() {
        // 4 แถบพาดเต็มสัปดาห์กินครบทุกเลนก่อน แถบ 4 วันจึงไม่เหลือที่ลง
        var items = (0..<4).map { lane in
            item("block\(lane)", day(2), day(8), created: day(1, hour: lane))
        }
        items.append(item("long", day(3), day(6), created: day(2)))

        let result = layout(items)

        #expect(result.bars.count == 4)
        #expect(result.bars.allSatisfy { $0.itemID != "long" })
        #expect(result.overflowByColumn == [1: 1, 2: 1, 3: 1, 4: 1])
    }

    // MARK: - เคสขอบที่สเปคไม่ได้สั่ง แต่พังเงียบได้

    @Test func itemsOutsideThisWeekAreDropped() {
        let result = layout([
            item("before", day(29, month: 7), day(31, month: 7)),
            item("after", day(9), day(11)),
            item("inside", day(8))
        ])

        #expect(result.bars.map(\.itemID) == ["inside"])
        #expect(result.bars[0].startColumn == 6)
        #expect(result.overflowByColumn.isEmpty)
    }

    @Test func longerBarWinsUpperLaneRegardlessOfInputOrder() {
        let result = layout([
            item("short", day(4), created: day(1)),
            item("long", day(3), day(6), created: day(2))
        ])

        let long = result.bars.first { $0.itemID == "long" }
        let short = result.bars.first { $0.itemID == "short" }
        #expect(long?.lane == 0)
        #expect(short?.lane == 1)
    }

    /// เวลาในวันต้องไม่มีผล — 4 ส.ค. 23:30 ยังเป็นคอลัมน์เดียวกับ 4 ส.ค. 00:00
    @Test func timeOfDayDoesNotShiftColumns() {
        let result = layout([item("late", day(4, hour: 23), day(4, hour: 23))])

        #expect(result.bars[0].startColumn == 2)
        #expect(result.bars[0].columnSpan == 1)
    }

    @Test func reversedRangeIsIgnored() {
        let result = layout([item("broken", day(6), day(4))])

        #expect(result.bars.isEmpty)
        #expect(result.overflowByColumn.isEmpty)
    }

    @Test func maxLanesOneSendsEverythingElseToOverflow() {
        let result = layout([
            item("a", day(3), created: day(1)),
            item("b", day(3), created: day(2))
        ], maxLanes: 1)

        #expect(result.bars.count == 1)
        #expect(result.bars[0].itemID == "a")
        #expect(result.overflowByColumn == [1: 1])
    }
}
