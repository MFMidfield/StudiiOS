//
//  FocusBreakPrompt.swift
//  ถามหลังจบรอบโฟกัส: "พัก 5 นาทีไหม"
//
//  5 นาทีคงที่ ผู้ใช้เลือกความยาวไม่ได้ (สเปค 15 ส.ค. 2569)
//  ไม่มีปุ่มปิด — ต้องเลือกอย่างใดอย่างหนึ่ง ไม่งั้นค้างอยู่ตรงนี้
//

import SwiftUI

struct FocusBreakPrompt: View {
    let onBreak: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Theme.Colors.focusBackdrop.opacity(0.92).ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Text("หมดเวลาโฟกัส")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.onFocusBackdrop)

                Text("พัก 5 นาทีก่อนไหม")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.onFocusBackdropMuted)

                VStack(spacing: Theme.Spacing.md) {
                    Button(action: onBreak) {
                        Text("พัก 5 นาที")
                            .font(Theme.Font.heading)
                            .foregroundStyle(Theme.Colors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.lg)
                            .background(Theme.Colors.primary, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    Button(action: onSkip) {
                        Text("ไม่พัก")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.onFocusBackdrop)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.lg)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, Theme.Spacing.lg)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
    }
}

#Preview {
    FocusBreakPrompt(onBreak: {}, onSkip: {})
}
