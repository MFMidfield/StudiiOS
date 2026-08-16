//
//  TaskSubjectPeriodPicker.swift
//  เลือกวิชาของงานด้วย "วัน → คาบ" แทนการเลือกจากรายชื่อวิชา
//
//  เหตุผล: นักเรียนจำว่า "ครูสั่งคาบ 3 วันพุธ" ไม่ได้จำว่าวิชาชื่อเต็มว่าอะไร
//  ชื่อวิชาจึงมาจาก `ScheduleEntry` ของคาบที่เลือกเสมอ — ไม่มีช่องพิมพ์ชื่อเอง
//  และไม่มีปุ่ม "เพิ่มวิชาใหม่" (วิชาต้องมาจากตารางเรียนที่ตั้งไว้แล้วเท่านั้น)
//
//  ⚠️ วัน/คาบเป็นแค่ทางเดินไปหา `subjectName` — **ไม่ได้ตั้งกำหนดส่ง**
//  กำหนดส่งยังเลือกแยกที่ DatePicker ด้านล่างของฟอร์มเหมือนเดิม
//

import SwiftUI

struct TaskSubjectPeriodPicker: View {
    /// คาบของเทอมปัจจุบัน (ตัดคาบพักออกแล้ว) — ส่งเข้ามาจากฟอร์ม
    let entries: [ScheduleEntry]
    @Binding var subjectName: String

    @State private var selectedDay: Int
    @State private var selectedPeriod: Int
    @Namespace private var dayCapsule

    /// จ–อา ครบ 7 วัน (ตารางเรียนเก็บ 1 = จันทร์ … 7 = อาทิตย์)
    private static let days: [Int] = Array(1...7)
    private static let shortLabels: [Int: String] = [
        1: "จ", 2: "อ", 3: "พ", 4: "พฤ", 5: "ศ", 6: "ส", 7: "อา"
    ]

    init(entries: [ScheduleEntry], subjectName: Binding<String>) {
        self.entries = entries
        _subjectName = subjectName

        let start = Self.defaultSelection(entries: entries, subjectName: subjectName.wrappedValue)
        _selectedDay = State(initialValue: start.day)
        _selectedPeriod = State(initialValue: start.period)
    }

    private var periods: [ScheduleEntry] {
        entries
            .filter { $0.dayOfWeek == selectedDay }
            .sorted { $0.periodNumber < $1.periodNumber }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            dayBar

            Divider()

            Group {
                if periods.isEmpty {
                    Text("วันนี้ไม่มีคาบเรียนในตาราง")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Picker("คาบ", selection: $selectedPeriod) {
                        ForEach(periods) { entry in
                            Text("คาบ \(entry.periodNumber) · \(entry.subjectName)")
                                .tag(entry.periodNumber)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            // เปลี่ยนวันแล้วรายการคาบเปลี่ยนยกชุด — เฟดเข้าออกกันภาพกระตุก
            .transition(.opacity)
            .id(selectedDay)
        }
        .animation(.smooth(duration: 0.25), value: selectedDay)
        .onChange(of: selectedDay) { _, _ in
            // ย้ายวันแล้วคาบเดิมอาจไม่มีอยู่ — เลื่อนไปคาบแรกของวันใหม่
            if !periods.contains(where: { $0.periodNumber == selectedPeriod }) {
                selectedPeriod = periods.first?.periodNumber ?? 0
            }
            syncSubjectName()
        }
        .onChange(of: selectedPeriod) { _, _ in syncSubjectName() }
        .onAppear(perform: syncSubjectName)
    }

    private var dayBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Self.days, id: \.self) { day in
                dayButton(day)
            }
        }
        // geometry ของแคปซูลต้องอยู่ในกลุ่มเดียวกันทั้งแถบ ถึงจะ interpolate ตำแหน่งได้
        .animation(.snappy(duration: 0.3), value: selectedDay)
    }

    private func dayButton(_ day: Int) -> some View {
        let isSelected = day == selectedDay
        let hasClass = entries.contains { $0.dayOfWeek == day }

        return Button {
            // สั่ง animation ที่ต้นทางด้วย ไม่พึ่ง `.animation(value:)` ของ VStack อย่างเดียว —
            // แคปซูลสีส้มจะได้ "เลื่อน" ไปวันใหม่จริงๆ ทุกครั้งที่กด
            withAnimation(.snappy(duration: 0.3)) { selectedDay = day }
        } label: {
            Text(Self.shortLabels[day] ?? "")
                .font(Theme.Font.plex(13, isSelected ? .semibold : .regular))
                .foregroundStyle(labelColor(isSelected: isSelected, hasClass: hasClass))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background {
                    if isSelected {
                        // matchedGeometryEffect = แคปซูลเลื่อนไปวันใหม่ ไม่ใช่กระพริบหาย-โผล่
                        Capsule()
                            .fill(Theme.Colors.primary)
                            .matchedGeometryEffect(id: "selectedDay", in: dayCapsule)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// วันที่ไม่มีคาบเลยจางไว้ตั้งแต่แรก จะได้ไม่ต้องกดเข้าไปเจอความว่าง
    private func labelColor(isSelected: Bool, hasClass: Bool) -> Color {
        if isSelected { return Theme.Colors.onPrimary }
        return hasClass ? Theme.Colors.textPrimary : Theme.Colors.textSecondary.opacity(0.5)
    }

    private func syncSubjectName() {
        let match = periods.first { $0.periodNumber == selectedPeriod }
        subjectName = match?.subjectName ?? ""
    }

    // MARK: - ค่าเริ่มต้น

    /// ลำดับการเลือกค่าเริ่มต้น
    /// 1. งานที่กำลังแก้ไขมีวิชาอยู่แล้ว → คาบแรกที่สอนวิชานั้น
    /// 2. ตอนนี้อยู่ในคาบเรียนพอดี → คาบนั้น
    /// 3. ไม่งั้น → วันจันทร์ คาบแรกของวันจันทร์ (ถ้าจันทร์ว่างก็วันแรกที่มีคาบ)
    static func defaultSelection(entries: [ScheduleEntry], subjectName: String) -> (day: Int, period: Int) {
        if !subjectName.isEmpty,
           let match = entries
            .filter({ $0.subjectName == subjectName })
            .sorted(by: { ($0.dayOfWeek, $0.periodNumber) < ($1.dayOfWeek, $1.periodNumber) })
            .first {
            return (match.dayOfWeek, match.periodNumber)
        }

        let today = ScheduleConstants.todayWeekday
        let cal = Calendar.current
        let minutesNow = cal.component(.hour, from: .now) * 60 + cal.component(.minute, from: .now)
        if let ongoing = entries.first(where: {
            $0.dayOfWeek == today && $0.startMinute <= minutesNow && minutesNow < $0.endMinute
        }) {
            return (today, ongoing.periodNumber)
        }

        let mondayPeriods = entries.filter { $0.dayOfWeek == 1 }.sorted { $0.periodNumber < $1.periodNumber }
        if let first = mondayPeriods.first { return (1, first.periodNumber) }

        if let anyEntry = entries.sorted(by: { ($0.dayOfWeek, $0.periodNumber) < ($1.dayOfWeek, $1.periodNumber) }).first {
            return (anyEntry.dayOfWeek, anyEntry.periodNumber)
        }

        return (1, 1)
    }
}
