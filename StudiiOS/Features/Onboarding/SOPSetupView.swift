//
//  SOPSetupView.swift
//  หน้า 6 ของ setup — คณะที่อยากยื่น + เริ่มร่าง SOP
//
//  ใช้ `NewSOPTargetSheet` และ `SOPEditorView` ตัวเดียวกับในแอปจริง ไม่มีฟอร์มย่อ
//  เฉพาะ setup (แพตเทิร์นเดียวกับหน้าผลงานที่ใช้ `PortfolioItemSheet` ตัวเดิม)
//
//  ทุกอย่างในหน้านี้ข้ามได้ — ปุ่มล่างบอกตรงๆ ว่ายังไม่ได้เพิ่มอะไร
//

import SwiftUI
import SwiftData

struct SOPSetupView: View {
    let onBack: () -> Void
    let onNext: () -> Void

    @Query(sort: \SOPTarget.sortOrder) private var targets: [SOPTarget]

    @State private var isAddingTarget = false
    @State private var editingTarget: SOPTarget?

    var body: some View {
        OnboardingScaffold(
            step: .sop,
            onBack: onBack,
            primaryTitle: targets.isEmpty ? "ยังไม่มี ข้ามไปก่อน" : "ถัดไป",
            onPrimary: onNext
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                addButton
                if targets.isEmpty {
                    hint
                } else {
                    targetList
                }
            }
        }
        .sheet(isPresented: $isAddingTarget) {
            NewSOPTargetSheet()
        }
        // เปิดหน้าเขียนเป็น sheet ไม่ push — OnboardingScaffold ซ่อน nav bar ไว้
        // การ push ในนี้จะได้หน้าที่ไม่มีปุ่มย้อนกลับ
        .sheet(item: $editingTarget) { target in
            NavigationStack {
                SOPEditorView(target: target)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("เสร็จ") { editingTarget = nil }
                        }
                    }
            }
        }
    }

    // MARK: - ชิ้นส่วน

    private var addButton: some View {
        Button {
            isAddingTarget = true
        } label: {
            CardContainer {
                HStack(spacing: Theme.Spacing.lg) {
                    IconTile(systemName: "plus", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("เพิ่มคณะที่อยากยื่น")
                            .font(Theme.Font.plex(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("มหาวิทยาลัย · คณะ · สาขา")
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var hint: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Text("ยังไม่รู้ว่าจะยื่นที่ไหนก็ข้ามได้ เพิ่มทีหลังที่เมนู SOP ได้ตลอด — เขียนไว้ก่อนดีกว่ามาเริ่มเอาตอนใกล้ยื่น")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var targetList: some View {
        OnboardingSection(title: "เพิ่มแล้ว \(targets.count) ที่") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(targets) { target in
                    targetRow(target)
                }
            }
        }
    }

    private func targetRow(_ target: SOPTarget) -> some View {
        Button {
            editingTarget = target
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                IconTile(systemName: "graduationcap.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text(target.universityName)
                        .font(Theme.Font.plex(14, .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(target.facultyLine)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Text(statusText(for: target))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.primaryDeep)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statusText(for target: SOPTarget) -> String {
        let count = target.sop?.characterCount ?? 0
        return count > 0 ? "\(count.formatted()) ตัวอักษร" : "เขียน SOP"
    }
}

#Preview {
    NavigationStack {
        SOPSetupView(onBack: {}, onNext: {})
    }
    .modelContainer(for: [SOPTarget.self, SOPDocument.self], inMemory: true)
}
