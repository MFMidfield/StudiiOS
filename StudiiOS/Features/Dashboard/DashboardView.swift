//
//  DashboardView.swift
//  Dashboard module: คาบเรียนถัดไป, สถิติวันนี้, เมนูหลัก, งานค้าง.
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
                HeaderSection()
                DateBadge(date: today)
                DashboardNextClassCard()
                DashboardStatsCard(
                    focusMinutesToday: focusMinutesToday,
                    pendingCount: pendingAssignments.count
                )
                GPAXDashboardCard()
                DashboardMenuGrid()
                DashboardPendingCard(pending: pendingAssignments)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
        }
        .background(Theme.Colors.background)
        .ignoresSafeArea(edges: .top)
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

struct HeaderSection: View {
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(greeting.text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(greeting.emoji)
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
                .fill(Theme.Colors.primary.opacity(0.14))
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
                    .foregroundStyle(Theme.Colors.primaryDeep)
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
                .foregroundStyle(Theme.Colors.primaryDeep)
                .font(.subheadline)
            Text(date.thaiFullString)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.cardStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: [Assignment.self, FocusSession.self, Term.self, TermSubject.self], inMemory: true)
}
