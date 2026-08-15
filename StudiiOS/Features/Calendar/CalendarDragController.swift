//
//  CalendarDragController.swift
//  ลากย้ายวัน (ghost) + hit-test + toast เลิกทำ
//
//  ก้อน G ขั้นที่ 1: ยกโค้ดเดิมออกมาจาก CalendarView.swift ทั้งก้อน
//  **ยังเป็น extension ของ CalendarView อยู่** เพราะขั้นนี้ห้ามเปลี่ยนพฤติกรรม —
//  ขั้นที่ 6 ค่อยแปลงเป็นตัวควบคุมของตัวเองพร้อม hit-test แบบใหม่ (08_Calendar §5)
//

import SwiftUI
import SwiftData
import UIKit

enum CalendarGhostPayload {
    case newEvent
    case existingEvent(CalendarEvent)
    case existingTask(Assignment)
}

extension CalendarView {

    // ── Hit-test ─────────────────────────────────────────

    func isBeingDragged(_ item: CalendarItem) -> Bool {
        switch ghostPayload {
        case .existingEvent(let e): return item.sourceEvent === e
        case .existingTask(let t): return item.sourceTask === t
        default: return false
        }
    }

    /// ผลของการหาว่านิ้วอยู่ตรงไหนของสายเลื่อน
    struct CalendarHit {
        let day: CalendarDay
        /// จุดกึ่งกลางช่องวันนั้น ในระบบพิกัดสายเลื่อน — ใช้ให้ ghost ไปหยุดตรงกลางช่อง
        let center: CGPoint
        let weekStart: Date
        let column: Int
        /// ระยะจากขอบบนของแถวสัปดาห์ ใช้หาว่าโดนเลนที่เท่าไหร่
        let localY: CGFloat
    }

    /// เลขคณิตอย่างเดียว ไม่ใช้ GeometryReader ต่อช่อง — อ่าน frame แค่ระดับเดือน
    /// (12 รายการ ไม่ใช่ 365 ตาม 08_Calendar §5.1) แล้วหารเอาเอง
    ///
    /// เดือนที่ `LazyVStack` ยังไม่ render จะไม่มี frame → ปล่อยตรงนั้นไม่ได้ = flyBack
    func hit(at point: CGPoint) -> CalendarHit? {
        guard let entry = monthFrames.first(where: { $0.value.contains(point) }),
              let month = months.first(where: { $0.id == entry.key })
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

        let center = CGPoint(
            x: frame.minX + colWidth * (CGFloat(column) + 0.5),
            y: frame.minY + CalendarGeometry.monthLabelHeight
                + CalendarGeometry.rowHeight * (CGFloat(row) + 0.5)
        )

        return CalendarHit(
            day: month.days[index],
            center: center,
            weekStart: month.days[row * 7].date,
            column: column,
            localY: gridY - CGFloat(row) * CalendarGeometry.rowHeight
        )
    }

    /// ตำแหน่งนิ้ว → แถบไหน · คิดจาก `WeekLayout` ชุดเดียวกับที่วาด
    /// ขั้นที่ 6 จะย้ายมาคิดจาก frame ของแถบตรงๆ
    func hitTestItem(_ hit: CalendarHit) -> CalendarItem? {
        guard hit.localY >= CalendarGeometry.laneTop else { return nil }

        let laneStride = CalendarGeometry.laneHeight + CalendarGeometry.laneSpacing
        let lane = Int((hit.localY - CalendarGeometry.laneTop) / laneStride)
        guard lane >= 0, lane < CalendarGeometry.maxLanes else { return nil }

        let bar = weekLayout(weekStart: hit.weekStart).bars.first {
            $0.lane == lane
                && hit.column >= $0.startColumn
                && hit.column < $0.startColumn + $0.columnSpan
        }
        guard let bar else { return nil }
        return itemsByID[bar.itemID]
    }

    // ── Gesture ──────────────────────────────────────────

    /// ชื่อระบบพิกัดของตารางเดือน — `CalendarView` ประกาศไว้บน `CalendarMonthSection`
    static let gridSpaceName = "monthGrid"

    var ghostGesture: some UIGestureRecognizerRepresentable {
        CalendarPressDragGesture(
            space: .named(Self.gridSpaceName),
            onBegan: { beginGhost(at: $0) },
            onChanged: { moveGhost(to: $0) },
            onEnded: { endGhost(at: $0) }
        )
    }

