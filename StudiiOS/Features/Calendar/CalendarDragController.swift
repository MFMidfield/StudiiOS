//
//  CalendarDragController.swift
//  ลากย้ายวัน (ghost) + hit-test + toast เลิกทำ
//
//  ขั้นที่ 6 ของ 08_Calendar §8 — ย้ายออกจาก `CalendarView` มาเป็นตัวควบคุม
//  ของตัวเองแล้ว สถานะ ghost/toast ไม่กระจายอยู่ใน view อีก และ `CalendarView`
//  ปิดสมาชิกกลับเป็น private ได้ตามเดิม
//
//  ตัวควบคุมไม่ถือ query ของตัวเอง — ทุกอย่างที่ต้องรู้ (เดือน · รายการ ·
//  ผลจัดเลน · ModelContext) ส่งเข้ามาเป็น `Environment` ตอนเรียกแต่ละครั้ง
//

import SwiftUI
import SwiftData
import UIKit

enum CalendarGhostPayload {
    case newEvent
    case existingEvent(CalendarEvent)
    case existingTask(Assignment)
}

@Observable
@MainActor
final class CalendarDragController {

    /// ทุกอย่างที่ตัวควบคุมต้องรู้จาก `CalendarView` ในจังหวะนั้น
    struct Environment {
        let calendar: Calendar
        let months: [CalendarMonthInfo]
        let itemsByID: [String: CalendarItem]
        let weekLayout: (Date) -> WeekLayout
        let modelContext: ModelContext
        let subjectColor: (Assignment) -> Color
        /// ลากไปวางบนช่องว่าง → สร้างกิจกรรมแล้วเปิดฟอร์มให้แก้ทันที
        let onCreatedEvent: (CalendarEvent) -> Void
        let onSelectDate: (Date) -> Void
    }

    // ── สถานะ ghost ───────────────────────────────────────

    private(set) var payload: CalendarGhostPayload?
    private(set) var origin: CGPoint = .zero
    private(set) var position: CGPoint = .zero
    private(set) var scale: CGFloat = 1.0

    /// id เดือน → frame ในระบบพิกัดสายเลื่อน · 12 รายการ ไม่ใช่ 365 (§5.1)
    var monthFrames: [String: CGRect] = [:]

    private var lastHapticDay: Date?
    private var lastHapticTime: Date = .distantPast

    // ── สถานะ toast ───────────────────────────────────────

    private(set) var toastMessage: String?
    private var toastUndo: (() -> Void)?
    private var toastDismissTask: Task<Void, Never>?

    var isDragging: Bool { payload != nil }

    func isBeingDragged(_ item: CalendarItem) -> Bool {
        switch payload {
        case .existingEvent(let e): return item.sourceEvent === e
        case .existingTask(let t): return item.sourceTask === t
        default: return false
        }
    }

    // ══════════════════════════════════════════════════════
    // MARK: - Hit-test
    // ══════════════════════════════════════════════════════

    struct Hit {
        let day: CalendarDay
        /// กึ่งกลางคอลัมน์นั้นในแนวนอน (ระบบพิกัดสายเลื่อน)
        let columnCenterX: CGFloat
        /// ขอบบนของแถวสัปดาห์ในแนวตั้ง (ระบบพิกัดสายเลื่อน)
        let rowTop: CGFloat
        let weekStart: Date
        let column: Int
        /// ระยะจากขอบบนของแถวสัปดาห์ ใช้หาว่าโดนเลนที่เท่าไหร่
        let localY: CGFloat

        /// จุดที่ ghost ควรไปหยุด = กลางแถบของเลนที่ `lane`
        func center(lane: Int) -> CGPoint {
            CGPoint(
                x: columnCenterX,
                y: rowTop + CalendarGeometry.laneOffset(lane) + CalendarGeometry.laneHeight / 2
            )
        }
    }

    /// เลขคณิตล้วน ไม่ใช้ GeometryReader ต่อช่อง — อ่าน frame แค่ระดับเดือน
    /// เดือนที่ `LazyVStack` ยังไม่ render จะไม่มี frame → ปล่อยตรงนั้นไม่ได้
    func hit(at point: CGPoint, env: Environment) -> Hit? {
        guard let entry = monthFrames.first(where: { $0.value.contains(point) }),
              let month = env.months.first(where: { $0.id == entry.key })
        else { return nil }

        let frame = entry.value
        let colWidth = frame.width / 7
        guard colWidth > 0 else { return nil }

        let localX = point.x - frame.minX
        let gridY = point.y - frame.minY - CalendarGeometry.monthLabelHeight
        guard gridY >= 0 else { return nil }

        let row = Int(gridY / CalendarGeometry.rowHeight)
        let column = min(max(Int(localX / colWidth), 0), 6)
        let index = row * 7 + column
        guard index >= 0, index < month.days.count else { return nil }

        return Hit(
            day: month.days[index],
            columnCenterX: frame.minX + colWidth * (CGFloat(column) + 0.5),
            rowTop: frame.minY + CalendarGeometry.monthLabelHeight
                + CalendarGeometry.rowHeight * CGFloat(row),
            weekStart: month.days[row * 7].date,
            column: column,
            localY: gridY - CGFloat(row) * CalendarGeometry.rowHeight
        )
    }

