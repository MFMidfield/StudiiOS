//
//  TCASWeightSetupView.swift
//  ตั้งน้ำหนัก % รายวิชาของ 1 คณะ — 2 โหมด: รายวิชา (กรอกทีละวิชา) กับ กลุ่ม
//  (เลือกกลุ่มสอบ เช่น A-Level แล้วหารเท่ากันให้ทุกวิชาที่เลือก, §7.2).
//  เปิดจาก TCASScoreCard เสมอ (เข้าซ้ำได้) และจาก NewTCASEntrySheet ครั้งแรกที่สร้างคณะ
//  (showsSkipButton = true ตอนนั้น).
//

import SwiftUI
import SwiftData

struct TCASWeightSetupView: View {
    @Bindable var entry: TCASEntry
    var showsSkipButton = false
    var onDone: (() -> Void)?

    @Environment(\.modelContext) private var context
    @State private var mode: EntryMode = .subject

    private enum EntryMode: String, CaseIterable {
        case subject = "รายวิชา"
        case group = "กลุ่ม"
    }

    private var totalPercent: Double {
        entry.weights.reduce(0) { $0 + $1.percent }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("น้ำหนักรวมตอนนี้")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Text(totalPercent, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(abs(totalPercent - 100) < 0.01 ? Theme.Colors.success : Theme.Colors.warning)
                    Text("%").foregroundStyle(Theme.Colors.textSecondary)
                }
                if abs(totalPercent - 100) > 0.01 {
                    Text("ไม่ครบ 100% ก็บันทึกได้ — บางคณะมีสัมภาษณ์/แฟ้มสะสมงานถ่วงน้ำหนักด้วย")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            if !entry.weights.isEmpty {
                Section("น้ำหนักที่ตั้งไว้") {
                    ForEach(sortedWeights) { weight in
                        weightRow(weight)
                    }
                    .onDelete(perform: deleteWeights)
                }
            }

            Section {
                Picker("โหมด", selection: $mode) {
                    ForEach(EntryMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowSeparator(.hidden)

            switch mode {
            case .subject: SubjectAddSection(entry: entry, context: context)
            case .group: GroupAddSection(entry: entry, context: context)
            }
        }
        .navigationTitle("ตั้งน้ำหนักคะแนน")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsSkipButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ข้ามก่อน") { onDone?() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { onDone?() }
                }
            }
        }
    }

    private var sortedWeights: [TCASScoreWeight] {
        entry.weights.sorted { $0.examCode < $1.examCode }
    }

    private func weightRow(_ weight: TCASScoreWeight) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(TCASExamCatalog.exam(code: weight.examCode)?.displayName ?? weight.examCode)
                    .font(.system(size: 14))
                if !weight.groupName.isEmpty {
                    Text("กลุ่ม \(weight.groupName) · รวม \(weight.groupPercent.formatted(.number.precision(.fractionLength(1))))%")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            Text(weight.percent, format: .number.precision(.fractionLength(2)))
                .font(.system(size: 14, weight: .semibold))
            Text("%").foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func deleteWeights(at offsets: IndexSet) {
        let weights = sortedWeights
        for i in offsets {
            let weight = weights[i]
            entry.weights.removeAll { $0.examCode == weight.examCode && $0.groupName == weight.groupName }
            context.delete(weight)
        }
    }
}

/// ฟอร์มเพิ่มน้ำหนักแบบรายวิชา — เลือกวิชา + กรอก % แล้วกด "เพิ่ม"
private struct SubjectAddSection: View {
    @Bindable var entry: TCASEntry
    let context: ModelContext

    @State private var examCode: String = TCASExamCatalog.all.first?.code ?? ""
    @State private var percentText: String = ""

    var body: some View {
        Section("เพิ่มรายวิชา") {
            Picker("วิชา", selection: $examCode) {
                ForEach(TCASExamCatalog.grouped, id: \.group) { section in
                    ForEach(section.exams) { exam in
                        Text(exam.displayName).tag(exam.code)
                    }
                }
            }
            TextField("น้ำหนัก %", text: $percentText)
                .keyboardType(.decimalPad)
            Button("เพิ่ม") { addWeight() }
                .disabled(Double(percentText) == nil || Double(percentText)! <= 0)
        }
    }

    private func addWeight() {
        guard let percent = Double(percentText), percent > 0 else { return }
        if let existing = entry.weights.first(where: { $0.examCode == examCode }) {
            context.delete(existing)
        }
        let weight = TCASScoreWeight(examCode: examCode, percent: percent, entry: entry)
        context.insert(weight)
        entry.weights.append(weight)
        percentText = ""
    }
}

/// ฟอร์มเพิ่มน้ำหนักแบบกลุ่ม — เลือกกลุ่มสอบ (TGAT/TPAT/A-Level) + % รวม + วิชาในกลุ่ม
/// แล้วหารเท่ากันให้ผ่าน TCASScoreEngine.setGroupPercent (§2.2/§7.2)
private struct GroupAddSection: View {
    @Bindable var entry: TCASEntry
    let context: ModelContext

    @State private var group: TCASExamGroup = .aLevel
    @State private var groupPercentText: String = ""
    @State private var selected: Set<String> = []

    private var members: [TCASExam] {
        TCASExamCatalog.grouped.first { $0.group == group }?.exams ?? []
    }

    var body: some View {
        Section("เพิ่มเป็นกลุ่ม") {
            Picker("กลุ่มสอบ", selection: $group) {
                ForEach(TCASExamGroup.allCases, id: \.self) { Text($0.thaiName).tag($0) }
            }
            .onChange(of: group) { _, _ in selected = [] }

            ForEach(members) { exam in
                Button {
                    if selected.contains(exam.code) { selected.remove(exam.code) }
                    else { selected.insert(exam.code) }
                } label: {
                    HStack {
                        Image(systemName: selected.contains(exam.code) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(exam.code) ? Theme.Colors.primaryDeep : Theme.Colors.textSecondary)
                        Text(exam.displayName)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
                .buttonStyle(.plain)
            }

            TextField("% รวมของกลุ่ม", text: $groupPercentText)
                .keyboardType(.decimalPad)

            if let groupPercent = Double(groupPercentText), !selected.isEmpty {
                let split = TCASScoreEngine.setGroupPercent(groupPercent: groupPercent, memberCount: selected.count)
                Text("วิชาละ \(split.formatted(.number.precision(.fractionLength(2))))%")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Button("เพิ่ม") { addGroupWeights() }
                .disabled(Double(groupPercentText) == nil || Double(groupPercentText)! <= 0 || selected.isEmpty)
        }
    }

    private func addGroupWeights() {
        guard let groupPercent = Double(groupPercentText), groupPercent > 0, !selected.isEmpty else { return }
        let split = TCASScoreEngine.setGroupPercent(groupPercent: groupPercent, memberCount: selected.count)
        for code in selected {
            if let existing = entry.weights.first(where: { $0.examCode == code }) {
                context.delete(existing)
            }
            let weight = TCASScoreWeight(examCode: code, percent: split, groupName: group.rawValue, groupPercent: groupPercent, entry: entry)
            context.insert(weight)
            entry.weights.append(weight)
        }
        selected = []
        groupPercentText = ""
    }
}