    func beginGhost(at point: CGPoint) {
        guard let hit = hit(at: point) else { return }
        if let item = hitTestItem(hit) {
            if let event = item.sourceEvent {
                ghostPayload = .existingEvent(event)
            } else if let task = item.sourceTask {
                ghostPayload = .existingTask(task)
            } else {
                return
            }
        } else {
            ghostPayload = .newEvent
        }

        ghostOrigin = point
        ghostCurrentPosition = point
        ghostScale = 1.0
        lastHapticDay = hit.day.date
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
            ghostScale = 1.08
        }
    }

    func moveGhost(to point: CGPoint) {
        ghostCurrentPosition = point
        guard let hit = hit(at: point), hit.day.date != lastHapticDay else { return }
        lastHapticDay = hit.day.date
        let now = Date()
        guard now.timeIntervalSince(lastHapticTime) >= 0.06 else { return }
        lastHapticTime = now
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func endGhost(at point: CGPoint?) {
        guard ghostPayload != nil else { return }
        guard let point, let hit = hit(at: point) else {
            flyBack()
            return
        }
        let targetDay = hit.day
        let targetCenter = hit.center

        func settle(_ commit: @escaping () -> Void) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                ghostCurrentPosition = targetCenter
                ghostScale = 1.0
            } completion: {
                commit()
                resetGhostState()
            }
        }

        switch ghostPayload {
        case .newEvent:
            settle { createEvent(on: targetDay.date) }
        case .existingEvent(let event):
            if cal.isDate(event.startDate, inSameDayAs: targetDay.date) {
                flyBack()
            } else {
                settle { moveEvent(event, to: targetDay.date) }
            }
        case .existingTask(let task):
            if let due = task.resolvedDueDate, cal.isDate(due, inSameDayAs: targetDay.date) {
                flyBack()
            } else {
                settle { moveTask(task, to: targetDay.date) }
            }
        case nil:
            break
        }
    }

    func flyBack() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.80)) {
            ghostCurrentPosition = ghostOrigin
            ghostScale = 1.0
        } completion: {
            resetGhostState()
        }
    }

    func resetGhostState() {
        ghostPayload = nil
        lastHapticDay = nil
    }

    // ── บันทึกการย้าย ─────────────────────────────────────

    func createEvent(on date: Date) {
        let dayStart = cal.startOfDay(for: date)
        let newEvent = CalendarEvent(
            title: "กิจกรรมใหม่",
            startDate: dayStart,
            endDate: cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart,
            isAllDay: true
        )
        modelContext.insert(newEvent)
        try? modelContext.save()
        selectedDate = date
        activeSheet = .editNewGhost(newEvent)
    }

    func moveEvent(_ event: CalendarEvent, to date: Date) {
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
        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: event) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        showMoveToast(dateLabel: newStart.thaiShortNoYearString) {
            event.startDate = originalStart
            event.endDate = originalEnd
            event.updatedAt = .now
            try? modelContext.save()
            Task { await NotificationManager.shared.schedule(for: event) }
        }
    }

    func moveTask(_ task: Assignment, to date: Date) {
        guard let originalDue = task.resolvedDueDate else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        let time = cal.dateComponents([.hour, .minute, .second], from: originalDue)
        comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second
        let newDue = cal.date(from: comps) ?? originalDue

        task.dueDate = newDue
        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        showMoveToast(dateLabel: newDue.thaiShortNoYearString) {
            task.dueDate = originalDue
            try? modelContext.save()
            Task { await NotificationManager.shared.schedule(for: task) }
        }
    }

    // ── Ghost overlay ────────────────────────────────────

    @ViewBuilder
    var ghostOverlay: some View {
        if let payload = ghostPayload {
            GhostPillView(
                label: ghostLabel(for: payload),
                color: ghostColor(for: payload),
                scale: ghostScale,
                position: ghostCurrentPosition
            )
        }
    }

    func ghostLabel(for payload: CalendarGhostPayload) -> String {
        switch payload {
        case .newEvent: return "กิจกรรมใหม่"
        case .existingEvent(let e): return e.subjectName.isEmpty ? e.title : e.subjectName
        case .existingTask(let t): return t.subjectName.isEmpty ? t.title : t.subjectName
        }
    }

    func ghostColor(for payload: CalendarGhostPayload) -> Color {
        switch payload {
        case .newEvent: return Theme.Colors.primary
        case .existingEvent(let e): return e.color
        case .existingTask(let t): return subjectColor(for: t)
        }
    }

    // ── Move toast ("ย้ายไป... เลิกทำ") ────────────────────

    func showMoveToast(dateLabel: String, undo: @escaping () -> Void) {
        toastDismissTask?.cancel()
        withAnimation { toastMessage = "ย้ายไป \(dateLabel) แล้ว" }
        toastUndo = undo
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { toastMessage = nil }
            toastUndo = nil
        }
    }

    func dismissToast(runUndo: Bool) {
        toastDismissTask?.cancel()
        if runUndo { toastUndo?() }
        withAnimation { toastMessage = nil }
        toastUndo = nil
    }

    @ViewBuilder
    var moveToast: some View {
        if let message = toastMessage {
            HStack {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button("เลิกทำ") { dismissToast(runUndo: true) }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