    /// เลนที่ของชิ้นนี้จะไปลงจริงเมื่อปล่อยที่ช่องนั้น = เลนว่างเลนแรกของคอลัมน์
    /// (ไม่นับตัวที่กำลังลากอยู่เอง — มันกำลังจะย้ายออกจากที่เดิม)
    /// ghost จะได้เลื่อนไปต่อท้ายของที่มีอยู่ ไม่ไปทับแถวบนสุด
    private func landingLane(for hit: Hit, env: Environment) -> Int {
        let draggedID: String?
        switch payload {
        case .existingEvent(let e): draggedID = "event_\(e.id)"
        case .existingTask(let t): draggedID = "task_\(t.persistentModelID)"
        default: draggedID = nil
        }

        let occupied = Set(
            env.weekLayout(hit.weekStart).bars
                .filter { bar in
                    bar.itemID != draggedID
                        && hit.column >= bar.startColumn
                        && hit.column < bar.startColumn + bar.columnSpan
                }
                .map(\.lane)
        )

        return (0..<CalendarGeometry.maxLanes).first { !occupied.contains($0) }
            ?? (CalendarGeometry.maxLanes - 1)
    }

    /// ตำแหน่งนิ้ว → แถบไหน · คิดจาก `WeekLayout` ชุดเดียวกับที่วาด
    func item(at hit: Hit, env: Environment) -> CalendarItem? {
        guard hit.localY >= CalendarGeometry.laneTop else { return nil }

        let laneStride = CalendarGeometry.laneHeight + CalendarGeometry.laneSpacing
        let lane = Int((hit.localY - CalendarGeometry.laneTop) / laneStride)
        guard lane >= 0, lane < CalendarGeometry.maxLanes else { return nil }

        let bar = env.weekLayout(hit.weekStart).bars.first {
            $0.lane == lane
                && hit.column >= $0.startColumn
                && hit.column < $0.startColumn + $0.columnSpan
        }
        guard let bar else { return nil }
        return env.itemsByID[bar.itemID]
    }

    // ══════════════════════════════════════════════════════
    // MARK: - วงจรการลาก
    // ══════════════════════════════════════════════════════

