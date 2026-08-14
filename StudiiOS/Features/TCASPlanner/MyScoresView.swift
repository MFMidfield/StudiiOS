//
//  MyScoresView.swift
//  คะแนนสอบของผู้ใช้ — ชุดเดียวใช้ร่วมทุกคณะ (ค้นด้วย examCode, ไม่ผูก TCASEntry)
//  เปิดจาก Section บนสุดของ TCASPlannerView (§9 การตัดสินใจข้อ 1)
//

import SwiftUI
import SwiftData

struct MyScoresView: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [TCASScoreRecord]

    var body: some View {
        List {
            ForEach(TCASExamCatalog.grouped, id: \.group) { section in
                Section(section.group.thaiName) {
                    ForEach(section.exams) { exam in
                        ScoreRow(
                            exam: exam,
                            record: record(for: exam.code),
                            onChange: { score, hasTaken in update(exam: exam, score: score, hasTaken: hasTaken) }
                        )
                    }
                }
            }
        }
        .navigationTitle("คะแนนสอบของฉัน")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func record(for code: String) -> TCASScoreRecord? {
        records.first { $0.examCode == code }
    }

    private func update(exam: TCASExam, score: Double, hasTaken: Bool) {
        if let existing = record(for: exam.code) {
            existing.score = score
            existing.hasTaken = hasTaken
            existing.takenAt = Date.now
        } else {
            let newRecord = TCASScoreRecord(examCode: exam.code, score: score, hasTaken: hasTaken)
            context.insert(newRecord)
        }
    }
}

private struct ScoreRow: View {
    let exam: TCASExam
    let record: TCASScoreRecord?
    let onChange: (Double, Bool) -> Void

    private var scoreBinding: Binding<Double> {
        Binding(
            get: { record?.score ?? 0 },
            set: { onChange($0, record?.hasTaken ?? false) }
        )
    }

    private var hasTakenBinding: Binding<Bool> {
        Binding(
            get: { record?.hasTaken ?? false },
            set: { onChange(record?.score ?? 0, $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(exam.displayName)
                    .font(.system(size: 14))
                Spacer()
                TextField("0", value: scoreBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Text("/ \(Int(exam.fullScore))")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Toggle("สอบไปแล้ว", isOn: hasTakenBinding)
                .font(.caption)
        }
    }
}
