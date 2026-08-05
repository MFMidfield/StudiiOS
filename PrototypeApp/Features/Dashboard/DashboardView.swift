//
//  DashboardView.swift
//  Dashboard module: งานค้าง, งานที่ต้องส่งวันนี้, Productivity Summary.
//

import SwiftUI
import SwiftData
import UIKit

struct DashboardView: View {
    @Query(sort: \Assignment.dueDate) private var assignments: [Assignment]
    @Query private var focusSessions: [FocusSession]

    private var today: Date { .now }

    private var pendingAssignments: [Assignment] {
        assignments.filter { !$0.isDone }
    }

    private var dueTodayAssignments: [Assignment] {
        pendingAssignments.filter {
            guard let due = $0.resolvedDueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderSection()
                DateBadge(date: today)
                StatsCard(
                    focusMinutesToday: focusMinutesToday,
                    pendingCount: pendingAssignments.count
                )
                MainMenuSection()
                PendingWorkSection(dueToday: dueTodayAssignments, pending: pendingAssignments)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.Colors.background)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var focusMinutesToday: Int {
        let seconds = focusSessions
            .filter { Calendar.current.isDateInToday($0.startedAt) && $0.completed }
            .reduce(0) { $0 + $1.durationSeconds }
        return seconds / 60
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    @State private var profile = StudentProfileStore.shared

    private var displayName: String {
        if !profile.nickname.isEmpty { return profile.nickname }
        if !profile.firstName.isEmpty { return profile.firstName }
        return "ยินดีต้อนรับ"
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("สวัสดีตอนเช้า")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("🌤")
                }
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Spacer()
            AvatarView()
        }
        .padding(.top, 60)
    }
}

struct AvatarView: View {
    @State private var profile = StudentProfileStore.shared

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.primary.opacity(0.12))
                .frame(width: 60, height: 60)
                .padding(.top, 10)
            if let profileImage = profile.cachedProfileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .padding(.top, 10)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.top, 10)
            }
        }
    }
}

// MARK: - Date Badge

struct DateBadge: View {
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(Theme.Colors.primary)
                .font(.subheadline)
            Text(date.thaiFullString)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Stats Card (Productivity Summary)

private struct StatItem: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    let icon: String
    let color: Color
}

struct StatsCard: View {
    let focusMinutesToday: Int
    let pendingCount: Int

    private var stats: [StatItem] {
        [
            StatItem(value: "\(focusMinutesToday) น.", label: "โฟกัสวันนี้", icon: "timer", color: Theme.Colors.warning),
            StatItem(value: "\(pendingCount)", label: "งานค้าง", icon: "checkmark.seal.fill", color: Theme.Colors.success),
        ]
    }

    var body: some View {
        CardContainer {
            Text("การเรียนวันนี้")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: 8) {
                ForEach(stats) { stat in
                    StatItemView(stat: stat)
                }
            }
        }
    }
}

private struct StatItemView: View {
    let stat: StatItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stat.color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: stat.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(stat.color)
            }
            Text(stat.value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(stat.label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Main Menu Section

private struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: DashboardDestination
    let tier: FeatureTier
}

struct MainMenuSection: View {
    private let menuItems: [MenuItem] = [
        MenuItem(title: "เกรด & GPA", subtitle: "ติดตามผลการเรียน", icon: "chart.bar.fill", color: Theme.Colors.primary, destination: .gradeCenter, tier: .free),
        MenuItem(title: "TCAS Planner", subtitle: "วางแผนสอบเข้า", icon: "target", color: Theme.Colors.info, destination: .tcasPlanner, tier: .free),
        MenuItem(title: "Portfolio", subtitle: "รวบรวมผลงาน", icon: "folder.fill", color: Theme.Colors.success, destination: .portfolio, tier: .free),
        MenuItem(title: "Career", subtitle: "สำรวจอาชีพ", icon: "briefcase.fill", color: Theme.Colors.warning, destination: .careerDiscovery, tier: .free),
        MenuItem(title: "งาน / การบ้าน", subtitle: "รายการงาน", icon: "checkmark.square.fill", color: Theme.Colors.info, destination: .assignments, tier: .free),
        MenuItem(title: "โฟกัส", subtitle: "Pomodoro Timer", icon: "timer", color: Theme.Colors.indigo, destination: .focusMode, tier: .free),
    ]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        CardContainer {
            Text("เมนูหลัก")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.textPrimary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(menuItems) { item in
                    NavigationLink(value: item.destination) {
                        MenuItemView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MenuItemView: View {
    let item: MenuItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(item.color)
                }
                if item.tier != .free {
                    TierBadge(tier: item.tier)
                        .offset(x: 8, y: -6)
                }
            }
            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pending Work Section (งานค้าง / งานที่ต้องส่งวันนี้)

struct PendingWorkSection: View {
    let dueToday: [Assignment]
    let pending: [Assignment]

    @State private var showAddTask = false

    var body: some View {
        CardContainer {
            HStack {
                Text("งานค้าง")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(pending.count) รายการ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("เพิ่มงาน")
            }
            if pending.isEmpty {
                EmptyRow(text: "ไม่มีงานค้าง 🎉")
            } else {
                ForEach(pending.prefix(4)) { assignment in
                    AssignmentRow(assignment: assignment, isDueToday: dueToday.contains(assignment))
                    if assignment.id != pending.prefix(4).last?.id {
                        Divider()
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet()
        }
    }
}

struct AssignmentRow: View {
    let assignment: Assignment
    var isDueToday: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isDueToday ? Theme.Colors.danger : Theme.Colors.primary)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Spacer()
            Text(assignment.resolvedDueDate?.thaiShortString ?? "ไม่กำหนดส่ง")
                .font(.caption2)
                .foregroundStyle(isDueToday ? Theme.Colors.danger : .secondary)
        }
        .padding(.vertical, 4)
    }
}

struct EmptyRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: [Assignment.self, FocusSession.self], inMemory: true)
}
