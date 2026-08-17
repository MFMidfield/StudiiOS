//
//  ScheduleSetupView.swift
//  หน้า 3 ของ setup — ตารางเรียนของเทอมที่เลือกไว้หน้า 2
//
//  ทางถ่ายรูปใช้เส้นเดียวกับ `AddScheduleEntrySheet` ทุกขั้น:
//    ScheduleOCRParser → ScheduleImportBuilder → ScheduleImportReviewSheet → ScheduleImportCommitter
//  ของเดิม onboarding มี OCR เส้นของตัวเองที่ไม่มีหน้าตรวจเลย — คาบที่อ่านผิดจึงลงฐานข้อมูล
//  ไปเงียบๆ เส้นนั้นถูกลบทิ้งแล้ว
//
//  presentation ทั้งชุด (alert → dialog → picker → review) แขวนจาก view นี้ตัวเดียว
//  ห้ามย้ายไปไว้ใน child — sheet ซ้อน sheet คือจุดที่หน้าต่างหายเงียบๆ
//
//  ข้ามได้ แต่ต้องเตือนก่อน (สเปค): ไม่มีตาราง = หน้าเกรดละเอียดไม่มีวิชาให้ seed
//  และการ์ด "คาบเรียนถัดไป" บน Dashboard จะว่าง
//

import SwiftUI
import SwiftData
import UIKit

