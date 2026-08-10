//
//  AddSubjectSheet.swift
//  Form to create a new Subject, opened from AddScheduleEntrySheet's
//  subject picker (or standalone). Returns the created Subject to the
//  caller so it can be auto-selected.
//

import SwiftUI
import SwiftData

private let iconChoices = [
    "function", "atom", "book.closed.fill", "textformat.abc",
    "globe.asia.australia.fill", "flask.fill", "leaf.fill", "paintpalette.fill",
    "figure.run", "music.note", "hammer.fill", "desktopcomputer",
    "person.3.fill", "flag.fill", "fork.knife", "star.fill",
]

struct AddSubjectSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    let onCreated: (Subject) -> Void

    @State private var name = ""
    @State private var hasCode = false
    @State private var code = ""
    @State private var colorHex: String
    @State private var iconName = ScheduleConstants.defaultSubjectIcon
    @State private var isBreak = false

    init(onCreated: @escaping (Subject) -> Void) {
        self.onCreated = onCreated
        _colorHex = State(initialValue: "E1802F")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        !trimmedName.isEmpty && subjects.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicateName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ชื่อวิชา", text: $name)
                    if isDuplicateName {
                        Text("มีวิชานี้อยู่แล้ว")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.danger)
                    }

                    Toggle("ใส่รหัสวิชา", isOn: $hasCode.animation(.easeInOut(duration: 0.2)))
                    if hasCode {
                        TextField("รหัสวิชา", text: $code)
                    }
                }

                Section("สี") {
                    colorGrid
                }

                Section("ไอคอน") {
                    iconGrid
                }

                Section {
                    Toggle("เป็นช่วงพัก", isOn: $isBreak)
                    Text("จะแสดงเป็นแถบพิเศษ ไม่มีเลขคาบ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("เพิ่มวิชา")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: Theme.Spacing.sm) {
            ForEach(Theme.Colors.subjectPaletteHex, id: \.self) { hex in
                ZStack {
                    Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                    if colorHex == hex {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .onTapGesture { colorHex = hex }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Theme.Spacing.md) {
            ForEach(iconChoices, id: \.self) { icon in
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(iconName == icon ? Color(hex: colorHex).opacity(0.15) : Theme.Colors.surfaceRaised)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundStyle(iconName == icon ? Color(hex: colorHex) : Theme.Colors.textSecondary)
                }
                .onTapGesture { iconName = icon }
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        guard canSave else { return }
        let subject = Subject(
            name: trimmedName,
            code: hasCode ? code.trimmingCharacters(in: .whitespaces) : "",
            colorHex: colorHex,
            iconName: iconName,
            isBreak: isBreak
        )
        context.insert(subject)
        AppLog.action("Subject", "เพิ่มวิชา: \(subject.name) (\(subject.code)) สี=#\(subject.colorHex) ไอคอน=\(subject.iconName) isBreak=\(subject.isBreak)")
        onCreated(subject)
        dismiss()
    }
}

#Preview {
    AddSubjectSheet(onCreated: { _ in })
        .modelContainer(for: [Subject.self], inMemory: true)
}
