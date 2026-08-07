//
//  OCRDebugView.swift
//  Developer-only viewer that shows exactly what Vision reads out of a
//  photo, before any parsing heuristic touches it. Every recognized line
//  is listed with its normalized bounding box and confidence so a bad
//  parse can be traced to either "Vision misread it" or "the grid guess
//  was wrong". DEBUG builds only — never shipped.
//

#if DEBUG

import SwiftUI
import UIKit

struct OCRDebugView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case schedule
        case gradeReport

        var id: String { rawValue }

        var label: String {
            switch self {
            case .schedule: return "ตารางเรียน"
            case .gradeReport: return "ผลการเรียน (ปพ.)"
            }
        }

        /// Matches the label used by the parsers' console dump.
        var dumpLabel: String {
            switch self {
            case .schedule: return "Schedule"
            case .gradeReport: return "GradeReport"
            }
        }
    }

    /// `ProfileImagePicker.Source` isn't `Identifiable`, so wrap it here and
    /// drive one `.sheet(item:)` instead of juggling two booleans.
    private struct PickerRequest: Identifiable {
        let id = UUID()
        let source: ProfileImagePicker.Source
    }

    @State private var mode: Mode = .schedule
    @State private var image: UIImage?
    @State private var boxes: [OCRTextBox] = []
    @State private var draftCount: Int = 0
    @State private var isAnalyzing = false
    @State private var hasResult = false
    @State private var picker: PickerRequest?

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                modePicker
                sourceButtons
                previewSection
                resultSection
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle("ทดสอบ OCR")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $picker) { request in
            ProfileImagePicker(source: request.source, allowsEditing: false) { picked in
                analyze(picked)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Sections

    private var modePicker: some View {
        Picker("โหมด", selection: $mode) {
            ForEach(Mode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) { _, _ in
            if let image { analyze(image) }
        }
    }

    private var sourceButtons: some View {
        HStack(spacing: Theme.Spacing.md) {
            if isCameraAvailable {
                Button {
                    picker = PickerRequest(source: .camera)
                } label: {
                    Label("ถ่ายรูป", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                picker = PickerRequest(source: .photoLibrary)
            } label: {
                Label("เลือกรูป", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .tint(Theme.Colors.primary)
    }

    @ViewBuilder
    private var previewSection: some View {
        if let image {
            CardContainer {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                if isAnalyzing {
                    HStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                        Text("กำลังอ่านรูป…")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        } else {
            CardContainer {
                Text("เลือกรูปตารางเรียนหรือใบ ปพ. เพื่อดูว่า Vision อ่านออกมาเป็นข้อความอะไรบ้าง")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        if hasResult && !isAnalyzing {
            CardContainer {
                HStack(alignment: .firstTextBaseline) {
                    Text("Vision อ่านได้ \(boxes.count) กล่อง · parse เป็น \(draftCount) รายการ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()

                    Button("คัดลอกทั้งหมด") {
                        UIPasteboard.general.string = report
                    }
                    .font(.caption)
                }

                if boxes.isEmpty {
                    Text("Vision อ่านไม่ได้เลย — ลองถ่ายให้ตรงและสว่างขึ้น")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.danger)
                } else {
                    Divider()

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(Array(boxes.enumerated()), id: \.element.id) { index, box in
                            Text(box.debugLine(index: index))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Logic

    /// Full console-style report, same lines as the Xcode dump, for pasting
    /// back into chat when a photo parses badly.
    private var report: String {
        var lines = [
            "===== \(mode.dumpLabel) · Vision อ่านได้ \(boxes.count) กล่อง · parse เป็น \(draftCount) รายการ ====="
        ]
        lines += boxes.enumerated().map { $0.element.debugLine(index: $0.offset) }
        lines.append("===== จบ =====")
        return lines.joined(separator: "\n")
    }

    private func analyze(_ image: UIImage) {
        self.image = image
        boxes = []
        draftCount = 0
        hasResult = false
        isAnalyzing = true

        switch mode {
        case .schedule:
            ScheduleOCRParser.parseSchedule(from: image, onRawBoxes: { raw in
                boxes = raw
            }) { drafts in
                draftCount = drafts.count
                isAnalyzing = false
                hasResult = true
            }
        case .gradeReport:
            GradeReportOCRParser.parseGradeReport(from: image, onRawBoxes: { raw in
                boxes = raw
            }) { drafts in
                draftCount = drafts.count
                isAnalyzing = false
                hasResult = true
            }
        }
    }
}

#endif
