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

    /// The app only knows ม.ปลาย now, so this always has something to say.
    private var progressText: String {
        let sortKey = gradeLevel * 10 + termNumber
        let passed = GPAXCalculator.upperBandSortKeys.filter { $0 < sortKey }.count
        let remaining = GPAXCalculator.upperBandSortKeys.filter { $0 >= sortKey }.count
        return "ผ่านมาแล้ว \(passed) เทอม · เหลืออีก \(remaining) เทอม"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ระดับชั้น") {
                    chipRow(values: SchoolBand.upper.gradeLevels, selection: $gradeLevel) { "ม.\($0)" }
                }
                Section("เทอม") {
                    chipRow(values: [1, 2], selection: $termNumber) { "เทอม \($0)" }
                }

                Section {
                    Text(progressText)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
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
