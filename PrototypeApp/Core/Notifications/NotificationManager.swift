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
