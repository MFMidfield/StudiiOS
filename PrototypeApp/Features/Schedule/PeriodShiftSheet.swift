//
//  PeriodShiftSheet.swift
//  Form to create/update/cancel a DayScheduleOverride for one day. The
//  live preview calls the exact same PeriodShiftCalculator.apply used by
//  ScheduleTimetableSection, so preview and real result never drift apart.
//

import SwiftUI
import SwiftData

private enum LengthChoice: Hashable {
    case minutes(Int)
    case custom
}

struct PeriodShiftSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let day: Int
    let dayEntries: [ScheduleEntry]
    let targetDate: Date
    let existing: DayScheduleOverride?

    @State private var startPeriodNumber: Int
    @State private var startTime: Date
    @State private var lengthChoice: LengthChoice
    @State private var customLengthText: String
    @State private var showCancelConfirm = false

    init(day: Int, dayEntries: [ScheduleEntry], targetDate: Date, existing: DayScheduleOverride?) {
        self.day = day
        self.dayEntries = dayEntries
        self.targetDate = targetDate
        self.existing = existing

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // `init` runs before `self` is usable, so the computed properties below
        // are off limits here — sort into a local instead.
        let sortedEntries = dayEntries.sorted { $0.startMinute < $1.startMinute }
        let firstRealPeriod: Int? = sortedEntries.first { $0.subject?.isBreak != true }?.periodNumber
        let initialPeriodNumber: Int = existing?.startPeriodNumber ?? firstRealPeriod ?? 1
        let anchorEntry = sortedEntries.first { $0.periodNumber == initialPeriodNumber }

        let initialStartMinute: Int
        let initialLength: Int
        if let existing {
            initialStartMinute = existing.startMinute
            initialLength = existing.periodLengthMinutes
        } else {
            initialStartMinute = anchorEntry?.startMinute ?? 480
            initialLength = anchorEntry.map { $0.endMinute - $0.startMinute } ?? 50
        }

        _startPeriodNumber = State(initialValue: initialPeriodNumber)
        _startTime = State(initialValue: cal.date(byAdding: .minute, value: initialStartMinute, to: today) ?? today)
        if stride(from: 5, through: 60, by: 5).contains(initialLength) {
            _lengthChoice = State(initialValue: .minutes(initialLength))
            _customLengthText = State(initialValue: "")
        } else {
            _lengthChoice = State(initialValue: .custom)
            _customLengthText = State(initialValue: String(initialLength))
        }
    }

    private var sortedDayEntries: [ScheduleEntry] {
        dayEntries.sorted { $0.startMinute < $1.startMinute }
    }

    /// Period numbers as they appear down the day, de-duplicated but kept in
    /// clock order — a school that prints "0" for both homeroom and lunch must
    /// still offer that number exactly once.
    private var periodChoices: [Int] {
        var seen = Set<Int>()
        return sortedDayEntries
            .map { $0.periodNumber }
            .filter { seen.insert($0).inserted }
    }

    /// "คาบ 1 · ฟิสิกส์" — the number alone is ambiguous when a school uses 0
    /// for both homeroom and lunch.
    private func periodChoiceLabel(_ n: Int) -> String {
        let first = sortedDayEntries.first { $0.periodNumber == n }
        let subject = first?.subject?.name ?? first?.subjectName ?? ""
        return subject.isEmpty ? "คาบ \(n)" : "คาบ \(n) · \(subject)"
    }

    private var startMinuteValue: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var periodLengthValue: Int? {
        switch lengthChoice {
        case .minutes(let n): return n
        case .custom: return Int(customLengthText)
        }
    }

    private var isLengthValid: Bool {
        guard let length = periodLengthValue else { return false }
        return (1...240).contains(length)
    }

    private var previewPeriods: [ResolvedPeriod] {
        guard let length = periodLengthValue, isLengthValid else { return [] }
        let previewOverride = DayScheduleOverride(
            date: targetDate,
            startPeriodNumber: startPeriodNumber,
            startMinute: startMinuteValue,
            periodLengthMinutes: length
        )
        return PeriodShiftCalculator.apply(override: previewOverride, to: dayEntries)
    }

    var body: some View {
        NavigationStack {
            Form {
                infoSection
                actionSection
            }
            .navigationTitle("ร่นคาบ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
            .onAppear {
                AppLog.action(
                    "Shift",
                    "เปิดฟอร์มร่นคาบ · \(ScheduleConstants.dayLabelsFull[day] ?? "") \(targetDate.thaiDayMonthYearString) · มี override เดิม: \(existing == nil ? "ไม่มี" : "มี")"
                )
            }
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        Section {
            LabeledContent("วันที่ร่น", value: "\(ScheduleConstants.dayLabelsFull[day] ?? "") \(targetDate.thaiDayMonthYearString)")

            Picker("เริ่มร่นที่คาบ", selection: $startPeriodNumber) {
                ForEach(periodChoices, id: \.self) { n in
                    Text(periodChoiceLabel(n)).tag(n)
                }
            }
            Text("คาบก่อนหน้าคาบที่เลือกจะไม่แสดงในวันนี้")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            DatePicker("คาบแรกเริ่ม", selection: $startTime, displayedComponents: .hourAndMinute)

            Picker("คาบละ", selection: $lengthChoice) {
                ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { n in
                    Text("\(n) นาที").tag(LengthChoice.minutes(n))
                }
                Text("กำหนดเอง").tag(LengthChoice.custom)
            }
            if lengthChoice == .custom {
                TextField("นาที (1-240)", text: $customLengthText)
                    .keyboardType(.numberPad)
            }
            if !isLengthValid {
                Text("คาบละต้องอยู่ระหว่าง 1-240 นาที")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.danger)
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                confirmShift()
            } label: {
                HStack {
                    Spacer()
                    Text("ยืนยันร่นคาบ").fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(!isLengthValid)

            if existing != nil {
                Button(role: .destructive) {
                    showCancelConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("ยกเลิกการร่นคาบ")
                        Spacer()
                    }
                }
            }
        }
        .confirmationDialog(
            "ยกเลิกการร่นคาบวันนี้?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("ยกเลิกการร่นคาบ", role: .destructive, action: cancelShift)
            Button("ปิด", role: .cancel) {}
        }
    }

    // MARK: - Actions

    private func confirmShift() {
        guard let length = periodLengthValue, (1...240).contains(length) else {
            AppLog.warn("Shift", "บันทึกไม่ได้: คาบละต้องอยู่ระหว่าง 1-240 นาที")
            return
        }

        let resolved = previewPeriods
        let hiddenCount = dayEntries.count - resolved.count

        if let existing {
            existing.startPeriodNumber = startPeriodNumber
            existing.startMinute = startMinuteValue
            existing.periodLengthMinutes = length
        } else {
            context.insert(DayScheduleOverride(
                date: targetDate,
                startPeriodNumber: startPeriodNumber,
                startMinute: startMinuteValue,
                periodLengthMinutes: length
            ))
        }

        do {
            try context.save()
            AppLog.action(
                "Shift",
                "ร่นคาบ \(targetDate.thaiDayMonthYearString) · เริ่มคาบ \(startPeriodNumber) เวลา \(startMinuteValue.asClockString) · คาบละ \(length) นาที · ร่น \(resolved.count) คาบ · ซ่อน \(hiddenCount) คาบ"
            )
        } catch {
            AppLog.error("Shift", "save ล้มเหลว: \(error.localizedDescription)")
            return
        }

        dismiss()
    }

    private func cancelShift() {
        guard let existing else { return }
        let dateLabel = targetDate.thaiDayMonthYearString

        context.delete(existing)
        do {
            try context.save()
            AppLog.action("Shift", "ยกเลิกร่นคาบ \(dateLabel)")
        } catch {
            AppLog.error("Shift", "save ล้มเหลว: \(error.localizedDescription)")
        }

        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Subject.self, ScheduleEntry.self, DayScheduleOverride.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let math = Subject(name: "คณิตศาสตร์เพิ่มเติม ม.5", colorHex: "E1802F", iconName: "function")
    let lunch = Subject(name: "พักกลางวัน", colorHex: "FFB347", iconName: "fork.knife", isBreak: true, isBuiltIn: true)
    [math, lunch].forEach { container.mainContext.insert($0) }

    let entries = [
        ScheduleEntry(dayOfWeek: 1, startMinute: 480, endMinute: 530, periodNumber: 1, location: "5201", subjectName: math.name, subject: math),
        ScheduleEntry(dayOfWeek: 1, startMinute: 720, endMinute: 780, periodNumber: 0, subjectName: lunch.name, subject: lunch),
    ]
    entries.forEach { container.mainContext.insert($0) }

    return PeriodShiftSheet(day: 1, dayEntries: entries, targetDate: .now, existing: nil)
        .modelContainer(container)
}
