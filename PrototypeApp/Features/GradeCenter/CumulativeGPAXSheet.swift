//
//  CumulativeGPAXSheet.swift
//  Screen 4 (§6.4) — "I don't remember individual terms."
//  Reached from TermGradeEditView's "จำเกรดเทอมนี้ไม่ได้" link.
//

import SwiftUI
import SwiftData

struct CumulativeGPAXSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Lets the presenting screen (or its own sheet) close too once this flow finishes.
    var onDone: () -> Void = {}

    @State private var gpaxText = ""
    @State private var termCountText = ""

    private var parsedGPAX: Double? { Double(gpaxText) }
    private var parsedTermCount: Int? { Int(termCountText) }
    private var gpaxIsValid: Bool { parsedGPAX.map { (0.0...4.0).contains($0) } ?? false }
    private var canUseCumulative: Bool { gpaxIsValid && (parsedTermCount.map { $0 > 0 } ?? false) }

    var body: some View {
        NavigationStack {
            Form {
                Section("รู้ GPAX สะสมล่าสุด") {
                    TextField("เช่น 3.29", text: $gpaxText)
                        .keyboardType(.decimalPad)
                    TextField("จำนวนเทอมที่ผ่านมา", text: $termCountText)
                        .keyboardType(.numberPad)
                    Text("เลขนี้อยู่ท้ายใบ ปพ.1")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Button("ใช้ค่านี้") { useCumulative() }
                        .disabled(!canUseCumulative)
                }

                Section {
                    Button("เว้นไว้ก่อน") {
                        onDone()
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                Section {
                    Button("ขอใบ ปพ.1 จากฝ่ายทะเบียน") { requestTranscriptReminder() }
                }
            }
            .navigationTitle("จำเกรดเทอมนี้ไม่ได้")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
    }

    private func useCumulative() {
        guard let gpax = parsedGPAX, let count = parsedTermCount else { return }
        GPAXSettings.setCumulative(gpax: gpax, credits: nil, termCount: count)
        GPAXSettings.setEntryMode(.cumulative)
        onDone()
        dismiss()
    }

    private func requestTranscriptReminder() {
        let event = CalendarEvent(
            title: "ขอใบ ปพ.1 จากฝ่ายทะเบียน",
            startDate: .now,
            endDate: .now,
            isAllDay: true
        )
        context.insert(event)
        try? context.save()
        onDone()
        dismiss()
    }
}

#Preview {
    CumulativeGPAXSheet()
        .modelContainer(for: [CalendarEvent.self], inMemory: true)
}
