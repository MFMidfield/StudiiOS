//
//  NotificationManager.swift
//  Wraps UNUserNotificationCenter for CalendarEvent reminders and the
//  Settings "test notification" flow.
//

import Foundation
import UserNotifications

extension EventAlert {
    /// Lead time before the event's start to fire the notification, or nil for `.none`.
    func leadTime(customMinutes: Int) -> TimeInterval? {
        switch self {
        case .none:       return nil
        case .atTime:     return 0
        case .fiveMin:    return 5 * 60
        case .fifteenMin: return 15 * 60
        case .thirtyMin:  return 30 * 60
        case .oneHour:    return 60 * 60
        case .oneDay:     return 24 * 60 * 60
        case .custom:     return TimeInterval(customMinutes) * 60
        }
    }
}

@Observable
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var lastError: String?

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        Task { await refreshStatus() }
    }

    // MARK: - Authorization

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            lastError = error.localizedDescription
            await refreshStatus()
            return false
        }
    }

    // MARK: - Test notification

    func sendTestNotification(after seconds: TimeInterval = 5) async {
        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "ทดสอบแจ้งเตือน"
        content.body = "ถ้าเห็นข้อความนี้ แปลว่าระบบแจ้งเตือนทำงานปกติ"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Event scheduling

    private func identifier(for event: CalendarEvent) -> String {
        "event-\(event.id.uuidString)"
    }

    func schedule(for event: CalendarEvent) async {
        cancel(for: event)

        guard let leadTime = event.alert.leadTime(customMinutes: event.customAlertMinutes) else { return }
        let fireDate = event.startDate.addingTimeInterval(-leadTime)
        guard fireDate > .now else { return }

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        if event.isAllDay {
            content.body = "วันนี้ทั้งวัน"
        } else {
            content.body = "เริ่ม \(DateFormatter.time24h.string(from: event.startDate)) น."
        }
        if !event.location.isEmpty {
            content.body += " · \(event.location)"
        }
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: event),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancel(for event: CalendarEvent) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: event)])
    }

    // MARK: - Assignment scheduling
    //
    // แยกจากส่วนของ CalendarEvent ด้านบนโดยสิ้นเชิง — identifier คนละ prefix
    // งาน 1 ชิ้นได้แจ้งเตือน 3 จุด (ดู AssignmentSlot)

    private enum AssignmentSlot: String, CaseIterable {
        /// 24 ชม. ก่อนกำหนดส่ง
        case d1
        /// 07:00 ของวันที่กำหนดส่ง
        case am
        /// 1 ชม. ก่อนกำหนดส่ง
        case h1
    }

    /// iOS ยอมให้มี pending notification ได้ 64 อัน — 16 งาน × 3 จุด = 48
    /// เหลือที่ว่างให้ CalendarEvent
    private static let maxAssignmentsWithReminders = 16

    /// ยิงเฉพาะงานที่กำหนดส่งภายในกี่วัน
    private static let assignmentReminderWindowDays = 14

    private func identifiers(forUID uid: String) -> [String] {
        AssignmentSlot.allCases.map { "assignment-\(uid)-\($0.rawValue)" }
    }

    /// เงื่อนไขเดียวที่ตัดสินว่างานชิ้นนี้ควรมีแจ้งเตือนไหม
    private func shouldSchedule(_ assignment: Assignment, now: Date = .now) -> Bool {
        guard assignment.remindersEnabled,
              !assignment.isDone,
              let due = assignment.resolvedDueDate,
              due > now
        else { return false }
        return AssignmentPriorityEngine.daysUntil(due, from: now) <= Self.assignmentReminderWindowDays
    }

    private func fireDate(for slot: AssignmentSlot, due: Date) -> Date? {
        switch slot {
        case .d1:
            return due.addingTimeInterval(-24 * 60 * 60)
        case .am:
            return Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: due)
        case .h1:
            return due.addingTimeInterval(-60 * 60)
        }
    }

    /// ข้อความต่าง slot กัน เพราะป้ายวันต้องถูก ณ "ตอนเด้ง" ไม่ใช่ตอนตั้ง
    private func reminderBody(for assignment: Assignment, due: Date, slot: AssignmentSlot) -> String {
        var parts = [assignment.kind.label]
        if !assignment.subjectName.isEmpty {
            parts.append(assignment.subjectName)
        }
        let time = DateFormatter.time24h.string(from: due)
        switch slot {
        case .d1: parts.append("ส่งพรุ่งนี้ \(time) น.")
        case .am: parts.append("ส่งวันนี้ \(time) น.")
        case .h1: parts.append("อีก 1 ชั่วโมงถึงกำหนดส่ง (\(time) น.)")
        }
        return parts.joined(separator: " · ")
    }

    /// ยกเลิกของเดิมแล้วตั้งใหม่เสมอ — เรียกได้ทุกครั้งที่งานเปลี่ยน
    /// ถ้างานไม่เข้าเงื่อนไข (ปิด toggle / เสร็จแล้ว / ไม่กำหนดส่ง) จะเหลือแค่ยกเลิก
    func schedule(for assignment: Assignment) async {
        cancel(for: assignment)

        guard shouldSchedule(assignment), let due = assignment.resolvedDueDate else { return }

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let uid = assignment.ensureUID()

        for slot in AssignmentSlot.allCases {
            guard let fireDate = fireDate(for: slot, due: due),
                  fireDate > .now,
                  fireDate <= due
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = assignment.title
            content.body = reminderBody(for: assignment, due: due, slot: slot)
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let request = UNNotificationRequest(
                identifier: "assignment-\(uid)-\(slot.rawValue)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )

            do {
                try await center.add(request)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func cancel(for assignment: Assignment) {
        guard !assignment.uid.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers(forUID: assignment.uid))
    }

    /// เรียกตอนแอปขึ้น foreground — กวาดทิ้งแล้วตั้งใหม่ทั้งหมดให้ตรงกับวันนี้
    /// (ป้ายวัน "พรุ่งนี้/วันนี้" และหน้าต่าง 14 วันขึ้นกับวันที่ปัจจุบัน)
    func refreshAssignmentReminders(_ assignments: [Assignment]) async {
        for assignment in assignments {
            cancel(for: assignment)
        }

        let due = assignments
            .filter { shouldSchedule($0) }
            .sorted { ($0.resolvedDueDate ?? .distantFuture) < ($1.resolvedDueDate ?? .distantFuture) }
            .prefix(Self.maxAssignmentsWithReminders)

        for assignment in due {
            await schedule(for: assignment)
        }
        AppLog.action("Notification", "ตั้งแจ้งเตือนงานใหม่ \(due.count) ชิ้น (สูงสุด \(Self.maxAssignmentsWithReminders))")
    }

    // MARK: - Pomodoro / Focus
    //
    // แยกจาก 2 ส่วนบนโดยสิ้นเชิง — identifier prefix `focus-`
    // มีได้ทีละ 1 อันเท่านั้น (ช่วงที่กำลังเดินอยู่) ตั้งใหม่ = ทับของเดิม
    //
    // จุดสำคัญ: ตั้งไว้ **ล่วงหน้า** ที่เวลาหมด ไม่ได้ยิงตอนแอปตรวจพบว่าหมดเวลา
    // เพราะถ้าแอปอยู่ background หรือถูกปิด จะไม่มีใครยิงให้เลย

    private static let focusIdentifier = "focus-phase-end"

    func scheduleFocusEnd(at fireDate: Date, phase: PomodoroPhase, body: String) async {
        cancelFocusNotification()
        guard fireDate > .now else { return }

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = phase.endedNotificationTitle
        content.body = body
        content.sound = .default
        // หมายเหตุ: ถ้าอยากให้เด้งทะลุโหมด "ห้ามรบกวน" ต้องเพิ่ม capability
        // "Time Sensitive Notifications" ใน Xcode ก่อน แล้วค่อยตั้ง
        // content.interruptionLevel = .timeSensitive — ยังไม่เปิดในรอบนี้

        let request = UNNotificationRequest(
            identifier: Self.focusIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, fireDate.timeIntervalSinceNow),
                repeats: false
            )
        )

        do {
            try await center.add(request)
            AppLog.action("Notification", "ตั้งแจ้งเตือนจบ\(phase.label) อีก \(Int(fireDate.timeIntervalSinceNow)) วิ")
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancelFocusNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.focusIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.focusIdentifier])
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
