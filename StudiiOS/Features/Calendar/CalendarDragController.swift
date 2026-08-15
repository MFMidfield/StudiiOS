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

    /// เลขคณิตอย่างเดียว ไม่ใช้ GeometryReader ต่อช่อง (42 ช่องจะกิน CPU) —
    /// วัดขนาดกริดครั้งเดียวผ่าน `.onGeometryChange` แล้วหารเอาเอง
    var cellSize: CGSize {
        let rowCount = max(calendarDays.count / 7, 1)
        return CGSize(width: gridSize.width / 7, height: gridSize.height / CGFloat(rowCount))
    }

    func cellIndex(at point: CGPoint) -> Int? {
        let size = cellSize
        guard size.width > 0, size.height > 0, point.x >= 0, point.y >= 0 else { return nil }
        let days = calendarDays
        let rowCount = days.count / 7
        let col = Int(point.x / size.width)
        let row = Int(point.y / size.height)
        guard col >= 0, col < 7, row >= 0, row < rowCount else { return nil }
        let idx = row * 7 + col
        return idx < days.count ? idx : nil
    }

    func cellCenter(for index: Int) -> CGPoint {
        let size = cellSize
        let col = index % 7
        let row = index / 7
        return CGPoint(x: size.width * (CGFloat(col) + 0.5), y: size.height * (CGFloat(row) + 0.5))
    }

    /// ตำแหน่งนิ้ว → แถบไหน · คิดจาก `WeekLayout` ชุดเดียวกับที่วาด ไม่ใช่จากลำดับ
    /// pill ในช่องอีกแล้ว (08_Calendar §5.1) — ขั้นที่ 6 จะย้ายมาคิดจาก frame ของแถบตรงๆ
    func hitTestItem(at point: CGPoint, cellIndex idx: Int) -> CalendarItem? {
        let size = cellSize
        guard size.height > 0 else { return nil }

        let row = idx / 7
        let column = idx % 7
        let localY = point.y - CGFloat(row) * size.height
        guard localY >= CalendarGeometry.laneTop else { return nil }

        let laneStride = CalendarGeometry.laneHeight + CalendarGeometry.laneSpacing
        let lane = Int((localY - CalendarGeometry.laneTop) / laneStride)
        guard lane >= 0, lane < CalendarGeometry.maxLanes else { return nil }

        let bar = weekLayout(row: row).bars.first {
            $0.lane == lane
                && column >= $0.startColumn
                && column < $0.startColumn + $0.columnSpan
        }
        guard let bar else { return nil }
        return itemsByID[bar.itemID]
    }

    // ── Gesture ──────────────────────────────────────────

    var ghostGesture: some UIGestureRecognizerRepresentable {
        CalendarPressDragGesture(
            onBegan: { beginGhost(at: $0) },
            onChanged: { moveGhost(to: $0) },
            onEnded: { endGhost(at: $0) }
        )
    }

    func beginGhost(at point: CGPoint) {
        guard let idx = cellIndex(at: point) else { return }
        if let item = hitTestItem(at: point, cellIndex: idx) {
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
        lastHapticCellIndex = idx
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) {
            ghostScale = 1.08
        }
    }

    func moveGhost(to point: CGPoint) {
        ghostCurrentPosition = point
        guard let idx = cellIndex(at: point), idx != lastHapticCellIndex else { return }
        lastHapticCellIndex = idx
        let now = Date()
        guard now.timeIntervalSince(lastHapticTime) >= 0.06 else { return }
        lastHapticTime = now
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func endGhost(at point: CGPoint?) {
        guard ghostPayload != nil else { return }
        guard let point, let idx = cellIndex(at: point) else {
            flyBack()
            return
        }
        let targetDay = calendarDays[idx]
        let targetCenter = cellCenter(for: idx)

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
        lastHapticCellIndex = nil
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