struct ScheduleSetupView: View {
    let onBack: () -> Void
    let onNext: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var allEntries: [ScheduleEntry]
    @Query private var terms: [Term]
    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""

    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }
    private var entries: [ScheduleEntry] { allEntries.inTerm(activeTerm) }

    /// หนึ่ง `.sheet` ต่อหนึ่ง view เท่านั้น — แขวนสองตัวไว้ที่เดียวกันแล้วตัวที่เปิดทีหลัง
    /// จะปิดตัวเองทันที (บั๊ก "กดกรอกเองแล้ว sheet เด้งแล้วหายเอง")
    private enum ActiveSheet: Identifiable {
        case addPeriod(Term)
        case review(ImportReviewPayload)

        var id: String {
            switch self {
            case .addPeriod: return "addPeriod"
            case .review(let payload): return "review-\(payload.id)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?
    @State private var isConfirmingSkip = false

    // Photo import
    @State private var isShowingScanWarning = false
    @State private var isShowingPhotoSource = false
    @State private var activePickerSource: ProfileImagePicker.Source?
    @State private var isAnalyzingPhoto = false
    @State private var scanError: String?

    var body: some View {
        OnboardingScaffold(
            step: .schedule,
            onBack: onBack,
            primaryTitle: entries.isEmpty ? "ยังไม่เพิ่ม ข้ามไปก่อน" : "ถัดไป",
            onPrimary: { entries.isEmpty ? isConfirmingSkip = true : onNext() }
        ) {
            VStack(spacing: Theme.Spacing.xl) {
                importCard
                manualCard
                if !entries.isEmpty {
                    entryList
                }
            }
        }
        .alert("ยังไม่มีตารางเรียน", isPresented: $isConfirmingSkip) {
            Button("กลับไปเพิ่ม", role: .cancel) {}
            Button("ข้ามไปก่อน") { onNext() }
        } message: {
            Text("ข้ามได้ แต่หน้าแรกจะยังไม่บอกคาบเรียนถัดไป และตอนกรอกเกรดจะไม่มีรายชื่อวิชามาให้เลือกอัตโนมัติ เพิ่มทีหลังได้ที่แท็บตารางเรียน")
        }
        .fullScreenCover(item: $activePickerSource) { source in
            ProfileImagePicker(source: source, allowsEditing: false) { analyze($0) }
                .ignoresSafeArea()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addPeriod(let term):
                OnboardingPeriodSheet(term: term, defaultStartMinute: nextStartMinute)
            case .review(let payload):
                ScheduleImportReviewSheet(payload: payload) { confirmed in
                    commitImport(confirmed)
                }
                .presentationDetents([.large])
                .interactiveDismissDisabled(true)
            }
        }
    }

    // MARK: - Cards

    private var importCard: some View {
        Button {
            isShowingScanWarning = true
        } label: {
            CardContainer {
                HStack(spacing: Theme.Spacing.lg) {
                    IconTile(systemName: "camera.viewfinder", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ถ่ายรูปตารางเรียน")
                            .font(Theme.Font.plex(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("อ่านทั้งใบให้อัตโนมัติ แล้วให้คุณตรวจก่อนบันทึก")
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if isAnalyzingPhoto { ProgressView() }
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isAnalyzingPhoto)
        .overlay(alignment: .bottom) { scanErrorText }
        // แขวนที่ปุ่ม ไม่ใช่ที่หน้าทั้งหน้า: บน iPad กับ Mac ตัว dialog เป็น popover
        // ที่ชี้ไปยัง view ที่มันเกาะอยู่ — เกาะทั้งหน้าแล้วลูกศรไปโผล่มุมซ้ายบน
        .alert("ระบบอาจอ่านผิด", isPresented: $isShowingScanWarning) {
            Button("ยกเลิก", role: .cancel) {}
            Button("เข้าใจแล้ว") { chooseImageSource() }
        } message: {
            Text("การอ่านตารางจากรูปอาจอ่านผิด โดยเฉพาะรหัสวิชาและเวลา จะมีหน้าให้ตรวจทุกคาบก่อนบันทึกจริง")
        }
        .confirmationDialog("เลือกรูปตารางเรียน", isPresented: $isShowingPhotoSource, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("ถ่ายรูป") { activePickerSource = .camera }
            }
            Button("เลือกจากคลังภาพ") { activePickerSource = .photoLibrary }
            Button("ยกเลิก", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var scanErrorText: some View {
        if let scanError {
            Text(scanError)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.warning)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)
                .offset(y: 26)
        }
    }

    private var manualCard: some View {
        Button {
            // เทอมถูกหยิบมา ณ ตอนกด ไม่ใช่ตอนวาด sheet — เนื้อ sheet ที่ว่าง
            // (activeTerm เป็น nil ชั่วขณะ) คือสาเหตุที่ SwiftUI ปิดมันเองทันที
            guard let activeTerm else { return }
            activeSheet = .addPeriod(activeTerm)
        } label: {
            CardContainer {
                HStack(spacing: Theme.Spacing.lg) {
                    IconTile(systemName: "square.and.pencil", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("กรอกเอง")
                            .font(Theme.Font.plex(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("เลือกวิชาจากรายการ แล้วใส่วันกับเวลา")
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(activeTerm == nil)
    }

    // MARK: - List

    private var entryList: some View {
        OnboardingSection(title: "เพิ่มแล้ว \(entries.count) คาบ") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(ScheduleConstants.visibleDays, id: \.self) { day in
                    let dayEntries = entries
                        .filter { $0.dayOfWeek == day }
                        .sorted { $0.startMinute < $1.startMinute }
                    if !dayEntries.isEmpty {
                        dayBlock(day: day, entries: dayEntries)
                    }
                }
            }
        }
    }

    private func dayBlock(day: Int, entries dayEntries: [ScheduleEntry]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(ScheduleConstants.dayLabelsFull[day] ?? "")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            ForEach(dayEntries) { entry in
                periodRow(entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func periodRow(_ entry: ScheduleEntry) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.subject?.color ?? Theme.Colors.primary)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.subject?.name ?? entry.subjectName)
                    .font(Theme.Font.plex(14, .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(entry.startMinute.asClockString)–\(entry.endMinute.asClockString)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                delete(entry)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("ลบคาบ \(entry.subject?.name ?? entry.subjectName)")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }

    // MARK: - Actions

    /// ไม่มีกล้อง (simulator ก็ไม่มี) = มีทางเดียว ไม่ต้องถาม — เมนูตัวเลือกเดียว
    /// เปลืองการกดและเป็นอีกชั้นที่พังได้
    private func chooseImageSource() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            isShowingPhotoSource = true
        } else {
            activePickerSource = .photoLibrary
        }
    }

    /// วางคาบใหม่ต่อจากคาบสุดท้ายของวันนั้น เพื่อไม่ต้องเลื่อนเวลาเองทุกครั้ง
    private var nextStartMinute: Int {
        let today = ScheduleConstants.defaultEntryDay
        let last = entries.filter { $0.dayOfWeek == today }.map(\.endMinute).max()
        return last ?? 8 * 60
    }

    private func delete(_ entry: ScheduleEntry) {
        context.delete(entry)
        try? context.save()
    }

    private func analyze(_ image: UIImage) {
        isAnalyzingPhoto = true
        scanError = nil
        ScheduleOCRParser.parseScheduleDetailed(from: image, onRawBoxes: nil) { result in
            isAnalyzingPhoto = false
            let periods = ScheduleImportBuilder.build(from: result.entries)
            guard !periods.isEmpty else {
                scanError = result.problem?.message
                    ?? "อ่านตารางจากรูปนี้ไม่สำเร็จ ลองถ่ายให้เห็นตารางทั้งใบและอย่าให้เอียง"
                AppLog.warn("Onboarding", "OCR ไม่ได้คาบเลย · problem=\(String(describing: result.problem))")
                return
            }
            if let problem = result.problem { scanError = problem.message }
            activeSheet = .review(ImportReviewPayload(image: image, periods: periods))
        }
    }

    private func commitImport(_ periods: [ImportedPeriod]) {
        guard let activeTerm else {
            activeSheet = nil
            scanError = "ไม่พบเทอมปัจจุบัน ลองย้อนกลับไปหน้าก่อนแล้วกดถัดไปใหม่"
            AppLog.error("Onboarding", "commitImport ล้มเหลว: ไม่มี activeTerm")
            return
        }
        let summary = ScheduleImportCommitter.commit(periods, into: activeTerm, in: context)
        activeSheet = nil
        AppLog.action("Onboarding", "นำเข้าตารางจากรูป \(summary.insertedEntries) คาบ")
    }
}
