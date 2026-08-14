//
//  TCASTargetSheet.swift
//  ตั้งคะแนนเป้าของ 1 คณะ — แทน TextField "0 = ไม่ระบุเป้า" ในหน้ารายละเอียด
//
//  ปัญหาเดิม: placeholder หายทันทีที่พิมพ์ พิมพ์ 0 แล้วดูเหมือนตั้งเป้าไว้ 0 คะแนน
//  → ทำให้ "ไม่ระบุเป้า" เป็นปุ่มแยก ผู้ใช้ไม่ต้องรู้ว่า 0 มีความหมายพิเศษ (§4.3)
//

import SwiftUI

struct TCASTargetSheet: View {
    @Bindable var entry: TCASEntry
    /// คะแนนสูงสุดที่เป็นไปได้ด้วยน้ำหนักชุดปัจจุบัน — ใช้เตือนเมื่อเป้าสูงเกินเพดาน
    let ceiling: Double

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Double

    private static let shortcuts: [Double] = [50, 60, 70, 80]

    init(entry: TCASEntry, ceiling: Double) {
        self.entry = entry
        self.ceiling = ceiling
        _draft = State(initialValue: entry.targetScore)
    }

    private var isAboveCeiling: Bool { draft > ceiling + 0.01 }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                inputRow
                shortcutRow
                if isAboveCeiling {
                    Text("เป้านี้สูงกว่าคะแนนสูงสุดที่เป็นไปได้ (\(ceiling.formatted(.number.precision(.fractionLength(1))))) — ต้องเพิ่มน้ำหนักวิชาหรือปรับเป้า")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.warning)
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.background)
            .navigationTitle("คะแนนเป้าหมาย")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("ไม่ระบุเป้า") {
                        entry.targetScore = 0
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("บันทึก") {
                        entry.targetScore = min(max(draft, 0), 100)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(260)])
    }

    private var inputRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            TextField("0", value: $draft, format: .number)
                .keyboardType(.decimalPad)
                .font(Theme.Font.number(28))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("/ 100")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Colors.cardBackground)
        )
    }

    private var shortcutRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Self.shortcuts, id: \.self) { value in
                Button {
                    draft = value
                } label: {
                    Text(value.formatted(.number.precision(.fractionLength(0))))
                        .font(Theme.Font.plex(14, .medium))
                        .foregroundStyle(
                            abs(draft - value) < 0.01 ? Theme.Colors.onPrimary : Theme.Colors.primaryDeep
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            abs(draft - value) < 0.01 ? Theme.Colors.primary : Theme.Colors.primarySoft,
                            in: Capsule()
                        )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }
}
