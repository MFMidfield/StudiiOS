//
//  MyScoresView.swift
//  คะแนนสอบของผู้ใช้ — ชุดเดียวใช้ร่วมทุกคณะ (ค้นด้วย examCode, ไม่ผูก TCASEntry)
//  เปิดจากการ์ดบนสุดของ TCASPlannerView
//
//  🔴 กฎที่พลาดไม่ได้ (06_TCAS §4.4): "ยังไม่กรอก" กับ "กรอกว่า 0" ไม่ใช่เรื่องเดียวกัน
//  TCASScoreEngine.breakdown() ตัดสิน "ยังไม่ระบุ" จาก **การไม่มี record** ไม่ใช่จาก hasTaken
//  → ลบช่องจนว่าง ต้อง context.delete(record) เท่านั้น ห้ามทิ้ง record ที่ score = 0 ไว้
//  ไม่งั้นคะแนนรวมของทุกคณะที่ใช้วิชานั้นจะถูกนับเป็น 0 เงียบๆ
//
//  Toggle "สอบไปแล้ว" ถูกตัดทิ้ง — กรอกคะแนน = สอบแล้วโดยอัตโนมัติ UI เป็นคนตั้ง
//  hasTaken ให้ ไม่ใช่ผู้ใช้กดเอง (model ไม่ถูกแตะ · requiredAverage ยังใช้ hasTaken เหมือนเดิม)
//

import SwiftUI
import SwiftData

struct MyScoresView: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [TCASScoreRecord]
    @Query(sort: \TCASEntry.sortOrder) private var entries: [TCASEntry]

    /// คะแนนของแต่ละคณะ ณ ตอนเปิดหน้า — ใช้เทียบว่าที่กรอกไปเมื่อครู่ดันคณะไหนขึ้น
    /// ไม่ได้เก็บลงฐานข้อมูล หายเมื่อออกจากหน้า (§4.5)
    @State private var openingScores: [PersistentIdentifier: Double] = [:]

    var body: some View {
        List {
            ForEach(TCASExamCatalog.grouped, id: \.group) { section in
                Section {
                    ForEach(section.exams) { exam in
                        ScoreRow(
                            exam: exam,
                            record: record(for: exam.code),
                            onChange: { update(exam: exam, score: $0) }
                        )
                    }
                } header: {
                    sectionHeader(section)
                }
            }

            if !entries.isEmpty {
                impactSection
            }
        }
        .navigationTitle("คะแนนสอบของฉัน")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: captureOpeningScores)
    }

    // MARK: - หัว Section

    private func sectionHeader(_ section: (group: TCASExamGroup, exams: [TCASExam])) -> some View {
        HStack {
            Text(section.group.thaiName)
            Spacer()
            Text("กรอกแล้ว \(filledCount(in: section.exams))/\(section.exams.count)")
        }
    }

    private func filledCount(in exams: [TCASExam]) -> Int {
        exams.filter { record(for: $0.code) != nil }.count
    }

    // MARK: - มีผลกับคณะเป้าหมาย (§4.5)
    //
    // อ่านอย่างเดียว ไม่เขียนอะไรกลับ — ตอบคำถาม "กรอกไปแล้วมันไปโผล่ที่ไหน"

    private var impactSection: some View {
        Section {
            ForEach(entries) { entry in
                impactRow(entry)
            }
        } header: {
            Text("มีผลกับคณะเป้าหมาย")
        }
    }

    private func impactRow(_ entry: TCASEntry) -> some View {
        let now = currentScore(of: entry)
        let before = openingScores[entry.persistentModelID]
        let changed = before.map { abs($0 - now) > 0.01 } ?? false
        return HStack {
            Text("\(entry.facultyName) \(entry.universityName)")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.sm)
            if changed, let before {
                Text("\(before.formatted(.number.precision(.fractionLength(1)))) → \(now.formatted(.number.precision(.fractionLength(1))))")
                    .font(Theme.Font.plex(13, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.primaryDeep)
                Image(systemName: now > before ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(now > before ? Theme.Colors.success : Theme.Colors.textSecondary)
            } else {
                Text(now, format: .number.precision(.fractionLength(1)))
                    .font(Theme.Font.label)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private func captureOpeningScores() {
        guard openingScores.isEmpty else { return }
        for entry in entries {
            openingScores[entry.persistentModelID] = currentScore(of: entry)
        }
    }

    private func currentScore(of entry: TCASEntry) -> Double {
        let weights = entry.weights.map {
            TCASWeightInput(examCode: $0.examCode, percent: $0.percent, groupName: $0.groupName, groupPercent: $0.groupPercent)
        }
        let scores = records.map {
            TCASScoreInput(examCode: $0.examCode, score: $0.score, hasTaken: $0.hasTaken)
        }
        return TCASScoreEngine.currentScore(weights: weights, scores: scores)
    }

    // MARK: - Data

    private func record(for code: String) -> TCASScoreRecord? {
        records.first { $0.examCode == code }
    }

    /// `nil` = ผู้ใช้ลบจนช่องว่าง → ต้องลบ record ทิ้ง ไม่ใช่ตั้ง score = 0 (ดูหัวไฟล์)
    private func update(exam: TCASExam, score: Double?) {
        let existing = record(for: exam.code)
        guard let score else {
            if let existing { context.delete(existing) }
            return
        }
        if let existing {
            existing.score = score
            existing.hasTaken = true
            existing.takenAt = .now
        } else {
            context.insert(TCASScoreRecord(examCode: exam.code, score: score, hasTaken: true))
        }
    }
}

// MARK: - แถวรายวิชา

private struct ScoreRow: View {
    let exam: TCASExam
    let record: TCASScoreRecord?
    let onChange: (Double?) -> Void

    /// ถือข้อความที่ผู้ใช้กำลังพิมพ์เอง — ผูก TextField กับตัวเลขที่ format ใหม่ทุก
    /// keystroke จะแย่งเคอร์เซอร์ตอนพิมพ์ทศนิยม
    @State private var text = ""

    private var hasScore: Bool { !text.isEmpty }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(exam.displayName)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: Theme.Spacing.sm)
            TextField("—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
                .font(hasScore ? Theme.Font.plex(15, .semibold) : Theme.Font.body)
                .foregroundStyle(hasScore ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .onChange(of: text) { _, newValue in commit(newValue) }
            Text("/ \(Int(exam.fullScore))")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .onAppear {
            text = record.map { Self.format($0.score) } ?? ""
        }
    }

    private func commit(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onChange(nil)
            return
        }
        // "12." ระหว่างพิมพ์ยังแปลงไม่ได้ — ปล่อยไว้ก่อน อย่าเพิ่งเขียนลงฐานข้อมูล
        guard let value = Double(trimmed) else { return }
        guard value <= exam.fullScore else {
            // พิมพ์เกินคะแนนเต็ม (เช่น 3000 ในวิชาเต็ม 100) จะทำให้คะแนนรวมของทุกคณะ
            // ที่ใช้วิชานี้เพี้ยน — ดึงกลับมาที่เพดานแล้วแก้ข้อความให้ตรงกับที่เก็บจริง
            let capped = Self.format(exam.fullScore)
            if text != capped { text = capped }
            onChange(exam.fullScore)
            return
        }
        onChange(max(value, 0))
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}
