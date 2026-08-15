//
//  CalendarItemBuilder.swift
//  แปลง CalendarEvent / Assignment เป็น CalendarItem — ตรรกะล้วน ไม่มี View
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิม (`itemsByDay` / `searchResults`) ออกจาก
//  CalendarView.swift ทั้งก้อน ไม่เปลี่ยนพฤติกรรม — เดิมสร้าง CalendarItem
//  ด้วยมือสองที่ (ตาราง + ค้นหา) ตอนนี้เหลือจุดเดียว
//

import Foundation
import SwiftUI
import SwiftData

enum CalendarItemBuilder {

    static func item(for event: CalendarEvent) -> CalendarItem {
        CalendarItem(
            id: "event_\(event.id)",
            kind: .event,
            title: event.title,
            shortLabel: event.subjectName.isEmpty ? event.title : event.subjectName,
            date: event.startDate,
            isAllDay: event.isAllDay,
            color: event.color,
            isDone: false,
            sourceEvent: event,
            sourceTask: nil
        )
    }

    static func item(for task: Assignment, due: Date, color: Color) -> CalendarItem {
        let kind: CalendarItemKind = task.kind == .exam ? .exam : task.kind == .personal ? .personal : .homework
        return CalendarItem(
            id: "task_\(task.persistentModelID)",
            kind: kind,
            title: task.title,
            shortLabel: task.subjectName.isEmpty ? task.title : task.subjectName,
            date: due,
            isAllDay: true,
            color: color,
            isDone: task.isDone,
            sourceEvent: nil,
            sourceTask: task
        )
    }

    /// รายการทั้งหมดของทั้งแอปในรูป `CalendarItem` ชุดเดียว
    static func items(
        events: [CalendarEvent],
        tasks: [Assignment],
        color: (Assignment) -> Color
    ) -> [CalendarItem] {
        var result = events.map { item(for: $0) }
        for task in tasks {
            guard let due = task.resolvedDueDate else { continue }
            result.append(item(for: task, due: due, color: color(task)))
        }
        return result
    }

    /// index ตาม `startOfDay` ครั้งเดียว — กันช่องวันแต่ละช่อง (42 ช่อง)
    /// วน array ทั้งก้อนใหม่ทุกครั้งที่ render
    static func itemsByDay(_ items: [CalendarItem], calendar cal: Calendar) -> [Date: [CalendarItem]] {
        var dict: [Date: [CalendarItem]] = [:]
        for item in items {
            dict[cal.startOfDay(for: item.date), default: []].append(item)
        }
        for key in dict.keys {
            dict[key]?.sort { lhs, rhs in
                lhs.sortRank != rhs.sortRank ? lhs.sortRank < rhs.sortRank : lhs.date < rhs.date
            }
        }
        return dict
    }

    static func byID(_ items: [CalendarItem]) -> [String: CalendarItem] {
        Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // ── ขาเข้าของ MonthLayoutEngine ───────────────────────

    /// แปลงเป็นช่วงวันแบบ **รวมปลาย** ให้ engine
    ///
    /// `CalendarItem` ไม่มีวันสิ้นสุด (มีแค่ `date`) → ต้องอ่าน `endDate` จาก
    /// `CalendarEvent` ตรงๆ · กิจกรรมทั้งวันเก็บ `endDate` แบบ **ไม่รวมปลาย**
    /// (เที่ยงคืนของวันถัดไป) จึงต้องลบออกหนึ่งวัน ไม่งั้นแถบยาวเกินจริงหนึ่งช่อง
    static func layoutItem(for item: CalendarItem, calendar cal: Calendar) -> MonthLayoutItem {
        let endDay: Date
        let createdAt: Date

        if let event = item.sourceEvent {
            createdAt = event.createdAt
            if event.isAllDay {
                let exclusiveEnd = cal.startOfDay(for: event.endDate)
                let inclusive = cal.date(byAdding: .day, value: -1, to: exclusiveEnd) ?? event.startDate
                endDay = max(inclusive, event.startDate)
            } else {
                endDay = max(event.endDate, event.startDate)
            }
        } else {
            createdAt = item.sourceTask?.createdAt ?? item.date
            endDay = item.date
        }

        return MonthLayoutItem(
            id: item.id,
            startDay: item.date,
            endDay: endDay,
            sortRank: item.sortRank,
            createdAt: createdAt
        )
    }

    static func layoutItems(_ items: [CalendarItem], calendar cal: Calendar) -> [MonthLayoutItem] {
        items.map { layoutItem(for: $0, calendar: cal) }
    }

    static func searchResults(
        query: String,
        events: [CalendarEvent],
        tasks: [Assignment],
        color: (Assignment) -> Color
    ) -> [CalendarItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var results: [CalendarItem] = []

        for event in events {
            let matches = event.title.lowercased().contains(q)
                || event.location.lowercased().contains(q)
                || event.notes.lowercased().contains(q)
                || event.subjectName.lowercased().contains(q)
                || event.tags.contains { $0.name.lowercased().contains(q) }
            guard matches else { continue }
            results.append(item(for: event))
        }

        for task in tasks {
            guard let due = task.resolvedDueDate else { continue }
            let matches = task.title.lowercased().contains(q)
                || task.detail.lowercased().contains(q)
                || task.subjectName.lowercased().contains(q)
            guard matches else { continue }
            results.append(item(for: task, due: due, color: color(task)))
        }

        return results.sorted { $0.date < $1.date }
    }
}