    func begin(at point: CGPoint, env: Environment) {
        guard let hit = hit(at: point, env: env) else { return }

        if let item = item(at: hit, env: env) {
            if let event = item.sourceEvent {
                payload = .existingEvent(event)
            } else if let task = item.sourceTask {
                payload = .existingTask(task)
            } else {
                return
            }
        } else {
            payload = .newEvent
        }

        origin = point
        position = point
        scale = 1.0
        lastHapticDay = hit.day.date
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
            scale = 1.08
        }
    }

    func move(to point: CGPoint, env: Environment) {
        position = point
        guard let hit = hit(at: point, env: env), hit.day.date != lastHapticDay else { return }
        lastHapticDay = hit.day.date
        let now = Date()
        guard now.timeIntervalSince(lastHapticTime) >= 0.06 else { return }
        lastHapticTime = now
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func end(at point: CGPoint?, env: Environment) {
        guard payload != nil else { return }
        guard let point, let hit = hit(at: point, env: env) else {
            flyBack()
            return
        }

        let cal = env.calendar
        let targetDate = hit.day.date
        let landing = hit.center(lane: landingLane(for: hit, env: env))

        func settle(_ commit: @escaping () -> Void) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                position = landing
                scale = 1.0
            } completion: {
                commit()
                self.reset()
            }
        }

        switch payload {
        case .newEvent:
            settle { self.createEvent(on: targetDate, env: env) }
        case .existingEvent(let event):
            if cal.isDate(event.startDate, inSameDayAs: targetDate) {
                flyBack()
            } else {
                settle { self.moveEvent(event, to: targetDate, env: env) }
            }
        case .existingTask(let task):
            if let due = task.resolvedDueDate, cal.isDate(due, inSameDayAs: targetDate) {
                flyBack()
            } else {
                settle { self.moveTask(task, to: targetDate, env: env) }
            }
        case nil:
            break
        }
    }

    private func flyBack() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
            position = origin
            scale = 1.0
        } completion: {
            self.reset()
        }
    }

    private func reset() {
        payload = nil
        lastHapticDay = nil
    }

    // ══════════════════════════════════════════════════════
    // MARK: - บันทึกการย้าย
    // ══════════════════════════════════════════════════════

    private func createEvent(on date: Date, env: Environment) {
        let cal = env.calendar
        let dayStart = cal.startOfDay(for: date)
        let newEvent = CalendarEvent(
            title: "กิจกรรมใหม่",
            startDate: dayStart,
            endDate: cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart,
            isAllDay: true
        )
        env.modelContext.insert(newEvent)
        try? env.modelContext.save()
        env.onSelectDate(date)
        env.onCreatedEvent(newEvent)
    }

    /// ย้ายทั้งก้อนโดยคงจำนวนวันเท่าเดิม (§5.3) — เวลาในวันของกิจกรรมที่ไม่ใช่
    /// ทั้งวันต้องคงไว้ด้วย ไม่งั้นนัดบ่ายกลายเป็นเที่ยงคืน
    private func moveEvent(_ event: CalendarEvent, to date: Date, env: Environment) {
        let cal = env.calendar
        let originalStart = event.startDate
        let originalEnd = event.endDate
        let duration = originalEnd.timeIntervalSince(originalStart)

        let newStart: Date
        if event.isAllDay {
            newStart = cal.startOfDay(for: date)
        } else {
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            let time = cal.dateComponents([.hour, .minute, .second], from: originalStart)
            comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second
            newStart = cal.date(from: comps) ?? originalStart
        }

        event.startDate = newStart
        event.endDate = newStart.addingTimeInterval(duration)
        event.updatedAt = .now
        try? env.modelContext.save()
        Task { await NotificationManager.shared.schedule(for: event) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        showToast(dateLabel: newStart.thaiShortNoYearString) {
            event.startDate = originalStart
            event.endDate = originalEnd
            event.updatedAt = .now
            try? env.modelContext.save()
            Task { await NotificationManager.shared.schedule(for: event) }
        }
    }

    private func moveTask(_ task: Assignment, to date: Date, env: Environment) {
        let cal = env.calendar
        guard let originalDue = task.resolvedDueDate else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let time = cal.dateComponents([.hour, .minute, .second], from: originalDue)
        comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second
        let newDue = cal.date(from: comps) ?? originalDue

        task.dueDate = newDue
        try? env.modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        showToast(dateLabel: newDue.thaiShortNoYearString) {
            task.dueDate = originalDue
            try? env.modelContext.save()
            Task { await NotificationManager.shared.schedule(for: task) }
        }
    }

    // ══════════════════════════════════════════════════════
    // MARK: - Toast "ย้ายไป... เลิกทำ"
    // ══════════════════════════════════════════════════════

    private func showToast(dateLabel: String, undo: @escaping () -> Void) {
        toastDismissTask?.cancel()
        withAnimation { toastMessage = "ย้ายไป \(dateLabel) แล้ว" }
        toastUndo = undo
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.dismissToast(runUndo: false)
        }
    }

    func dismissToast(runUndo: Bool) {
        toastDismissTask?.cancel()
        if runUndo { toastUndo?() }
        withAnimation { toastMessage = nil }
        toastUndo = nil
    }

    // ── ป้ายบน ghost ──────────────────────────────────────

    func ghostLabel(env: Environment) -> String {
        switch payload {
        case .newEvent: return "กิจกรรมใหม่"
        case .existingEvent(let e): return e.subjectName.isEmpty ? e.title : e.subjectName
        case .existingTask(let t): return t.subjectName.isEmpty ? t.title : t.subjectName
        case nil: return ""
        }
    }

    func ghostColor(env: Environment) -> Color {
        switch payload {
        case .newEvent: return Theme.Colors.primary
        case .existingEvent(let e): return e.color
        case .existingTask(let t): return env.subjectColor(t)
        case nil: return Theme.Colors.primary
        }
    }
}

// ══════════════════════════════════════════════════════════════
// MARK: - ชั้นที่วาดของตัวควบคุม
// ══════════════════════════════════════════════════════════════

struct CalendarGhostOverlay: View {
    let controller: CalendarDragController
    let env: CalendarDragController.Environment

    var body: some View {
        if controller.isDragging {
            GhostPillView(
                label: controller.ghostLabel(env: env),
                color: controller.ghostColor(env: env),
                scale: controller.scale,
                position: controller.position
            )
        }
    }
}

struct CalendarMoveToast: View {
    let controller: CalendarDragController

    var body: some View {
        if let message = controller.toastMessage {
            HStack {
                Text(message)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button("เลิกทำ") { controller.dismissToast(runUndo: true) }
                    .font(Theme.Font.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, 90)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
