//
//  WelcomeView.swift
//  First-launch onboarding: introduces Student OS's core principles
//  (Offline-first / Privacy-first / Thai-first / Subject-centric) before
//  handing off to RootTabView. Shown once — gated by
//  AppStorage("hasCompletedOnboarding") in RootContainerView.
//

import SwiftUI

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

struct WelcomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "graduationcap.fill",
            iconColor: Theme.Colors.primary,
            title: "ยินดีต้อนรับสู่ Student OS",
            description: "แอปจัดการชีวิตนักเรียนไทยแบบครบวงจร ตั้งแต่การเรียน วางแผนอาชีพ ไปจนถึงเตรียมเข้ามหาวิทยาลัย"
        ),
        OnboardingPage(
            icon: "wifi.slash",
            iconColor: Theme.Colors.success,
            title: "ใช้งานได้แบบ Offline 100%",
            description: "ข้อมูลทั้งหมดเก็บในเครื่องของคุณ ไม่ต้องล็อกอิน ไม่ต้องต่ออินเทอร์เน็ต เป็นส่วนตัวและปลอดภัย"
        ),
        OnboardingPage(
            icon: "book.closed.fill",
            iconColor: Theme.Colors.warning,
            title: "จัดการงานเรียนในที่เดียว",
            description: "งาน โน้ต Flashcards และเกรด จัดการได้ครบในแอปเดียว"
        ),
        OnboardingPage(
            icon: "target",
            iconColor: Theme.Colors.info,
            title: "วางแผนอนาคตของคุณ",
            description: "คำนวณเกรดและ GPAX วางแผน TCAS สร้าง Portfolio และค้นหาเส้นทางอาชีพที่ใช่"
        ),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                        
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    if pageIndex == pages.count - 1 {
                        Button {
                            hasCompletedOnboarding = true
                            dismiss()
                        } label: {
                            Text("เริ่มต้นใช้งาน")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.primary)
                    } else {
                        Button {
                            withAnimation { pageIndex += 1 }
                        } label: {
                            Text("ถัดไป")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.primary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Theme.Colors.background)
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(page.iconColor)
            }
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(page.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    WelcomeView()
}
