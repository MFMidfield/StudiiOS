//
//  FocusTagEditorSheet.swift
//  จัดการแท็กโฟกัส — เพิ่ม / เปลี่ยนชื่อ / เปลี่ยนสี / ลบ
//
//  สีมาจาก `Theme.Colors.subjectPaletteHex` ชุดเดียวกับสีวิชา (8 สี)
//  ลบแท็กไม่กระทบสถิติเก่า — `FocusSession` เก็บสำเนาชื่อ/สีไว้ในตัวเอง
//

import SwiftUI
import SwiftData

struct FocusTagEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusTag.order) private var tags: [FocusTag]

    @State private var newName = ""
    @State private var newColorHex = Theme.Colors.subjectPaletteHex.first ?? "C96F4A"
    @State private var editingTag: FocusTag?

    private var palette: [String] { Theme.Colors.subjectPaletteHex }

    var body: some View {
        NavigationStack {
            List {
                Section("แท็กของฉัน") {
                    ForEach(tags) { tag in
                        row(for: tag)
                    }
                    .onDelete(perform: delete)
                }

                Section("เพิ่มแท็กใหม่") {
                    TextField("ชื่อแท็ก", text: $newName)
                        .font(Theme.Font.body)

                    colorPicker(selected: $newColorHex)

                    Button {
                        addTag()
                    } label: {
                        Label("เพิ่มแท็ก", systemImage: "plus.circle.fill")
                    }
                    .disabled(trimmedNewName.isEmpty)
                }
            }
            .themedFormBackground()
            .navigationTitle("แท็ก")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
            .sheet(item: $editingTag) { tag in
                FocusTagRenameSheet(tag: tag, palette: palette)
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - แถวแท็ก

    private func row(for tag: FocusTag) -> some View {
        Button {
            editingTag = tag
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 14, height: 14)
                Text(tag.name)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - เลือกสี

    @ViewBuilder
    private func colorPicker(selected: Binding<String>) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(palette, id: \.self) { hex in
                Button {
                    selected.wrappedValue = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .stroke(Theme.Colors.textPrimary, lineWidth: selected.wrappedValue == hex ? 2.5 : 0)
                                .padding(-3)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - การกระทำ

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addTag() {
        let name = trimmedNewName
        guard !name.isEmpty else { return }
        let nextOrder = (tags.map(\.order).max() ?? -1) + 1
        context.insert(FocusTag(name: name, colorHex: newColorHex, order: nextOrder))
        try? context.save()
        newName = ""
        newColorHex = palette.first ?? "C96F4A"
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(tags[index])
        }
        try? context.save()
    }
}

/// แก้ชื่อ/สีของแท็กเดิม
struct FocusTagRenameSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let tag: FocusTag
    let palette: [String]

    @State private var name = ""
    @State private var colorHex = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("ชื่อ") {
                    TextField("ชื่อแท็ก", text: $name)
                        .font(Theme.Font.body)
                }
                Section("สี") {
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(palette, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.Colors.textPrimary, lineWidth: colorHex == hex ? 2.5 : 0)
                                            .padding(-3)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .themedFormBackground()
            .navigationTitle("แก้ไขแท็ก")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = tag.name
                colorHex = tag.colorHex
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        tag.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.colorHex = colorHex
        try? context.save()
        dismiss()
    }
}
