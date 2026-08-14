//
//  GradeLevelSheet.swift
//  Screen 1 (§6.1) — the student's REAL current term, written to GPAXSettings.
//  Distinct from TermStore.activeTermKey (the term being browsed) — see D7.
//  Shown once on first use, and reachable again from Settings as "ขึ้นชั้นแล้ว".
//

import SwiftUI

struct GradeLevelSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var gradeLevel: Int
    @State private var termNumber: Int

    init() {
        _gradeLevel = State(initialValue: GPAXSettings.currentGradeLevel ?? 4)
        _termNumber = State(initialValue: GPAXSettings.currentTermNumber ?? 1)
    }

    private var band: SchoolBand { SchoolBand.containing(gradeLevel: gradeLevel) }

    /// nil for ม.1–ม.3 — GPAX for TCAS only counts ม.ปลาย (D5), so the
    /// passed/remaining count against the 6 upper-band slots is meaningless there.
    private var progressText: String? {
        guard band == .upper else { return nil }
        let sortKey = gradeLevel * 10 + termNumber
        let passed = GPAXCalculator.upperBandSortKeys.filter { $0 < sortKey }.count
        let remaining = GPAXCalculator.upperBandSortKeys.filter { $0 >= sortKey }.count
        return "ผ่านมาแล้ว \(passed) เทอม · เหลืออีก \(remaining) เทอม"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ระดับชั้น") {
                    chipRow(values: Array(1...6), selection: $gradeLevel) { "ม.\($0)" }
                }
                Section("เทอม") {
                    chipRow(values: [1, 2], selection: $termNumber) { "เทอม \($0)" }
                }

                if let progressText {
                    Section {
                        Text(progressText)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                if band == .lower {
                    Section {
                        Text("GPAX สำหรับ TCAS นับเฉพาะ ม.ปลาย (ม.4–ม.6) — ตั้งไว้ก่อนได้ ระบบจะเริ่มคำนวณตอนขึ้น ม.4")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("ระดับชั้นปัจจุบัน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        GPAXSettings.setCurrentTerm(gradeLevel: gradeLevel, termNumber: termNumber)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipRow(values: [Int], selection: Binding<Int>, label: @escaping (Int) -> String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(values, id: \.self) { value in
                let isSelected = selection.wrappedValue == value
                Button {
                    selection.wrappedValue = value
                } label: {
                    Text(label(value))
                        .font(Theme.Font.plex(14, .medium))
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(isSelected ? Theme.Colors.primary : Theme.Colors.background)
                        .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    GradeLevelSheet()
}
