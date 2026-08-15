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

    /// index ตาม `startOfDay` ครั้งเดียว — กันช่องวันแต่ละช่อง (42 ช่อง)
    /// วน array ทั้งก้อนใหม่ทุกครั้งที่ render
    static func itemsByDay(
        events: [CalendarEvent],
        tasks: [Assignment],
        calendar cal: Calendar,
        color: (Assignment) -> Color
    ) -> [Date: [CalendarItem]] {
        var dict: [Date: [CalendarItem]] = [:]

        for event in events {
            dict[cal.startOfDay(for: event.startDate), default: []].append(item(for: event))
        }

        for task in tasks {
            guard let due = task.resolvedDueDate else { continue }
            dict[cal.startOfDay(for: due), default: []].append(item(for: task, due: due, color: color(task)))
        }

        for key in dict.keys {
            dict[key]?.sort { lhs, rhs in
                lhs.sortRank != rhs.sortRank ? lhs.sortRank < rhs.sortRank : lhs.date < rhs.date
            }
        }
        return dict
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
