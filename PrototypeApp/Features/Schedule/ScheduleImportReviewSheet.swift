//
//  ScheduleImportReviewSheet.swift
//  The one screen that stands between OCR and the user's real timetable.
//
//  Its whole job is to make every mistake the parser could have made visible
//  and one tap away from being fixed. Nothing here writes to SwiftData — the
//  reviewed rows go back out through `onSave` and the caller decides.
//
//  Swipe-down is disabled by the presenter (AddScheduleEntrySheet) because
//  SwiftUI offers no hook to intercept it and ask "throw this away?". "ยกเลิก"
//  carries that confirmation instead.
//

import SwiftUI
import UIKit

struct ScheduleImportReviewSheet: View {
    let payload: ImportReviewPayload
    let onSave: ([ImportedPeriod]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var periods: [ImportedPeriod]
    @State private var showsOnlyFlagged = false
    @State private var editingPeriod: ImportedPeriod?
    @State private var isShowingSourceImage = false
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingSave = false

    init(payload: ImportReviewPayload, onSave: @escaping ([ImportedPeriod]) -> Void) {
        self.payload = payload
        self.onSave = onSave
        _periods = State(initialValue: payload.periods)
    }

    // MARK: - Derived

    private var flaggedCount: Int { periods.filter(\.needsAttention).count }

    /// Every day the photo touched, not `ScheduleConstants.visibleDays`: a
    /// Saturday row has to stay on screen so the user can delete it.
    private var days: [Int] { Array(Set(periods.map(\.dayOfWeek))).sorted() }

    private func rows(for day: Int) -> [ImportedPeriod] {
        periods.filter { $0.dayOfWeek == day && (!showsOnlyFlagged || $0.needsAttention) }
    }

    private var dayListText: String {
        days.compactMap { ScheduleConstants.dayLabels[$0] }.joined(separator: " · ")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                summaryHeader
                if flaggedCount > 0 { filterToggle }
                periodList
            }
            .padding(.top, Theme.Spacing.md)
            .background(Theme.Colors.background)
            .navigationTitle("ตรวจตารางที่อ่านได้")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .confirmationDialog(
                "ทิ้งข้อมูลที่อ่านมา?",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("ทิ้งทั้งหมด", role: .destructive) { dismiss() }
                Button("กลับไปตรวจต่อ", role: .cancel) {}
            }
            .confirmationDialog(
                "บันทึกตารางเรียน?",
                isPresented: $isConfirmingSave,
                titleVisibility: .visible
            ) {
                Button("บันทึกตารางเรียน") { onSave(periods) }
                Button("ยกเลิก", role: .cancel) {}
            } message: {
                Text("จะลบคาบเดิมของ \(dayListText) แล้วใส่ \(periods.count) คาบนี้แทน")
            }
            .sheet(item: $editingPeriod, onDismiss: pruneUnnamedRows) { period in
                ScheduleImportRowEditSheet(
                    period: period,
                    onSave: { apply($0) },
                    onDelete: { delete(period) }
                )
            }
            .sheet(isPresented: $isShowingSourceImage) {
                ScheduleImportSourceImageView(image: payload.image)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("ยกเลิก") { isConfirmingDiscard = true }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("บันทึก") { isConfirmingSave = true }
                .fontWeight(.semibold)
                .disabled(periods.isEmpty)
        }
    }

    // MARK: - Pieces

    private var summaryHeader: some View {
        CardContainer {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("อ่านได้ \(periods.count) คาบ · ต้องตรวจ \(flaggedCount) คาบ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("แตะแถวเพื่อแก้ · ปัดซ้ายเพื่อลบ")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button {
                    isShowingSourceImage = true
                } label: {
                    Image(uiImage: payload.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var filterToggle: some View {
        Toggle("เฉพาะที่ต้องตรวจ (\(flaggedCount))", isOn: $showsOnlyFlagged)
            .font(.subheadline)
            .padding(.horizontal, Theme.Spacing.lg)
    }

    private var periodList: some View {
        List {
            ForEach(days, id: \.self) { day in
                daySection(day)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func daySection(_ day: Int) -> some View {
        Section {
            ForEach(rows(for: day)) { period in
                periodRow(period)
                    .contentShape(Rectangle())
                    .onTapGesture { editingPeriod = period }
                    .swipeActions(edge: .trailing) {
                        Button("ลบ", role: .destructive) { delete(period) }
                    }
            }
        } header: {
            Text(ScheduleConstants.dayLabelsFull[day] ?? "")
        } footer: {
            Button("เพิ่มคาบใน\(ScheduleConstants.dayLabelsFull[day] ?? "")") {
                addBlankPeriod(day: day)
            }
            .font(.caption)
        }
    }

    private func periodRow(_ period: ImportedPeriod) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(period.subjectName)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if !period.subjectCode.isEmpty { codeChip(period.subjectCode) }
                Spacer(minLength: Theme.Spacing.xs)
                if period.needsAttention {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Colors.warning)
                }
            }
            Text(
                "คาบ \(period.periodNumber) · "
                    + "\(period.startMinute.asClockString)-\(period.endMinute.asClockString)"
            )
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)

            let detail = detailLine(period)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func codeChip(_ code: String) -> some View {
        Text(code)
            .font(.caption2)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Theme.Colors.primary.opacity(0.12), in: Capsule())
            .foregroundStyle(Theme.Colors.primary)
    }

    private func detailLine(_ period: ImportedPeriod) -> String {
        [period.teacherName, period.room]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " · ")
    }

    // MARK: - Mutations

    private func apply(_ edited: ImportedPeriod) {
        guard let index = periods.firstIndex(where: { $0.id == edited.id }) else { return }
        periods[index] = edited
        periods.sort {
            if $0.dayOfWeek != $1.dayOfWeek { return $0.dayOfWeek < $1.dayOfWeek }
            if $0.periodNumber != $1.periodNumber { return $0.periodNumber < $1.periodNumber }
            return $0.startMinute < $1.startMinute
        }
    }

    /// A blank row the user opened and then cancelled must not survive: an
    /// unnamed period would be committed as a subject called "".
    private func pruneUnnamedRows() {
        periods.removeAll {
            $0.subjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func delete(_ period: ImportedPeriod) {
        periods.removeAll { $0.id == period.id }
        AppLog.action("ScheduleImport", "ลบแถวที่อ่านมา · \(period.subjectName)")
    }

    /// A new row opens its edit sheet straight away — an empty row sitting in
    /// the list with no name is the "data disappeared silently" failure.
    private func addBlankPeriod(day: Int) {
        let last = periods.filter { $0.dayOfWeek == day }.last
        let start = last?.endMinute ?? (8 * 60 + 30)
        let blank = ImportedPeriod(
            dayOfWeek: day,
            periodNumber: (last?.periodNumber ?? 0) + 1,
            startMinute: start,
            endMinute: min(start + 50, 23 * 60 + 59),
            subjectCode: "",
            subjectName: "",
            teacherName: "",
            room: "",
            isBreak: false,
            codeNeedsReview: false,
            codeOptions: [],
            timeIsGuessed: false,
            nameIsGuessed: false,
            isUserAdded: true
        )
        periods.append(blank)
        editingPeriod = blank
    }
}

// MARK: - Source photo

/// The original photo, zoomable, so the user can settle an argument with the
/// parser without leaving the review.
private struct ScheduleImportSourceImageView: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(magnification)
            }
            .navigationTitle("รูปต้นฉบับ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จสิ้น") { dismiss() }
                }
            }
        }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(committedScale * value.magnification, 1), 5)
            }
            .onEnded { _ in
                committedScale = scale
            }
    }
}
