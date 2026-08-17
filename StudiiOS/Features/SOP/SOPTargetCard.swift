//
//  SOPTargetCard.swift
//  การ์ด 1 ใบ = 1 คณะที่ตั้งใจยื่น — มหาวิทยาลัย · คณะ · สาขา + สถานะ SOP
//
//  แถบล่างของการ์ดคือสัญญาณเดียวว่า "แตะแล้วได้เขียน SOP" — ของเดิม (TCASEntryCard)
//  โชว์คะแนน/เปอร์เซ็นต์ซึ่งไม่มีอยู่ในระบบแล้ว
//

import SwiftUI

struct SOPTargetCard: View {
    let target: SOPTarget

    private var characterCount: Int { target.sop?.characterCount ?? 0 }
    private var hasWriting: Bool { characterCount > 0 }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(target.universityName)
                    .font(Theme.Font.plex(17, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(target.facultyLine)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: hasWriting ? "doc.text.fill" : "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)

                Text(statusText)
                    .font(Theme.Font.plex(13, .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var statusText: String {
        hasWriting
            ? "เขียนแล้ว \(characterCount.formatted()) ตัวอักษร — แตะเพื่อแก้"
            : "ยังไม่ได้เขียน SOP — แตะเพื่อเริ่ม"
    }
}
