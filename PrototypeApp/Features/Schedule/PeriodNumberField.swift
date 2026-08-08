//
//  PeriodNumberField.swift
//  The "คาบที่" control, shared by AddScheduleEntrySheet and
//  ScheduleImportRowEditSheet so both screens offer the same thing: a picker
//  for the ordinary 0–10, plus a "กำหนดเอง" escape hatch for schools that
//  number periods some other way.
//
//  Renders Form rows only, never a Section.
//

import SwiftUI

enum PeriodChoice: Hashable {
    case number(Int)
    case custom
}

struct PeriodNumberField: View {
    @Binding var periodNumber: Int

    @State private var choice: PeriodChoice = .number(0)
    @State private var customText: String = ""

    // @ViewBuilder rather than a Group: the rows go straight into the caller's
    // Form, and Group's overload set (View / Scene / TableColumn / …) is
    // needlessly ambiguous here.
    @ViewBuilder
    var body: some View {
        picker

        if choice == .custom {
            TextField("เลขคาบ", text: $customText)
                .keyboardType(.numberPad)
                .onChange(of: customText) { _, new in customTextChanged(new) }
        }
    }

    /// The lifecycle modifiers live on the picker, which is always present —
    /// spread across the rows they would run once per row instead.
    private var picker: some View {
        Picker("คาบที่", selection: $choice) {
            ForEach(0...10, id: \.self) { n in
                Text("\(n)").tag(PeriodChoice.number(n))
            }
            Text("กำหนดเอง").tag(PeriodChoice.custom)
        }
        .onAppear(perform: syncFromBinding)
        .onChange(of: choice) { _, new in choiceChanged(new) }
    }

    private func syncFromBinding() {
        if (0...10).contains(periodNumber) {
            choice = .number(periodNumber)
            customText = ""
        } else {
            choice = .custom
            customText = String(periodNumber)
        }
    }

    private func choiceChanged(_ new: PeriodChoice) {
        switch new {
        case .number(let n):
            periodNumber = n
        case .custom:
            // A blank or half-typed custom field leaves the last good number
            // alone; zeroing it would silently move the row to คาบ 0.
            if let n = Int(customText) { periodNumber = n }
        }
    }

    private func customTextChanged(_ new: String) {
        guard let n = Int(new) else { return }
        periodNumber = n
    }
}
