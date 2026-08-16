//
//  FocusTagBar.swift
//  แถบเลือกแท็กใต้ตัวเลขเวลา — ไม่บังคับเลือก แตะซ้ำที่แท็กเดิม = ยกเลิกการเลือก
//

import SwiftUI

struct FocusTagBar: View {
    let tags: [FocusTag]
    @Binding var selectedID: String
    let onManage: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(tags) { tag in
                    chip(for: tag)
                }
                manageButton
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            // กันเส้นขอบ capsule โดน ScrollView ตัดบน-ล่าง — ของเดิมล็อกความสูงไว้ 44
            // ซึ่งเตี้ยกว่าชิปจริงเมื่อฟอนต์ไทยดันความสูงบรรทัดขึ้น
            .padding(.vertical, Theme.Spacing.xs)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(for tag: FocusTag) -> some View {
        let isSelected = tag.id == selectedID
        let color = Color(hex: tag.colorHex)

        return Button {
            selectedID = isSelected ? "" : tag.id
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(tag.name)
                    .font(Theme.Font.label)
                    .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? color.opacity(0.18) : Theme.Colors.cardBackground, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Theme.Colors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var manageButton: some View {
        Button(action: onManage) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.cardBackground, in: Capsule())
                .overlay(
                    Capsule().stroke(Theme.Colors.separator, lineWidth: 1)
                )
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
