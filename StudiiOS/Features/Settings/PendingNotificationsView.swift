//
//  PendingNotificationsView.swift
//  รายการแจ้งเตือนที่ตั้งไว้ — pushed from SettingsView's notification section.
//
//  Read-only apart from "ล้างการแจ้งเตือนทั้งหมด", which goes through
//  NotificationManager so the cancel logic stays in one place.
//
//  Split out of SettingsView.swift (588 lines, 4 structs).
//

import SwiftUI
import UserNotifications

struct PendingNotificationsView: View {
    @State private var requests: [UNNotificationRequest] = []

    var body: some View {
        List {
            if requests.isEmpty {
                Text("ยังไม่มีการแจ้งเตือนที่ตั้งไว้")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requests, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.content.title)
                            .font(Theme.Font.body)
                            .fontWeight(.semibold)
                        if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                           let date = trigger.nextTriggerDate() {
                            Text(date.thaiFullString)
                                .font(Theme.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("ล้างการแจ้งเตือนทั้งหมด", role: .destructive) {
                    NotificationManager.shared.cancelAll()
                    requests = []
                }
            }
        }
        .navigationTitle("การแจ้งเตือนที่ตั้งไว้")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            requests = await NotificationManager.shared.pendingRequests()
        }
    }
}
