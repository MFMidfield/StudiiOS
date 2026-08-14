//
//  DashboardView.swift
//  Dashboard module: คาบเรียนถัดไป, สรุปวันนี้, เมนูหลัก, งานค้าง, GPAX.
//  Body kept intentionally thin — each section is its own file (see
//  GPAXDashboardCard.swift's header comment for why) both to dodge
//  SwiftUI type-check timeouts and to keep this file reviewable.
//

import SwiftUI
import SwiftData
import UIKit

struct DashboardView: View {
    @Query(sort: \Assignment.dueDate) private var assignments: [Assignment]
    @Query private var focusSessions: [FocusSession]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }
    private var scopedAssignments: [Assignment] { assignments.inTerm(activeTerm) }

    @State private var hasAppeared = false

    private var today: Date { .now }

    private var pendingAssignments: [Assignment] {
        scopedAssignments.filter { !$0.isDone }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                HeaderSection(date: today)
                DashboardNextClassCard()
                DashboardStatsCard(
                    focusMinutesToday: focusMinutesToday,
                    pendingCount: pendingAssignments.count
                )
                DashboardMenuGrid()
                DashboardPendingCard(pending: pendingAssignments)
                GPAXDashboardCard()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
        }
        // The background reaches under the status bar, the content doesn't —
        // this replaces the old `.ignoresSafeArea(edges: .top)` + a hardcoded
        // 60pt top padding, which only lined up on Dynamic Island devices.
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                hasAppeared = true
            }
        }
    }

    private var focusMinutesToday: Int {
        // นับเฉพาะช่วง "โฟกัส" — ช่วงพักถูกบันทึกเป็น FocusSession ด้วยตั้งแต่
        // รอบ Pomodoro อัตโนมัติ ถ้าไม่กรองตัวเลขจะเฟ้อ
        let seconds = focusSessions
            .filter { $0.phase == .focus && Calendar.current.isDateInToday($0.startedAt) && $0.completed }
            .reduce(0) { $0 + $1.durationSeconds }
        return seconds / 60
    }
}

// MARK: - Header Section

/// Date + greeting + name + avatar. The date line used to be its own card
/// (`DateBadge`) below this — a whole card spent on one line of text.
struct HeaderSection: View {
    let date: Date

    @State private var profile = StudentProfileStore.shared

    private var displayName: String {
        if !profile.nickname.isEmpty { return profile.nickname }
        if !profile.firstName.isEmpty { return profile.firstName }
        return "ยินดีต้อนรับ"
    }

    /// Greeting + emoji that actually track the wall clock, instead of the
    /// old hardcoded "สวัสดีตอนเช้า" shown at every hour of the day.
    private var greeting: (text: String, emoji: String) {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return ("สวัสดีตอนเช้า", "🌤")
        case 12..<17: return ("สวัสดีตอนบ่าย", "☀️")
        case 17..<21: return ("สวัสดีตอนเย็น", "🌆")
        default: return ("ดึกแล้ว พักผ่อนบ้างนะ", "🌙")
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .medium))
                    Text(date.thaiFullString)
                        .font(Theme.Font.caption)
                }
                .foregroundStyle(Theme.Colors.textSecondary)

                HStack(spacing: 5) {
                    Text(greeting.text)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(greeting.emoji)
                        .font(Theme.Font.label)
                }

                Text(displayName)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            AvatarView()
        }
        .padding(.top, Theme.Spacing.sm)
    }
}

struct AvatarView: View {
    /// 34 matches the icon tiles elsewhere on the Dashboard — at the old 60 the
    /// avatar outweighed the greeting it sits next to.
    var size: CGFloat = 34

    @State private var profile = StudentProfileStore.shared

    var body: some View {
        Group {
            if let profileImage = profile.cachedProfileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.Colors.primarySoft)
        .clipShape(Circle())
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    // Every child card runs its own @Query — a type missing here crashes the
    // preview, not the app.
    .modelContainer(
        for: [
            Assignment.self, FocusSession.self, Term.self, TermSubject.self,
            Subject.self, ScheduleEntry.self, DayScheduleOverride.self,
        ],
        inMemory: true
    )
}
