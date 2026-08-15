//
//  FocusStatsSheet.swift
//  สถิติโฟกัส — เปิดจากปุ่มกราฟมุมซ้ายบนของหน้าโฟกัส
//
//  ⚠️ นับเฉพาะ `phase == .focus` เสมอ — ช่วงพักก็ถูกบันทึกเป็น FocusSession ด้วย
//  รอบที่ถูกกดหยุดกลางคัน (`completed == false`) แยกโชว์ต่างหาก ไม่รวมในนาทีรวม
//

import SwiftUI
import SwiftData

struct FocusStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [FocusSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    totalsCard
                    tagCard
                    unfinishedCard
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("สถิติโฟกัส")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - การ์ด

    private var totalsCard: some View {
        CardContainer {
            Text("รวม")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
            HStack(spacing: Theme.Spacing.lg) {
                FocusStatBlock(value: "\(todayMinutes)", label: "นาทีวันนี้")
                FocusStatBlock(value: "\(weekMinutes)", label: "นาทีสัปดาห์นี้")
                FocusStatBlock(value: "\(completedCount)", label: "รอบสำเร็จ")
            }
        }
    }

    private var tagCard: some View {
        CardContainer {
            Text("แยกตามแท็ก")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)

            if tagTotals.isEmpty {
                Text("ยังไม่มีข้อมูล")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(tagTotals, id: \.id) { row in
                    HStack(spacing: Theme.Spacing.md) {
                        Circle()
                            .fill(row.colorHex.isEmpty ? Theme.Colors.separator : Color(hex: row.colorHex))
                            .frame(width: 10, height: 10)
                        Text(row.name)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(row.minutes) นาที")
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    private var unfinishedCard: some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("รอบที่หยุดกลางคัน")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("ไม่ถูกนับในนาทีรวมข้างบน")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Text("\(unfinishedCount)")
                    .font(Theme.Font.number(22))
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
        }
    }

    // MARK: - คำนวณ

    private var focusSessions: [FocusSession] {
        sessions.filter { $0.phase == .focus }
    }

    private var completedSessions: [FocusSession] {
        focusSessions.filter(\.completed)
    }

    private var todayMinutes: Int {
        completedSessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var weekMinutes: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return completedSessions
            .filter { $0.startedAt >= weekAgo }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var completedCount: Int { completedSessions.count }

    private var unfinishedCount: Int {
        focusSessions.filter { !$0.completed }.count
    }

    private struct TagTotal {
        let id: String
        let name: String
        let colorHex: String
        let minutes: Int
    }

    /// จัดกลุ่มด้วย `tagID` (ไม่ใช่ชื่อ) — เปลี่ยนชื่อแท็กแล้วสถิติเก่ายังอยู่กองเดิม
    private var tagTotals: [TagTotal] {
        var buckets: [String: (name: String, colorHex: String, seconds: Int)] = [:]
        for session in completedSessions {
            let key = session.tagID.isEmpty ? "" : session.tagID
            let name = session.tagName.isEmpty ? "ไม่ระบุแท็ก" : session.tagName
            var bucket = buckets[key] ?? (name: name, colorHex: session.tagColorHex, seconds: 0)
            bucket.seconds += session.durationSeconds
            buckets[key] = bucket
        }
        return buckets
            .map { TagTotal(id: $0.key, name: $0.value.name, colorHex: $0.value.colorHex, minutes: $0.value.seconds / 60) }
            .sorted { $0.minutes > $1.minutes }
    }
}

struct FocusStatBlock: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(Theme.Font.number(22))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
