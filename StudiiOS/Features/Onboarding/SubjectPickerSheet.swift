//
//  SubjectPickerSheet.swift
//  เลือกวิชาจากรายการคงที่ — กลุ่มสาระ → รายวิชา
//
//  หน้า setup ไม่ให้พิมพ์ชื่อวิชาเองเป็นค่าเริ่มต้น: ชื่อที่พิมพ์เองสะกดไม่เหมือนกัน
//  ทุกครั้ง แล้วเกรดกับตารางก็จับคู่วิชาเดียวกันไม่ได้ รายชื่อทั้งหมดมาจาก
//  `ThaiCourseCatalog` ที่เดียว
//
//  ใช้ 2 ที่: หน้า 3 (เพิ่มคาบเรียนเอง) และหน้า 4 (เพิ่มวิชาในเกรดละเอียด)
//  หน้า 4 เปิด `allowsCustomName` เพราะเกรดเก่าอาจมีวิชาที่หลักสูตรกลางไม่มี
//

import SwiftUI

struct SubjectPickerSheet: View {
    /// true = มีช่อง "พิมพ์ชื่อเอง" ท้ายรายการ
    var allowsCustomName: Bool = false
    /// strand ติดไปด้วยเพื่อให้วิชาที่สร้างใหม่ได้สีของกลุ่มสาระตัวเอง
    let onPick: (_ name: String, _ strand: ThaiSubjectStrand?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var customName = ""

    private var matches: [(name: String, strand: ThaiSubjectStrand)] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return ThaiCourseCatalog.allCourses.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    groupList
                } else {
                    searchResults
                }
                if allowsCustomName {
                    customSection
                }
            }
            .navigationTitle("เลือกวิชา")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "ค้นหาวิชา")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
            }
        }
    }

    // MARK: - Lists

    private var groupList: some View {
        ForEach(ThaiCourseCatalog.groups) { group in
            NavigationLink {
                courseList(for: group)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    IconTile(systemName: group.iconName, color: Color(hex: group.colorHex))
                    Text(group.name)
                        .font(Theme.Font.body)
                    Spacer()
                    Text("\(group.courses.count)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    private func courseList(for group: ThaiCourseGroup) -> some View {
        List {
            ForEach(group.strands, id: \.self) { strand in
                Section(group.strands.count > 1 ? strand.displayName : "") {
                    ForEach(ThaiCourseCatalog.courses(for: strand), id: \.self) { course in
                        Button {
                            pick(course, strand)
                        } label: {
                            Text(course)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchResults: some View {
        Section {
            if matches.isEmpty {
                Text("ไม่พบวิชาที่ค้นหา")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            ForEach(matches, id: \.name) { match in
                Button {
                    pick(match.name, match.strand)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.name)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(ThaiCourseCatalog.group(forCourse: match.name)?.name ?? match.strand.displayName)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    private var customSection: some View {
        Section {
            TextField("ชื่อวิชา", text: $customName)
            Button("ใช้ชื่อนี้") {
                pick(customName.trimmingCharacters(in: .whitespaces), nil)
            }
            .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            Text("ไม่มีในรายการ")
        } footer: {
            Text("ใช้เมื่อวิชานั้นไม่มีในหลักสูตรกลาง เช่น วิชาเฉพาะของโรงเรียน")
        }
    }

    private func pick(_ name: String, _ strand: ThaiSubjectStrand?) {
        guard !name.isEmpty else { return }
        onPick(name, strand)
        dismiss()
    }
}

#Preview {
    SubjectPickerSheet(allowsCustomName: true) { _, _ in }
}
