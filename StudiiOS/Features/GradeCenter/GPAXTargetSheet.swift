//
//  GPAXTargetSheet.swift
//  The one place the GPAX target is set. It replaces both the old inline
//  TargetQuickSetter (which vanished the moment a target existed) and the
//  Settings section — two editors for one number is how the two drifted apart.
//
//  Writes only through GPAXSettings.setTarget: the UserDefaults keys stay
//  private to that file.
//

import SwiftUI

struct GPAXTargetSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var source: String

    /// Common targets, so the usual case is one tap instead of a keypad.
    private let presets: [Double] = [3.00, 3.25, 3.50, 3.75, 4.00]

    init() {
        _text = State(initialValue: GPAXSettings.hasTarget
                      ? GPAXCalculator.formatted(GPAXSettings.target)
                      : "")
        _source = State(initialValue: GPAXSettings.targetSource)
    }

    private var parsed: Double? {
        Double(text.trimmingCharacters(in: .whitespaces))
    }

    private var isValid: Bool {
        guard let parsed else { return false }
        return parsed > 0 && parsed <= 4.0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("เช่น 3.50", text: $text)
                        .keyboardType(.decimalPad)
                        .font(Theme.Font.body)

                    presetRow
                } header: {
                    Text("เป้า GPAX")
                } footer: {
                    Text(isValid || text.isEmpty
                         ? "ใส่ได้ตั้งแต่ 0.01 ถึง 4.00"
                         : "ต้องเป็นตัวเลขระหว่าง 0.01 ถึง 4.00")
                    .foregroundStyle(isValid || text.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.danger)
                }

                Section {
                    TextField("เช่น วิศวะ จุฬาฯ", text: $source)
                        .font(Theme.Font.body)
                } header: {
                    Text("ตั้งเป้านี้เพราะ")
                } footer: {
                    Text("ไม่ใส่ก็ได้ — ไว้เตือนตัวเองว่าเป้านี้มาจากไหน")
                }

                if GPAXSettings.hasTarget {
                    Section {
                        Button("ลบเป้า", role: .destructive) {
                            GPAXSettings.setTarget(0, source: "")
                            AppLog.action("GPAX", "ลบเป้า")
                            dismiss()
                        }
                    } footer: {
                        Text("ลบแล้วตัวเลข \"ต้องได้เทอมละ...\" กับเส้นเป้าในกราฟจะหายไป")
                    }
                }
            }
            .themedFormBackground()
            .navigationTitle("ตั้งเป้า GPAX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก", action: save).disabled(!isValid)
                }
            }
        }
    }

    private var presetRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(presets, id: \.self) { value in
                let label = GPAXCalculator.formatted(value)
                Button {
                    text = label
                } label: {
                    Text(label)
                        .font(Theme.Font.plex(13, .medium))
                        .foregroundStyle(text == label ? Theme.Colors.onPrimary : Theme.Colors.primaryDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(text == label ? Theme.Colors.primary : Theme.Colors.primarySoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        guard let parsed else { return }
        GPAXSettings.setTarget(parsed, source: source.trimmingCharacters(in: .whitespacesAndNewlines))
        AppLog.action("GPAX", "ตั้งเป้า \(GPAXCalculator.formatted(parsed))")
        dismiss()
    }
}

#Preview {
    Text("").sheet(isPresented: .constant(true)) { GPAXTargetSheet() }
}
